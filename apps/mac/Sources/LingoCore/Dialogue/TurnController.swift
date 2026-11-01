import Foundation

/// Speech output for the voice loop (implemented by `VoiceIO`; a fake in tests).
@MainActor
public protocol SpeechSink: AnyObject {
    func speak(_ text: String, lang: Lang, voiceID: String?, rate: Float, pauseAfter: Double, tag: Int)
    @discardableResult func stopSpeaking() -> (tag: Int, charOffset: Int)?
    var isSpeaking: Bool { get }
    var micMuted: Bool { get set }
}

extension VoiceIO: SpeechSink {}

/// Voice loop (R-06…R-15, S-02…S-07): push-to-talk/space and continuous mode, end of utterance by pause T, merging within G,
/// barge-in, local "repeat" and "slower", turns through `DialogEngine`, sentence-by-sentence speech, turn metrics.
@MainActor
public final class TurnController {
    public enum Mode: Sendable { case pushToTalk, continuous }

    public struct Context: Sendable {
        public var session: Session
        public var lastAssistant: ChatMessage?
        public var lastUser: ChatMessage?
        public var phrases: [String]
        /// The learner's vocabulary targets of the session (VR-07c): a hint for speech recognition.
        public var targets: [String] = []
        public init(session: Session, lastAssistant: ChatMessage?, lastUser: ChatMessage?, phrases: [String], targets: [String] = []) {
            self.session = session
            self.lastAssistant = lastAssistant
            self.lastUser = lastUser
            self.phrases = phrases
            self.targets = targets
        }
    }

    // Dependencies
    public let engine: DialogEngine
    public let recognizer: SpeechRecognizer
    public let sink: SpeechSink
    public let metrics: MetricsRecorder?
    public var voice: VoiceSettings
    public var context: () -> Context?

    // Outputs
    public private(set) var state: VoiceState = .idle { didSet { if state != oldValue { onState?(state) } } }
    public var onState: ((VoiceState) -> Void)?
    public var onLevel: ((Float) -> Void)?
    public var onTurn: ((TurnEvent) -> Void)?
    public var onNotice: ((String) -> Void)?
    /// The learner said "that's all" (R-22). Their line is saved, no model reply is requested; the app ends the session with its own goodbye.
    public var onFinishCommand: ((String) -> Void)?
    /// An utterance arrived for a finished session (for example the learner selected a finished session while voice was on):
    /// it is dropped, voice stops, and the app should switch the microphone off.
    public var onEndedSession: (() -> Void)?
    public private(set) var mode: Mode = .pushToTalk
    /// "I'm speaking Russian" (R-09): the next single utterance is recognized as Russian.
    public var forceRussianOnce = false
    /// "Slow pace" in the header (R-15): all replies at ×0.75.
    public var slowPace = false

    // Audio
    private var vad: EnergyVAD
    private var segmenter: TurnSegmenter
    private var buffer: [Float] = []
    private var bufferStart = 0          // absolute index of the first sample in the buffer
    private var clock = 0                // absolute index of the next sample
    private var recording = false        // button/space
    private var paused = false

    // Turn
    private var turnTask: Task<Void, Never>?
    private var turnSeq = 0
    private var currentTurnID = ""
    private var spokenParts: [(tag: Int, text: String)] = []
    private var nextTag = 1
    private var speakingTurn: String?
    private var interruptedAt: Int?
    private var lastSpeechEnd: Double = 0
    private var slowStep = 0
    private var lastUserID: String?
    private var lastUserText = ""
    private var answerStarted = false
    /// The assistant message currently being spoken (after it was written to the journal).
    private var speakingMessageID: String?
    private var speakingSessionID: String?
    private var recordStartedAt: Double = 0
    private var recordPeakDB: Float = -120
    private var silentWarned = false

    public init(engine: DialogEngine, recognizer: SpeechRecognizer, sink: SpeechSink, metrics: MetricsRecorder?,
                voice: VoiceSettings, context: @escaping () -> Context?) {
        self.engine = engine
        self.recognizer = recognizer
        self.sink = sink
        self.metrics = metrics
        self.voice = voice
        self.context = context
        self.vad = EnergyVAD(config: VoiceDefaults.vad)
        self.segmenter = TurnSegmenter(config: voice.turn)
    }

    var seconds: Double { Double(clock) / 16_000 }

    // MARK: Control (R-06, R-07, R-12)

    public func startContinuous() {
        mode = .continuous
        paused = false
        segmenter = TurnSegmenter(config: voice.turn)
        if state == .idle || state == .paused { state = .listening }
    }

    /// `cancelTurn` (the "Finish" button, R-22): also cancel the turn that is still being recognised or generated, so that no
    /// further reply is produced or spoken after the owner ended the conversation. Turning continuous mode off keeps the running turn.
    public func stopVoice(cancelTurn: Bool = false) {
        mode = .pushToTalk
        recording = false
        paused = false
        interrupt(reason: "stop")
        if cancelTurn {
            turnTask?.cancel()
            turnTask = nil
            speakingTurn = nil
            currentTurnID = ""
            answerStarted = false
        }
        state = .idle
    }

    /// "Pause": listening and speech are suspended (R-07).
    public func togglePause() {
        if paused {
            paused = false
            state = mode == .continuous ? .listening : .idle
        } else {
            paused = true
            interrupt(reason: "pause")
            state = .paused
        }
    }

    /// Space/button pressed (R-06): start recording; while speaking — stop the speech (R-12).
    public func pushDown() {
        if sink.isSpeaking { interrupt(reason: "key") }
        recording = true
        segmenter = TurnSegmenter(config: voice.turn)
        recordStartedAt = seconds
        recordPeakDB = -120
        silentWarned = false
        // If speech is already under way (the user started a little before pressing), the utterance starts now.
        if vad.isSpeech { _ = segmenter.speechStarted(at: max(0, seconds - 0.3)) }
        state = .recording
    }

    /// Space/button released: the utterance is finished.
    public func pushUp() {
        guard recording else { return }
        recording = false
        let ev = segmenter.flush(at: seconds)
        handle(ev)
        if !ev.contains(where: { if case .utterance = $0 { return true }; if case .merged = $0 { return true }; return false }) {
            state = mode == .continuous ? .listening : .idle
        }
    }

    /// Esc (R-06, R-12): cancel the utterance and stop speech.
    public func cancel() {
        recording = false
        segmenter = TurnSegmenter(config: voice.turn)
        interrupt(reason: "esc")
        state = mode == .continuous ? .listening : .idle
    }

    // MARK: Audio

    public func feed(_ s: [Float]) {
        let level = min(1, max(0, (EnergyVAD.rmsDB(s[...]) + 60) / 50))
        onLevel?(level)
        buffer.append(contentsOf: s)
        clock += s.count
        let cap = Int(UtteranceBuffer.maxSeconds * 16_000)
        if buffer.count > cap { let drop = buffer.count - cap; buffer.removeFirst(drop); bufferStart += drop }
        // The VAD always listens (the noise floor and the "speech" state do not get stuck between push-to-talk recordings);
        // events go to the segmenter only while recording is active.
        // While speaking the threshold is higher: our own echo does not count as barge-in (R-12).
        vad.extraMarginDB = sink.isSpeaking ? voice.bargeInMarginDB : 0
        let base = clock - s.count
        let events = vad.processEvents(s)
        guard !paused, recording || mode == .continuous else { return }
        for e in events {
            let t = Double(base + e.sampleOffset) / 16_000
            if e.isSpeech {
                let ev = segmenter.speechStarted(at: max(0, t - Double(VoiceDefaults.vad.attackFrames * VoiceDefaults.vad.frameMs) / 1000))
                // Barge-in (R-12): user speech during playback — stop within 0.5 s.
                if sink.isSpeaking { interrupt(reason: "barge-in") }
                handle(ev)
            } else {
                handle(segmenter.speechEnded(at: t - Double(VoiceDefaults.vad.hangoverMs) / 1000))
            }
        }
        // With the button the utterance also ends by itself after pause T (as in continuous mode); a second press ends it at once.
        let ev = segmenter.advance(to: seconds)
        if recording, ev.contains(where: { if case .utterance = $0 { return true }; return false }) { recording = false }
        handle(ev)
        // The microphone is silent while recording — show a hint (wrong input, muted, no access).
        if recording {
            recordPeakDB = max(recordPeakDB, EnergyVAD.rmsDB(s[...]))
            if seconds - recordStartedAt > 4, recordPeakDB < -65, !silentWarned {
                silentWarned = true
                onNotice?(String(localized: "The microphone gives no sound: check the input in System Settings → Sound → Input"))
            }
        }
    }

    private func handle(_ events: [TurnSegmenter.Event]) {
        for e in events {
            switch e {
            case .speechBegan:
                if state == .listening || state == .thinking { /* merging is decided at the end of the utterance */ }
            case .utterance(let span):
                process(span: span, merge: false)
            case .merged(_, let span):
                process(span: span, merge: true)
            case .discarded:
                break
            }
        }
    }

    private func samples(_ span: TurnSegmenter.Span) -> [Float] {
        let a = max(bufferStart, Int((span.start - 0.2) * 16_000)), b = min(clock, Int((span.end + 0.25) * 16_000))
        guard b > a else { return [] }
        return Array(buffer[(a - bufferStart)..<(b - bufferStart)])
    }

    // MARK: Utterance → turn

    private func process(span: TurnSegmenter.Span, merge: Bool) {
        guard let ctx = context() else { onNotice?(String(localized: "No session selected")); return }
        guard ctx.session.state != .ended else {
            stopVoice()
            onEndedSession?()
            return
        }
        let study = ctx.session.settings.lang
        // Merging (R-11): the assistant has not started speaking yet → cancel the pending request and send the combined text.
        let doMerge = merge && !answerStarted && lastUserID != nil
        if doMerge { turnTask?.cancel() } else if turnTask != nil { /* the previous turn finishes on its own */ }
        let audio = samples(span)
        let forced: Lang? = forceRussianOnce ? .ru : nil
        forceRussianOnce = false
        turnSeq += 1
        let turnID = "t\(turnSeq)-\(Int(Date().timeIntervalSince1970))"
        currentTurnID = turnID
        let speechEnd = MetricsRecorder.now() - (seconds - span.end)
        metrics?.mark(turnID, "speech_end", at: speechEnd)
        lastSpeechEnd = speechEnd
        state = .thinking
        answerStarted = false
        let recCtx = RecognitionContext.make(lastAssistant: ctx.lastAssistant?.spokenText, topic: ctx.session.settings.topic, phrases: ctx.phrases, targets: ctx.targets)
        let prevID = lastUserID, prevText = lastUserText
        turnTask = Task { [weak self] in
            guard let self else { return }
            let tr: Transcription
            do {
                tr = try await self.recognizer.transcribe(audio, candidates: [study, .ru], forced: forced, context: recCtx)
            } catch {
                if Task.isCancelled { return }  // "Finish" or a merge cancelled the turn: not an error
                self.onNotice?(String(localized: "Speech recognition: \(String(describing: error))"))
                self.state = self.mode == .continuous ? .listening : .idle
                return
            }
            if Task.isCancelled { return }
            self.metrics?.mark(turnID, "stt_final")
            self.metrics?.note(turnID, "lang", tr.lang.rawValue)
            self.metrics?.note(turnID, "chars", String(tr.text.count))
            let text = tr.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                self.state = self.mode == .continuous ? .listening : .idle
                return
            }
            if doMerge, let pid = prevID {
                let merged = prevText + " " + text
                try? await self.engine.edit(pid, session: ctx.session.id, text: merged)
                self.lastUserText = merged
                self.metrics?.note(turnID, "merged", "1")
                await self.runTurn(self.engine.respond(session: ctx.session.id, replyTo: pid), turnID: turnID, ctx: ctx)
                return
            }
            let cmd = CommandDetector.detect(text)
            if let c = cmd?.kind, c.isLocal {
                self.metrics?.note(turnID, "command", c.rawValue)
                _ = try? await self.engine.recordUser(session: ctx.session.id, text: text, lang: tr.lang)
                self.replayLast(ctx: ctx, slower: c == .slower, turnID: turnID)
                return
            }
            if cmd?.kind == .finish {
                self.metrics?.note(turnID, "command", CommandKind.finish.rawValue)
                _ = try? await self.engine.recordUser(session: ctx.session.id, text: text, lang: tr.lang)
                if !Task.isCancelled { self.onFinishCommand?(ctx.session.id) }
                return
            }
            if c(cmd) != .slower { self.slowStep = 0 }
            await self.runTurn(self.engine.send(session: ctx.session.id, text: text, lang: tr.lang, command: cmd?.kind), turnID: turnID, ctx: ctx)
        }
    }

    private nonisolated func c(_ m: CommandMatch?) -> CommandKind? { m?.kind }

    private func runTurn(_ stream: AsyncStream<TurnEvent>, turnID: String, ctx: Context) async {
        spokenParts = []
        interruptedAt = nil
        speakingTurn = turnID
        speakingMessageID = nil
        speakingSessionID = ctx.session.id
        let rate = SpeechPace(base: voice.pace).rate(multiplier: slowPace ? 0.75 : 1)
        for await e in stream {
            onTurn?(e)
            switch e {
            case .userSaved(let id):
                lastUserID = id
                lastUserText = (await engine.store.state.messages[ctx.session.id]?.first { $0.id == id }?.text) ?? lastUserText
            case .firstToken:
                metrics?.mark(turnID, "llm_first_token")
            case .speak(let l, let t):
                guard speakingTurn == turnID, interruptedAt == nil, !paused else { continue }
                let tag = nextTag
                nextTag += 1
                spokenParts.append((tag, t))
                if !answerStarted {
                    answerStarted = true
                    segmenter.assistantStartedSpeaking()
                }
                sink.speak(t, lang: l, voiceID: voice.voiceIDs[l], rate: rate, pauseAfter: 0, tag: tag)
                state = .speaking
            case .restart:
                if speakingTurn == turnID { sink.stopSpeaking(); spokenParts = [] }
            case .finished(let mid, _, _, _):
                if speakingTurn == turnID { speakingMessageID = mid }
                if let at = interruptedAt, speakingTurn == turnID || speakingTurn == nil {
                    try? await engine.markInterrupted(mid, session: ctx.session.id, at: at)
                    metrics?.note(turnID, "interrupted_at", String(at))
                }
                metrics?.note(turnID, "message", mid)
            case .failed(let reason, _):
                metrics?.note(turnID, "failed", String(reason.prefix(60)))
                onNotice?(String(localized: "Models are unavailable"))
            default:
                break
            }
        }
        await waitSpeechEnd()
        metrics?.mark(turnID, "reply_end")
        metrics?.flush(turnID)
        if currentTurnID == turnID, state == .speaking || state == .thinking {
            state = paused ? .paused : (mode == .continuous ? .listening : .idle)
        }
    }

    private func waitSpeechEnd() async {
        // A cancelled task must not spin here: Task.sleep throws at once on cancellation.
        while sink.isSpeaking, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
    }

    /// First audio of a reply part (from `VoiceIO.onPlaybackStarted`) — the `first_audio` metric.
    public func playbackStarted(tag: Int, uptimeNs: UInt64) {
        guard spokenParts.first?.tag == tag, let t = speakingTurn else { return }
        metrics?.mark(t, "first_audio", at: Double(uptimeNs) / 1e9)
    }

    /// Where speech stopped, in Characters of the spoken text (R-12), the unit the readers use (`spokenText.prefix(at)`; LINGO-03
    /// D-05). The speech engine reports a UTF-16 position inside the part (word markers and `NSString` lengths), so emoji no longer
    /// shift the mark; parts are joined by one space, as in `spokenText`.
    static func interruptionOffset(parts: [(tag: Int, text: String)], stopTag: Int, utf16Offset: Int) -> Int {
        var offset = 0
        for p in parts {
            if p.tag == stopTag {
                let units = Array(p.text.utf16.prefix(max(0, utf16Offset)))
                return offset + String(decoding: units, as: UTF16.self).count
            }
            offset += p.text.count + 1
        }
        return offset
    }

    /// Stop speech; remember where it was interrupted (R-12).
    private func interrupt(reason: String) {
        guard let stop = sink.stopSpeaking() else { return }
        let offset = Self.interruptionOffset(parts: spokenParts, stopTag: stop.tag, utf16Offset: stop.charOffset)
        interruptedAt = offset
        if let t = speakingTurn { metrics?.note(t, "interrupt", reason) }
        // The reply is already in the journal — mark it "interrupted" now (R-12); otherwise — when the reply is written.
        if let mid = speakingMessageID, let sid = speakingSessionID {
            let e = engine
            Task { try? await e.markInterrupted(mid, session: sid, at: offset) }
            speakingMessageID = nil
        }
        Log.turns.notice("interrupt reason=\(reason, privacy: .public) at=\(offset, privacy: .public)")
    }

    // MARK: "Repeat", "Slower" (R-14, R-15)

    private func replayLast(ctx: Context, slower: Bool, turnID: String) {
        guard let last = ctx.lastAssistant else { state = mode == .continuous ? .listening : .idle; return }
        if slower { slowStep = min(SpeechPace.slowSteps.count - 1, slowStep + 1) } else { slowStep = 0 }
        let mult = SpeechPace.slowSteps[slowStep]
        let rate = SpeechPace(base: voice.pace).rate(multiplier: slower ? mult : (slowPace ? 0.75 : 1))
        let segs: [(Lang, String)] = last.segments.isEmpty ? [(last.lang, last.text)]
            : last.segments.compactMap { if case .say(let l, let t) = $0 { return (l, t) }; return nil }
        spokenParts = []
        interruptedAt = nil
        speakingTurn = turnID
        speakingMessageID = nil
        answerStarted = true
        segmenter.assistantStartedSpeaking()
        for (l, t) in segs {
            let parts = slower ? SlowChunks.split(t) : [t]
            for p in parts {
                let tag = nextTag
                nextTag += 1
                spokenParts.append((tag, p))
                sink.speak(p, lang: l, voiceID: voice.voiceIDs[l], rate: rate, pauseAfter: slower ? 0.6 : 0, tag: tag)
            }
        }
        state = .speaking
        Task { [weak self] in
            await self?.waitSpeechEnd()
            self?.metrics?.mark(turnID, "reply_end")
            self?.metrics?.flush(turnID)
            if let s = self, s.currentTurnID == turnID, s.state == .speaking { s.state = s.mode == .continuous ? .listening : .idle }
        }
    }

    /// Replay speech when the assistant's bubble is clicked (R-41).
    public func replay(_ m: ChatMessage) {
        interrupt(reason: "replay")
        let rate = SpeechPace(base: voice.pace).rate(multiplier: slowPace ? 0.75 : 1)
        for seg in m.segments {
            if case .say(let l, let t) = seg {
                let tag = nextTag
                nextTag += 1
                sink.speak(t, lang: l, voiceID: voice.voiceIDs[l], rate: rate, pauseAfter: 0, tag: tag)
            }
        }
    }
}
