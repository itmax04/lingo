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

    /// Why an exam cannot start now (BR-33); a refused click must say so instead of doing nothing (H-05).
    private var startRefusal: String? {
        if ending { return Self.stillFinishingText }
        if model.startingExam { return Self.examStartingText }
        if model.readOnly { return model.disabledReason }
        return nil
    }

    /// LINGO-10 BR-08, BR-08a: the Mock tab's Start draws the tasks and opens the preparation. No session exists yet (A-01), the microphone
    /// stays closed, and voice setup starts now so that the end of preparation does not wait for it.
    func beginMockPrep() {
        if let why = startRefusal { model.banner = why; return }
        guard model.mockPrep == nil, !model.goetheLocked, let draw = GoetheHub.drawMock() else { return }
        stopExam()
        model.russianOnce = false; turn?.forceRussianOnce = false
        model.mockPrep = AppModel.MockPrep(draw: draw, startedAt: Date())
        Task { if let tc = await ensureVoice(forExamStart: true) { restoreExamMicrophone(on: tc.sink) } }
    }

    /// BR-08: the learner may change the topic until preparation ends; the other one becomes the partner's.
    func chooseMockTopic(_ index: Int) {
        guard var prep = model.mockPrep, !prep.ended, prep.draw.topics.indices.contains(index) else { return }
        prep.draw.chosen = index
        model.mockPrep = prep
    }

    /// Done, the timer, or Retry: the session is created with the frozen selection and the introduction begins (BR-08a).
    func finishMockPrep() {
        guard var prep = model.mockPrep, let selection = prep.draw.selection, !model.startingExam || prep.failed else { return }
        // N2: a refused Retry changes nothing; the preparation stays as it was and says why. A Done during a running start is ignored (guard above).
        if let why = startRefusal { model.banner = why; return }
        prep.ended = true; prep.failed = false
        model.mockPrep = prep
        model.banner = nil
        startExam(.goetheB1, tasks: selection.tasks, format: .mock, partnerTask: selection.partner)
    }

    /// Finish or leaving the screen discards the preparation: no session, no event, no debrief (BR-08a).
    func discardMockPrep() {
        guard model.mockPrep != nil else { return }
        model.mockPrep = nil
        model.goetheNotes = ""
        stopExam()
        // F3: the voice set up for the preparation is shut down again when no exam took it over.
        // N3: a new preparation started meanwhile keeps the voice it set up.
        Task { if self.exam == nil, !self.model.startingExam, self.model.mockPrep == nil { await self.shutDownVoice() } }
    }

    func startExam(_ kind: ExamKind, tasks: [String]? = nil, format: Activity.Format? = nil, teil: Int? = nil, partnerTask: String? = nil) {
        if let why = startRefusal { model.banner = why; return }
        // BR-37 (F2): a live Mock or its preparation is never replaced by another start; only the Mock's own start passes.
        if format != .mock, model.mockActive { model.banner = String(localized: "Finish the Mock exam first."); return }
        // BR-22: notes written before Start stay for the run (Teil 2 and 3 of a Training, a Mock); stopping the old run clears them.
        let notes = model.goetheNotes
        stopExam()
        model.goetheNotes = format == .mock || (format == .training && (teil == 2 || teil == 3)) ? notes : ""
        let startID = UUID()
        examStartID = startID
        model.startingExam = true
        // N1: remember which preparation this start belongs to; a newer one must not be marked failed.
        let prepStamp = model.mockPrep?.startedAt
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
            guard let tc = await ensureVoice(forExamStart: true), !Task.isCancelled, examStartID == startID else {
                // F1: a start cancelled by navigation (examStartID nil, nothing newer) also leaves the preparation retryable.
                if examStartID == startID || examStartID == nil, model.mockPrep?.startedAt == prepStamp { model.mockPrep?.failed = true }
                return
            }
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
            if controller.run != nil, controller.sessionID != nil { self.model.mockPrep = nil }
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
            guard let self else { return }
            // BR-08a: a failed session creation keeps the Mock preparation and its notes; Retry tries again.
            if self.model.mockPrep != nil {
                let notes = self.model.goetheNotes
                self.stopExam()
                self.model.goetheNotes = notes
                self.model.mockPrep?.failed = true
                self.model.banner = String(localized: "Could not start the Mock exam. Try again.")
                return
            }
            self.stopExam()
            self.model.banner = String(localized: "Could not continue the exam. Start a new exam from Teacher.")
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
        else if model.startingExam && exam?.sessionID == nil && !automatic {
            let notes = model.mockPrep != nil ? model.goetheNotes : ""
            stopExam()
            model.goetheNotes = notes   // BR-08a: a cancelled creation keeps the notes
        }
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
        let blocked = model.startingExam || model.mockPrep != nil || model.examReadOnly || (exam.map { !$0.microphoneAllowed } ?? false)
        sink.micMuted = blocked || (sink.isSpeaking && sink.micMuted)
    }
}
