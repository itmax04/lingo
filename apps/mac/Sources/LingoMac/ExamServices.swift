import Foundation
import LingoCore

/// One live runner; selecting another session permanently leaves its exam transcript-only.
@MainActor
extension AppServices {
    static var stillFinishingText: String { String(localized: "The session is still finishing. Try again in a moment.") }
    static var examStartingText: String { String(localized: "An exam is already starting.") }

    /// LINGO-10 BR-16, BR-33: a Goethe Training of one Teil on one task; the same conditions as any exam start (a refused click says why).
    func startGoetheTraining(teil: Int, task: String) {
        guard ExamCatalog.validTraining(teil: teil, ids: [task]) else { return }
        startExam(.goetheB1, tasks: [task], format: .training, teil: teil)
    }

    func startExam(_ kind: ExamKind, tasks: [String]? = nil, format: Activity.Format? = nil, teil: Int? = nil, partnerTask: String? = nil) {
        // A refused click must say why instead of doing nothing (H-05).
        if ending { model.banner = Self.stillFinishingText; return }
        if model.startingExam { model.banner = Self.examStartingText; return }
        if model.readOnly { model.banner = model.disabledReason; return }
        // BR-22: a Training plan written before Start stays for the run (Teil 2 and 3); stopping the old run clears it.
        let notes = model.goetheNotes
        stopExam()
        model.goetheNotes = format == .training && (teil == 2 || teil == 3) ? notes : ""
        let startID = UUID()
        examStartID = startID
        model.startingExam = true
        examStartTask = Task {
            defer {
                if examStartID == startID {
                    model.startingExam = false
                    if model.banner == Self.examStartingText { model.banner = nil }
                    examStartID = nil
                    if let tc = turn { restoreExamMicrophone(on: tc.sink) }
                }
            }
            // Navigation during voice setup cancels this task (examSelectionChanged); journal auto-selection does not.
            guard let tc = await ensureVoice(forExamStart: true), !Task.isCancelled, examStartID == startID else { return }
            await attachExam(kind, to: tc, tasks: tasks, format: format, teil: teil, partnerTask: partnerTask)
        }
    }

    func attachExam(_ kind: ExamKind, to tc: TurnController, tasks: [String]? = nil, format: Activity.Format? = nil, teil: Int? = nil,
                    partnerTask: String? = nil) async {
        turnTask?.cancel()
        tc.stopVoice(cancelTurn: true)
        model.streaming = nil
        let controller = ExamController(engine: engine, sink: tc.sink) { [weak self, weak tc] stream in
            guard let self, let tc else { return }
            let state = await self.store.state
            guard !Task.isCancelled, let current = self.exam, tc.exam === current,
                  current.sessionID == self.model.selectedSessionID else { return }
            self.model.apply(state)
            await tc.consumeExamReply(stream)
        }
        exam = controller
        tc.exam = controller
        // LINGO-10 BR-10, BR-23: Examiner lines and the partner's talk go through the voice loop, each in its own voice.
        controller.voices = ExamVoices.pick(preferred: settings.voice.voiceIDs[kind.lang], available: Voices.available(kind.lang))
        controller.speak = { [weak self, weak tc, weak controller] parts, voiceID in
            guard let self, let tc, let controller, self.exam === controller, tc.exam === controller else { return }
            await tc.speakExam(parts, lang: kind.lang, voiceID: voiceID)
        }
        controller.onStarted = { [weak self, weak controller] sid in
            guard let self, self.exam === controller else { return }
            self.model.langFilter = kind.lang
            self.model.selectedSessionID = sid
            let state = await self.store.state
            guard self.exam === controller, self.model.selectedSessionID == sid, !Task.isCancelled else { return }
            self.model.apply(state)
            self.model.section = .conversations
            self.updateSettings { $0.lastLang = kind.lang }
        }
        controller.onChange = { [weak self, weak controller] in
            guard let self, let controller, self.exam === controller else { return }
            self.model.liveExamSessionID = controller.sessionID
            self.model.examRun = controller.run
            self.model.examBusy = controller.busy
            self.model.examInputAllowed = controller.microphoneAllowed
            self.model.examFollowUp = controller.monologueReleased
            self.model.examSpeaker = controller.speaker
        }
        controller.onFinished = { [weak self, weak tc, weak controller] in
            guard let self else { return }
            let finished = controller?.sessionID
            self.stopExam()
            if let finished { self.runDebrief(finished) }
            Task {
                guard self.exam == nil, !self.model.startingExam, self.turn === tc else { return }
                await self.shutDownVoice()
            }
        }
        controller.onFailure = { [weak self] _ in
            self?.stopExam()
            self?.model.banner = String(localized: "Could not continue the exam. Start a new exam from Teacher.")
        }
        do { _ = try await controller.start(kind, tasks: tasks, format: format, teil: teil, partnerTask: partnerTask) }
        catch { controller.onFailure?(error) }
    }

    /// XR-03: one debrief request for a finished exam; the same call serves the end of the exam and the Retry button.
    /// A second call while one runs, or for a session that already has a debrief, sends nothing. No automatic retry.
    func runDebrief(_ sid: String) {
        guard !model.debriefRunning.contains(sid) else { return }
        model.debriefRunning.insert(sid)
        Task {
            _ = await engine.examDebrief(sid)
            model.debriefRunning.remove(sid)
            model.apply(await store.state)
        }
    }

    /// Leaving a live exam stops it. While a start has no session yet, only the learner's navigation cancels it: the journal
    /// observer may auto-select (often the new exam session itself) before `createSession` returns, and `onStarted` then
    /// selects the exam's own session (F-1).
    func examSelectionChanged(automatic: Bool = false) {
        if let sid = exam?.sessionID, model.selectedSessionID != sid { stopExam() }
        else if model.startingExam && exam?.sessionID == nil && !automatic { stopExam() }
    }

    func stopExam() {
        examStartID = nil
        examStartTask?.cancel(); examStartTask = nil
        exam?.stop(); exam = nil
        turn?.stopVoice(cancelTurn: true)
        turn?.exam = nil
        model.startingExam = false
        model.liveExamSessionID = nil
        model.examRun = nil
        model.examBusy = false
        model.examInputAllowed = false
        model.examFollowUp = false
        model.examSpeaker = nil
        model.goetheNotes = ""
        model.continuous = false
        model.streaming = nil
        model.thinking = false
    }

    /// VoiceIO startup/recovery and phrase playback must preserve the preparation/input gate.
    func restoreExamMicrophone(on sink: SpeechSink) {
        let blocked = model.startingExam || model.examReadOnly || (exam.map { !$0.microphoneAllowed } ?? false)
        sink.micMuted = blocked || (sink.isSpeaking && sink.micMuted)
    }
}
