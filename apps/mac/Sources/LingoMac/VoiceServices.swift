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
    func ensureVoice() async -> TurnController? {
        if let t = turn { return t }
        if Permissions.microphone == .notDetermined { _ = await Permissions.requestMicrophone() }
        guard Permissions.microphone == .granted else {
            model.banner = String(localized: "No microphone access: System Settings → Privacy & Security → Microphone → Lingo")
            return nil
        }
        prepareVoice()
        guard await voiceReady?.value == true, let w = whisper else { return nil }
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
                                          lastUser: msgs.last { $0.role == .user }, phrases: m.phrases.map(\.text))
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
        tc.onTurn = { [weak self] e in self?.turnEvent(e) }
        io.onSamples = { s in Task { @MainActor in tc.feed(s) } }
        io.onPlaybackStarted = { tag, ns in Task { @MainActor in tc.playbackStarted(tag: tag, uptimeNs: ns) } }
        io.onIdle = { Task { @MainActor in io.micMuted = false } }
        io.onRestart = { reason, ok in
            Log.app.notice("voice restarted: \(reason, privacy: .public)")
            if !ok { Task { @MainActor in m.banner = reason } }
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
        guard !ending else { return }
        Task {
            guard let t = await ensureVoice() else { return }
            voiceIO?.checkHealth(stallSeconds: 0.5)
            if t.mode == .continuous {
                if voiceIO?.isSpeaking == true { t.cancel() }
                return
            }
            if t.state == .recording { t.pushUp() } else { await resumeIfEnded(); t.pushDown() }
        }
    }

    func toggleContinuous() {
        guard !ending else { return }
        Task {
            guard let t = await ensureVoice() else { return }
            if t.mode == .continuous { t.stopVoice() } else { await resumeIfEnded(); t.startContinuous() }
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
        // Nothing may go on generating or speaking after "Finish": cancel the voice turn and the text turn that are in flight.
        turn?.stopVoice(cancelTurn: true)
        turnTask?.cancel()
        voiceIO?.stopSpeaking()
        model.continuous = false
        model.thinking = false
        model.streaming = nil
        let note = String(localized: "Finishing the session…")
        model.banner = note
        Task {
            defer {
                ending = false
                if model.banner == note { model.banner = nil }
            }
            // `farewell` is nil for a missing or already finished session: then nothing is added or spoken.
            if let bye = await engine.farewell(session: sid), let io = voiceIO {
                io.speak(bye.text, lang: bye.lang, voiceID: settings.voice.voiceIDs[bye.lang], rate: SpeechPace(base: settings.voice.pace).rate(multiplier: 1), tag: 9_000)
            }
            await engine.end(sid)
            await scheduler?.trigger(.sessionEnded)
        }
    }

    /// Speaking in a finished session continues it (R-01), like sending text does. `engine.resume` checks the journal itself,
    /// so it is safe to call whenever the learner starts to talk (the window model may lag behind the journal).
    func resumeIfEnded() async {
        guard let sid = model.selectedSessionID else { return }
        try? await engine.resume(sid)
    }

    func spaceDown() { guard !ending else { return }; Task { guard let t = await ensureVoice() else { return }; if t.mode == .pushToTalk { await resumeIfEnded(); t.pushDown() } else { t.cancel() } } }
    func spaceUp() { if turn?.mode == .pushToTalk { turn?.pushUp() } }
    func escape() { turn?.cancel() }
    func toggleRussian() {
        model.russianOnce.toggle()
        turn?.forceRussianOnce = model.russianOnce
    }
    func toggleSlowPace() {
        model.slowPace.toggle()
        turn?.slowPace = model.slowPace
    }

    /// ▶ on a hint phrase (R-27): the voice of the phrase's language, offline; the microphone does not listen; if the assistant is speaking — queued.
    func playPhrase(_ p: Phrase) {
        Task {
            if voiceIO == nil { _ = await ensureVoice() }
            guard let io = voiceIO else { return }
            io.playPhrase(p.text, lang: p.lang, voiceID: settings.voice.voiceIDs[p.lang],
                          rate: SpeechPace(base: settings.voice.pace).rate(multiplier: 1), tag: 50_000)
        }
    }

    func toggleStar(_ p: Phrase) {
        let on = !model.starred.contains(p.id)
        Task { try? await engine.star(p, on: on) }
    }

    /// Click on an assistant bubble — replay speech (R-41).
    func replay(_ m: ChatMessage) {
        Task { guard let t = await ensureVoice() else { return }; t.replay(m) }
    }
}
