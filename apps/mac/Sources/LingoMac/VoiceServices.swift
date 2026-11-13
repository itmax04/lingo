import AVFoundation
import AppKit
import Foundation
import LingoCore

/// Voice mode in the app (R-06…R-15, R-42): audio, recognition, `TurnController`, metrics.
@MainActor
extension AppServices {
    /// Loads the recognition model in the background at start-up (≈ 0.7 s; ≈ 760 MB, AC-15).
    func prepareVoice() {
        guard voiceReady == nil else { return }
        let t = Task { () -> Bool in
            do {
                let path = try await ModelStore.macDefault.ensure(.largeV3TurboQ5)
                let w = try await Task.detached { () -> WhisperEngine in
                    let w = try WhisperEngine(modelPath: path.path)
                    w.strategy = .dual
                    w.reducedContext = true
                    w.minAudioContext = 512
                    return w
                }.value
                self.whisper = w
                return true
            } catch {
                self.model.banner = String(localized: "Speech recognition unavailable: \(String(describing: error))")
                return false
            }
        }
        voiceReady = t
    }

    /// Audio and the loop are created on the first voice action (that is when macOS asks for microphone permission).
    func ensureVoice(forExamStart: Bool = false) async -> TurnController? {
        guard forExamStart || !model.examReadOnly else { return nil }
        if let t = turn { restoreExamMicrophone(on: t.sink); return t }
        if Permissions.microphone == .notDetermined { _ = await Permissions.requestMicrophone() }
        guard Permissions.microphone == .granted else {
            model.banner = String(localized: "No microphone access: System Settings → Privacy & Security → Microphone → Lingo")
            return nil
        }
        prepareVoice()
        guard await voiceReady?.value == true, let w = whisper else { return nil }
        // Finish may have run while the model was loading: a finished session must not get the microphone back.
        guard !ending, forExamStart || (model.selectedSession?.state != .ended && !model.examReadOnly), !Task.isCancelled else { return nil }
        if let t = turn { restoreExamMicrophone(on: t.sink); return t }
        plainSpeech.stopSpeaking(at: .immediate)  // its sound is unknown to echo cancellation; never let it overlap live voice
        let io = VoiceIO()
        do { try io.start(voiceProcessing: settings.voice.voiceProcessing, output: true) } catch {
            model.banner = String(localized: "Audio: \(error.localizedDescription)")
            return nil
        }
        if !io.voiceProcessing { model.banner = String(localized: "Echo cancellation unavailable — headphones work better for barge-in") }
        let metrics = MetricsRecorder(dir: store.base.appendingPathComponent("metrics", isDirectory: true))
        let m = model
        let tc = TurnController(engine: engine, recognizer: w, sink: io, metrics: metrics, voice: settings.voice) {
            guard let s = m.selectedSession else { return nil }
            let msgs = m.messages
            return TurnController.Context(session: s, lastAssistant: msgs.last { $0.role == .assistant && $0.kind == .normal },
                                          lastUser: msgs.last { $0.role == .user }, phrases: m.phrases.map(\.text),
                                          targets: m.history.vocabTargets(session: s.id).map(\.text))
        }
        tc.onState = { [weak tc] s in
            m.voiceState = s
            // "I'm speaking Russian" applies to one utterance (R-09): after it the button turns off.
            if let tc { m.russianOnce = tc.forceRussianOnce }
        }
        tc.onLevel = { l in
            m.levels.append(l)
            if m.levels.count > 160 { m.levels.removeFirst(m.levels.count - 160) }
        }
        tc.onNotice = { n in m.banner = n }
        tc.onFinishCommand = { [weak self] sid in Task { @MainActor in self?.finishSession(sid) } }
        tc.onEndedSession = { [weak self] in Task { @MainActor in await self?.shutDownVoice() } }
        tc.onTurn = { [weak self] e in self?.turnEvent(e) }
        io.onSamples = { s in Task { @MainActor in tc.feed(s) } }
        io.onPlaybackStarted = { tag, ns in Task { @MainActor in tc.playbackStarted(tag: tag, uptimeNs: ns) } }
        io.onIdle = { [weak self] in Task { @MainActor in self?.restoreExamMicrophone(on: io) } }
        io.onRestart = { [weak self] reason, ok in
            Log.app.notice("voice restarted: \(reason, privacy: .public)")
            Task { @MainActor in
                self?.restoreExamMicrophone(on: io)
                if !ok { m.banner = reason }
            }
        }
        io.onCaptureFailure = { [weak tc] reason in
            Task { @MainActor in
                tc?.stopVoice()
                m.continuous = false
                m.levels = []
                m.banner = reason
            }
        }
        voiceIO = io
        turn = tc
        tc.exam = exam
        restoreExamMicrophone(on: io)
        // Audio watchdog: once a second check that the microphone delivers samples (the engine may have stopped).
        healthTimer = Task { @MainActor in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                io.checkHealth()
            }
        }
        // Memory once a minute (AC-15).
        memoryTimer = Task {
            while !Task.isCancelled {
                metrics.memorySample()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        if let s = model.selectedSession {
            for l in Set([s.settings.lang, .ru]) { io.warmUp(lang: l, voiceID: settings.voice.voiceIDs[l]) }
        }
        return tc
    }

    func turnEvent(_ e: TurnEvent) {
        switch e {
        case .partial(let t): model.streaming = t
        case .restart: model.streaming = ""
        case .attempt(let s): model.streamingSource = s.label
        case .keyInvalid(let id, let reason): updateSettings { $0.llm.markInvalid(keyID: id, reason: reason) }
        case .finished, .failed, .cancelled: model.streaming = nil
        default: break
        }
    }

    // MARK: Panel actions (R-42) and keyboard (DESIGN.md §8)

    /// Microphone button: push-to-talk — start/finish the utterance (S-02); in continuous mode — stop the speech (R-12).
    func micTapped() {
        guard !ending, model.selectedSession?.state != .ended else { return }
        Task {
            guard let t = await ensureVoice() else { return }
            voiceIO?.checkHealth(stallSeconds: 0.5)
            if t.mode == .continuous {
                if voiceIO?.isSpeaking == true { t.cancel() }
                return
            }
            if t.state == .recording { t.pushUp() } else { t.pushDown() }
        }
    }

    func toggleContinuous() {
        guard !ending, model.selectedSession?.state != .ended else { return }
        Task {
            guard let t = await ensureVoice() else { return }
            if t.mode == .continuous { t.stopVoice() } else { t.startContinuous() }
            model.continuous = t.mode == .continuous
        }
    }

    func pauseTapped() { turn?.togglePause() }

    /// "Finish" (R-07, R-22): everything in flight stops, a fixed goodbye is spoken, the session ends, voice turns off.
    /// A second click (or a click on a finished session) does nothing.
    func endTapped() {
        guard let sid = model.selectedSessionID else { return }
        finishSession(sid)
    }

    /// The one way to finish a session: the button, "that's all" by voice and "that's all" typed all end here.
    func finishSession(_ sid: String) {
        guard !ending else { return }
        ending = true
        if model.startingExam || exam?.sessionID == sid { stopExam() }
        // Nothing may go on generating or speaking after "Finish": cancel the voice turn and the text turn that are in flight.
        turn?.stopVoice(cancelTurn: true)
        turnTask?.cancel()
        voiceIO?.stopSpeaking()
        model.continuous = false
        model.thinking = false
        model.streaming = nil
        let note = String(localized: "Finishing the session…")
        model.banner = note
        finishNote = note
        let fid = UUID()
        finishID = fid
        // 15 s: the goodbye wait (8 s) plus the teardown. Whatever happens to the task below, `ending` is released here.
        finishWatchdog?.cancel()
        finishWatchdog = Task { [weak self] in
            guard let timeout = self?.finishTimeout else { return }
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.releaseFinish(fid, timedOut: true)
        }
        Task {
            defer { releaseFinish(fid) }
            // `farewell` is nil for a missing or already finished session: then nothing is added or spoken.
            if let bye = await engine.farewell(session: sid), let io = voiceIO, finishID == fid {
                io.speak(bye.text, lang: bye.lang, voiceID: settings.voice.voiceIDs[bye.lang], rate: SpeechPace(base: settings.voice.pace).rate(multiplier: 1), tag: 9_000)
            }
            // The finished state is written first; once the goodbye has played the microphone is switched off and the app is free again.
            // The recap and the summary (model calls, they can take a while on a degraded chain) follow without blocking anything.
            let ended = await engine.markEnded(sid)
            // After a release (the watchdog fired) this task must not touch the audio any more.
            if finishID == fid {
                if let teardown = finishTeardown { await teardown() } else { await shutDownVoice() }
            }
            releaseFinish(fid)
            // The recap and summary belong to the finished part, so they are written before a queued "Continue".
            if ended { await engine.finalizeEnded(sid) }
            if ended, model.sessions.first(where: { $0.id == sid })?.settings.activity?.kind == .exam { runDebrief(sid) }
            if let c = pendingContinue { pendingContinue = nil; try? await engine.resume(c) }
            await scheduler?.trigger(.sessionEnded)
        }
    }

    /// The one place that ends "finishing": idempotent, and only for the finish it belongs to.
    func releaseFinish(_ id: UUID, timedOut: Bool = false) {
        guard finishID == id else { return }
        finishID = nil
        finishWatchdog?.cancel()
        finishWatchdog = nil
        ending = false
        if model.banner == finishNote || model.banner == Self.stillFinishingText { model.banner = nil }
        finishNote = nil
        if timedOut {
            pendingContinue = nil
            model.banner = String(localized: "Finishing the session took too long and was stopped. You can start again.")
        }
    }

    /// "Continue session" on the "Session finished" card (R-01): the only way back into a finished session.
    func continueSession() {
        guard let sid = model.selectedSessionID, model.canContinue else { return }
        // Pressed while the goodbye is still playing: continue as soon as finishing is done (no click is lost).
        if ending { pendingContinue = sid; return }
        plainSpeech.stopSpeaking(at: .immediate)
        Task { try? await engine.resume(sid) }
    }

    /// After "Finish" the microphone is switched off completely (the macOS microphone indicator goes out): the goodbye is
    /// allowed to finish first. The next voice action creates audio again.
    func shutDownVoice() async {
        if let io = voiceIO {
            let deadline = Date().addingTimeInterval(8)
            while io.isSpeaking, Date() < deadline { try? await Task.sleep(for: .milliseconds(100)) }
            // The controller stops the speech through the sink, so it goes first: after `io.stop()` the audio objects are gone.
            turn?.stopVoice(cancelTurn: true)
            io.stop()
            // Release everything that keeps the old audio and loop alive (they are rebuilt by the next voice action).
            io.onSamples = nil
            io.onPlaybackStarted = nil
            io.onIdle = nil
            io.onRestart = nil
            io.onCaptureFailure = nil
        }
        healthTimer?.cancel()
        healthTimer = nil
        memoryTimer?.cancel()
        memoryTimer = nil
        turn?.stopVoice(cancelTurn: true)
        turn = nil
        voiceIO = nil
        model.continuous = false
        model.voiceState = .idle
        model.levels = []
    }

    func spaceDown() { guard !ending, model.selectedSession?.state != .ended else { return }; Task { guard let t = await ensureVoice() else { return }; if t.mode == .pushToTalk { t.pushDown() } else { t.cancel() } } }
    func spaceUp() { if turn?.mode == .pushToTalk { turn?.pushUp() } }
    func escape() { turn?.cancel(); plainSpeech.stopSpeaking(at: .immediate) }
    func toggleRussian() {
        guard !model.mockAidsOff else { return }  // LINGO-10 BR-20: ⌥R has no effect in a Mock
        model.russianOnce.toggle()
        turn?.forceRussianOnce = model.russianOnce
    }
    func toggleSlowPace() {
        model.slowPace.toggle()
        turn?.slowPace = model.slowPace
    }

    /// ▶ on a hint phrase (R-27): the voice of the phrase's language, offline; the microphone does not listen; if the assistant is speaking — queued.
    func playPhrase(_ p: Phrase, slow: Bool = false) {
        if let io = voiceIO, ending {
            // The goodbye is still playing through the audio engine: queue behind it instead of a second synthesizer.
            io.speak(p.text, lang: p.lang, voiceID: settings.voice.voiceIDs[p.lang], rate: SpeechPace(base: settings.voice.pace).rate(multiplier: slow ? 0.75 : 1), tag: 50_000)
            return
        }
        if model.selectedSession?.state == .ended || model.examReadOnly || ending {
            speakWithoutMicrophone(p.text, lang: p.lang)
            return
        }
        Task {
            if voiceIO == nil { _ = await ensureVoice() }
            guard let io = voiceIO else { return }
            io.playPhrase(p.text, lang: p.lang, voiceID: settings.voice.voiceIDs[p.lang],
                          rate: SpeechPace(base: settings.voice.pace).rate(multiplier: slow ? 0.75 : 1), tag: 50_000)
        }
    }

    func toggleStar(_ p: Phrase) {
        let on = !model.starred.contains(p.id)
        Task { try? await engine.star(p, on: on) }
    }

    /// Click on an assistant bubble — replay speech (R-41).
    func replay(_ m: ChatMessage) {
        if model.selectedSession?.state == .ended || model.examReadOnly || ending {
            // A finished session must not switch the microphone back on just to replay a line.
            let parts: [(Lang, String)] = (m.segments.isEmpty ? [.say(m.lang, m.spokenText)] : m.segments).compactMap { if case .say(let l, let t) = $0 { return (l, t) }; return nil }
            if let io = voiceIO {
                // The goodbye is still playing through the audio engine: queue behind it.
                for (l, t) in parts { io.speak(t, lang: l, voiceID: settings.voice.voiceIDs[l], rate: SpeechPace(base: settings.voice.pace).rate(multiplier: model.slowPace ? 0.75 : 1), tag: 9_100) }
            } else {
                plainSpeech.stopSpeaking(at: .immediate)  // a new replay replaces the previous one, as in TurnController.replay
                for (l, t) in parts { speakWithoutMicrophone(t, lang: l, stopPrevious: false) }
            }
            return
        }
        Task { guard let t = await ensureVoice() else { return }; t.replay(m) }
    }

    /// Plays text through the system speech synthesizer only: no audio engine, no input tap, so the microphone stays off.
    func speakWithoutMicrophone(_ text: String, lang: Lang, stopPrevious: Bool = true) {
        if stopPrevious { plainSpeech.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = Voices.voice(for: lang, preferred: settings.voice.voiceIDs[lang])
        u.rate = SpeechPace(base: settings.voice.pace).rate(multiplier: model.slowPace ? 0.75 : 1)
        plainSpeech.speak(u)
    }
}
