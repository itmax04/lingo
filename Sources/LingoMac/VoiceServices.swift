import AppKit
import Foundation
import LingoCore

/// Голосовой режим в приложении (R-06…R-15, R-42): звук, распознавание, `TurnController`, метрики.
@MainActor
extension AppServices {
    /// Загрузка модели распознавания в фоне при старте (≈ 0,7 с; ≈ 760 МБ, AC-15).
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
                self.model.banner = "Распознавание недоступно: \(error)"
                return false
            }
        }
        voiceReady = t
    }

    /// Звук и цикл создаются при первом голосовом действии (тогда же macOS спрашивает разрешение на микрофон).
    func ensureVoice() async -> TurnController? {
        if let t = turn { return t }
        if Permissions.microphone == .notDetermined { _ = await Permissions.requestMicrophone() }
        guard Permissions.microphone == .granted else {
            model.banner = "Нет доступа к микрофону: Системные настройки → Конфиденциальность и безопасность → Микрофон → Lingo"
            return nil
        }
        prepareVoice()
        guard await voiceReady?.value == true, let w = whisper else { return nil }
        let io = VoiceIO()
        do { try io.start(voiceProcessing: settings.voice.voiceProcessing, output: true) } catch {
            model.banner = "Звук: \(error.localizedDescription)"
            return nil
        }
        if !io.voiceProcessing { model.banner = "Эхоподавление недоступно — для перебивания лучше наушники" }
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
            // «Говорю по-русски» действует на одну реплику (R-09): после неё кнопка гаснет.
            if let tc { m.russianOnce = tc.forceRussianOnce }
        }
        tc.onLevel = { l in
            m.levels.append(l)
            if m.levels.count > 160 { m.levels.removeFirst(m.levels.count - 160) }
        }
        tc.onNotice = { n in m.banner = n }
        tc.onTurn = { [weak self] e in self?.turnEvent(e) }
        io.onSamples = { s in Task { @MainActor in tc.feed(s) } }
        io.onPlaybackStarted = { tag, ns in Task { @MainActor in tc.playbackStarted(tag: tag, uptimeNs: ns) } }
        io.onIdle = { Task { @MainActor in io.micMuted = false } }
        voiceIO = io
        turn = tc
        // Память раз в минуту (AC-15).
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

    // MARK: Действия панели (R-42) и клавиатура (DESIGN.md §8)

    /// Кнопка микрофона: по кнопке — начать/закончить реплику (S-02); в непрерывном режиме — остановить озвучку (R-12).
    func micTapped() {
        Task {
            guard let t = await ensureVoice() else { return }
            if t.mode == .continuous {
                if voiceIO?.isSpeaking == true { t.cancel() }
                return
            }
            if t.state == .recording { t.pushUp() } else { t.pushDown() }
        }
    }

    func toggleContinuous() {
        Task {
            guard let t = await ensureVoice() else { return }
            if t.mode == .continuous { t.stopVoice() } else { t.startContinuous() }
            model.continuous = t.mode == .continuous
        }
    }

    func pauseTapped() { turn?.togglePause() }

    /// «Завершить» (R-07, R-22): прощание, итог при режиме «после», голос выключается.
    func endTapped() {
        guard let sid = model.selectedSessionID else { return }
        turn?.stopVoice()
        model.continuous = false
        Task {
            for await e in engine.respond(session: sid, command: .finish) { turnEvent(e)
                if case .speak(let l, let t) = e, let io = voiceIO {
                    io.speak(t, lang: l, voiceID: settings.voice.voiceIDs[l], rate: SpeechPace(base: settings.voice.pace).rate(multiplier: 1), tag: 9_000)
                }
            }
            await engine.end(sid)
            await scheduler?.trigger(.sessionEnded)
        }
    }

    func spaceDown() { Task { guard let t = await ensureVoice() else { return }; if t.mode == .pushToTalk { t.pushDown() } else { t.cancel() } } }
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

    /// ▶ фразы подсказки (R-27): голос языка фразы, без сети; микрофон не слушает; если помощник говорит — в очередь.
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

    /// Клик по пузырю помощника — повтор озвучки (R-41).
    func replay(_ m: ChatMessage) {
        Task { guard let t = await ensureVoice() else { return }; t.replay(m) }
    }
}
