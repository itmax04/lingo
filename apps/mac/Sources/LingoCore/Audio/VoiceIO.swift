@preconcurrency import AVFoundation
import Foundation

/// Voice-mode audio (ADR-0001 §7–8): one `AVAudioEngine` for both microphone and speech output.
/// - Input: voice processing (echo cancellation) → 16 kHz mono → `onSamples`. Audio is never written to disk (R-08).
/// - Output: `AVSpeechSynthesizer.write` → an `AVAudioPlayerNode` on the same engine, so echo cancellation "sees" the assistant's voice
///   and the playback position gives the exact barge-in point (R-12).
public final class VoiceIO: @unchecked Sendable {
    public typealias SamplesHandler = @Sendable ([Float]) -> Void

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private let synth = AVSpeechSynthesizer()
    private var converter = PCMConverter()
    private let lock = NSLock()
    private let synthQueue = DispatchQueue(label: "lingo.tts")
    /// Speech output format. With voice processing the player is connected in the device output format (with 24 kHz mono the engine
    /// failed to start: CoreAudio −10875, H-2 diagnostics); voice buffers are converted to it.
    var outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!
    private var hasOutput = false

    public var onSamples: SamplesHandler?
    /// Input format after start (diagnostics).
    public private(set) var inputFormatDescription = ""
    /// Raw peaks per input channel (diagnostics).
    public var onRawPeaks: (@Sendable ([Float]) -> Void)?
    /// First audio of a speech item (uptime in ns) — the `first_audio` metric (R-47).
    public var onPlaybackStarted: (@Sendable (_ tag: Int, _ uptimeNs: UInt64) -> Void)?
    /// A speech item has finished playing.
    public var onItemFinished: (@Sendable (_ tag: Int) -> Void)?
    /// The whole speech queue has finished playing.
    public var onIdle: (@Sendable () -> Void)?

    public private(set) var voiceProcessing = false
    public private(set) var running = false
    /// The microphone is temporarily muted (playing a hint phrase, R-27).
    public var micMuted: Bool {
        get { lock.withLock { _micMuted } }
        set { lock.withLock { _micMuted = newValue } }
    }
    private var _micMuted = false

    struct Item {
        var tag: Int
        var startSample: Int64
        var samples: Int64
        /// (offset in samples from the start of the item, character position in the item's text)
        var markers: [(Int64, Int)]
        var textLength: Int
        var started = false
    }
    private var items: [Item] = []
    private var scheduledTotal: Int64 = 0
    private var pendingBuffers = 0
    private var pendingSynth = 0
    private var generation = 0

    public init() {}

    // MARK: Start and stop

    /// Last start error for each attempt (H-2 diagnostics).
    public private(set) var startLog: [String] = []
    /// Parameters of the last start — used for restarts.
    private var wantVP = true
    private var wantOutput = true
    private var lastSampleAt: Double = 0
    private var configObserver: NSObjectProtocol?
    private var restartLimiter = AudioRestartLimiter()
    private var recoveryWork: DispatchWorkItem?
    private var shouldRun = false
    private var hasInputTap = false
    private var captureFailureReported = false
    private var lastConvertedAt: Double = 0
    private var startedAt: Double = 0
    private var lastVoiceProcessingFailureAt: Double?
    /// Capture has stopped; this also fires when no audio buffers arrive at all.
    public var onCaptureFailure: (@Sendable (String) -> Void)?
    /// Audio was restarted (configuration change or silence): the reason, and whether the restart succeeded.
    public var onRestart: (@Sendable (String, Bool) -> Void)?

    static func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e9 }

    /// Seconds since the last block of microphone samples (∞ if none yet).
    public var secondsSinceSamples: Double { lock.withLock { lastSampleAt == 0 ? .infinity : Self.now() - lastSampleAt } }

    public var isCapturing: Bool {
        running && engine.isRunning && lock.withLock {
            lastConvertedAt > 0 && Self.now() - lastConvertedAt < 1.5
        }
    }

    /// `voiceProcessing` — system echo cancellation. If starting with it fails (CoreAudio −10875 etc.),
    /// the engine is recreated and started without it; barge-in then relies on the VAD threshold (risk listed in plan.md).
    public func start(voiceProcessing wantVP: Bool = true, output: Bool = true) throws {
        guard !running else { return }
        self.wantVP = wantVP
        self.wantOutput = output
        shouldRun = true
        startLog = []
        var attempts: [Bool] = wantVP ? [true, false] : [false]
        var lastError: Error?
        while let vp = attempts.first {
            attempts.removeFirst()
            do {
                try startOnce(voiceProcessing: vp, output: output)
                startLog.append("vp=\(vp) output=\(output): OK")
                return
            } catch {
                lastError = error
                startLog.append("vp=\(vp) output=\(output): \((error as NSError).domain) \((error as NSError).code) \(error.localizedDescription)")
                Log.speech.error("voice io start failed vp=\(vp, privacy: .public): \(String(describing: error), privacy: .public)")
                resetEngine()
            }
        }
        throw lastError ?? VoiceIOError.noInput
    }

    private func resetEngine() {
        if let o = configObserver { NotificationCenter.default.removeObserver(o); configObserver = nil }
        recoveryWork?.cancel()
        recoveryWork = nil
        engine.stop()
        if hasInputTap { engine.inputNode.removeTap(onBus: 0); hasInputTap = false }
        if hasOutput { player.stop() }
        // Release the old voice-processing I/O unit before constructing another one.
        if voiceProcessing { try? engine.inputNode.setVoiceProcessingEnabled(false) }
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        converter = PCMConverter()
        hasOutput = false
        running = false
        voiceProcessing = false
        lock.withLock { lastSampleAt = 0; lastConvertedAt = 0 }
    }

    private func startOnce(voiceProcessing vp: Bool, output: Bool) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
        #endif
        let input = engine.inputNode
        if vp {
            try input.setVoiceProcessingEnabled(true)
            voiceProcessing = true
            if #available(macOS 14.0, iOS 17.0, *) {
                input.voiceProcessingOtherAudioDuckingConfiguration = .init(enableAdvancedDucking: false, duckingLevel: .min)
            }
        }
        if output || vp {
            // VP may expose 5 microphone channels. Use the speaker-side format for output,
            // queried after enabling VP, rather than applying the microphone layout to it.
            let ioFormat = engine.outputNode.inputFormat(forBus: 0)
            let mixer = engine.mainMixerNode
            guard ioFormat.sampleRate > 0, ioFormat.channelCount > 0 else { throw VoiceIOError.noInput }
            engine.connect(mixer, to: engine.outputNode, format: ioFormat)
            let rate = ioFormat.sampleRate
            if rate > 0 { outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)! }
            engine.attach(player)
            engine.connect(player, to: mixer, format: outFormat)
            hasOutput = true
        }
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else { throw VoiceIOError.noInput }
        inputFormatDescription = "\(fmt.sampleRate) Hz, \(fmt.channelCount) ch, \(fmt.commonFormat.rawValue), interleaved=\(fmt.isInterleaved)"
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buffer, _ in
            guard let self else { return }
            self.lock.withLock { self.lastSampleAt = Self.now() }
            guard !self.micMuted else { return }
            if let cb = self.onRawPeaks, let d = buffer.floatChannelData {
                var peaks: [Float] = []
                for c in 0..<Int(buffer.format.channelCount) {
                    var p: Float = 0
                    for i in 0..<Int(buffer.frameLength) { p = max(p, abs(d[c][i])) }
                    peaks.append(p)
                }
                cb(peaks)
            }
            let s = self.converter.convert(buffer)
            if !s.isEmpty {
                self.lock.withLock { self.lastConvertedAt = Self.now() }
                self.onSamples?(s)
            }
        }
        hasInputTap = true
        engine.prepare()
        try engine.start()
        if output { player.play() }
        running = true
        startedAt = Self.now()
        lock.withLock { lastSampleAt = Self.now() }
        // macOS stops the engine when the audio configuration changes (device, sample rate, voice processing) —
        // without a restart the microphone goes silent for good (live check 2026-10-26).
        if let o = configObserver { NotificationCenter.default.removeObserver(o) }
        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, self.shouldRun else { return }
            // Startup can post several notifications even while capture is healthy.
            self.recoveryWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.checkHealth() }
            self.recoveryWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
        Log.speech.notice("voice io started vp=\(self.voiceProcessing, privacy: .public) in=\(fmt.sampleRate, privacy: .public)Hz/\(fmt.channelCount, privacy: .public)ch")
    }

    /// Restarts audio with the same parameters (at most 5 times a minute). The speech queue is cleared.
    public func restart(reason: String, recoveringCapture: Bool = false) {
        let t = Self.now()
        guard shouldRun else { return }
        let allowed = lock.withLock { restartLimiter.allow(at: t) }
        guard allowed else { return }
        Log.speech.notice("voice io restart: \(reason, privacy: .public)")
        // VP can start successfully and then stop asynchronously; the start-error fallback
        // cannot catch that. Use unprocessed input after a repeated recovery failure.
        let repeatedVPFailure = recoveringCapture && voiceProcessing
            && lastVoiceProcessingFailureAt.map { t - $0 < 10 } == true
        if recoveringCapture && voiceProcessing { lastVoiceProcessingFailureAt = t }
        let vp = wantVP && !repeatedVPFailure
        let out = wantOutput
        if wantVP && !vp {
            Log.speech.notice("voice processing unstable; recovering without echo cancellation")
        }
        _ = stopSpeaking()
        micMuted = false
        resetEngine()
        do {
            try start(voiceProcessing: vp, output: out)
            onRestart?(reason, true)
        } catch {
            Log.speech.error("voice io restart failed: \(String(describing: error), privacy: .public)")
            onCaptureFailure?(String(localized: "Could not restart audio: \(error.localizedDescription)"))
            onRestart?(String(localized: "Could not restart audio: \(error.localizedDescription)"), false)
        }
    }

    /// Watchdog: if the microphone has been silent longer than `seconds` while the engine runs — restart.
    public func checkHealth(stallSeconds: Double = 1.5) {
        guard shouldRun else { return }
        let age = secondsSinceSamples
        let conversionStalled = !micMuted && lock.withLock {
            Self.now() - (lastConvertedAt > 0 ? lastConvertedAt : startedAt) > stallSeconds
        }
        if !running || !engine.isRunning || age > stallSeconds || conversionStalled {
            if !captureFailureReported {
                captureFailureReported = true
                onCaptureFailure?(String(localized: "Microphone capture stopped. Recovering audio; please repeat your phrase."))
            }
            let reason = !engine.isRunning ? "engine stopped" : (conversionStalled ? "audio conversion stalled" : "no microphone samples")
            restart(reason: reason, recoveringCapture: true)
        } else if isCapturing {
            captureFailureReported = false
        }
    }

    public func stop() {
        shouldRun = false
        _ = stopSpeaking()
        resetEngine()
        restartLimiter = AudioRestartLimiter()
        captureFailureReported = false
        lastVoiceProcessingFailureAt = nil
    }

    public enum VoiceIOError: Error { case noInput }

    // MARK: Speech output

    public var isSpeaking: Bool { lock.withLock { pendingBuffers > 0 || pendingSynth > 0 } }

    /// Queue a phrase for speech. `tag` — index of the reply part (for "interrupted" and metrics). `pauseAfter` — silence after it (R-15).
    public func speak(_ text: String, lang: Lang, voiceID: String?, rate: Float, pauseAfter: Double = 0, tag: Int) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let gen = lock.withLock { () -> Int in pendingSynth += 1; return generation }
        synthQueue.async { [weak self] in
            guard let self else { return }
            let u = AVSpeechUtterance(string: t)
            u.voice = Voices.voice(for: lang, preferred: voiceID)
            u.rate = rate
            let done = DispatchSemaphore(value: 0)
            var collected: [AVAudioPCMBuffer] = []
            var markers: [(Int64, Int)] = []
            var srcRate: Double = 0
            self.synth.write(u, toBufferCallback: { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 { done.signal(); return }
                srcRate = pcm.format.sampleRate
                collected.append(pcm)
            }, toMarkerCallback: { ms in
                for m in ms where m.mark == .word { markers.append((Int64(m.byteSampleOffset), m.textRange.location)) }
            })
            _ = done.wait(timeout: .now() + 20)
            self.enqueue(collected, srcRate: srcRate, markers: markers, textLength: (t as NSString).length,
                         pauseAfter: pauseAfter, tag: tag, generation: gen)
        }
    }

    private func enqueue(_ buffers: [AVAudioPCMBuffer], srcRate: Double, markers: [(Int64, Int)], textLength: Int,
                         pauseAfter: Double, tag: Int, generation gen: Int) {
        lock.lock()
        guard gen == generation else { lock.unlock(); return }
        pendingSynth = max(0, pendingSynth - 1)
        guard running else {
            let idle = pendingBuffers == 0 && pendingSynth == 0
            lock.unlock()
            if idle { onIdle?() }
            return
        }
        lock.unlock()
        var out: [AVAudioPCMBuffer] = []
        for b in buffers { if let c = convert(b) { out.append(c) } }
        if pauseAfter > 0, let silence = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: AVAudioFrameCount(pauseAfter * outFormat.sampleRate)) {
            silence.frameLength = silence.frameCapacity
            out.append(silence)
        }
        let total = out.reduce(Int64(0)) { $0 + Int64($1.frameLength) }
        let ratio = srcRate > 0 ? outFormat.sampleRate / srcRate : 1
        lock.lock()
        let wasIdle = pendingBuffers == 0
        // After the queue is paused, playback resumes from the player's current position.
        if wasIdle, let now = playerSample() { scheduledTotal = max(scheduledTotal, now) }
        let item = Item(tag: tag, startSample: scheduledTotal, samples: total,
                        markers: markers.map { (Int64(Double($0.0) * ratio), $0.1) }, textLength: textLength)
        items.append(item)
        scheduledTotal += total
        pendingBuffers += out.count
        lock.unlock()
        for (i, b) in out.enumerated() {
            let isFirst = i == 0, isLast = i == out.count - 1
            player.scheduleBuffer(b, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                self?.bufferPlayed(tag: tag, last: isLast, generation: gen)
            }
            if isFirst {
                let latency = engine.outputNode.presentationLatency
                let ns = DispatchTime.now().uptimeNanoseconds + UInt64(max(0, latency) * 1e9)
                if wasIdle { onPlaybackStarted?(tag, ns) }
                else { markStartedLater(tag) }
            }
        }
        if !player.isPlaying { player.play() }
    }

    private func markStartedLater(_ tag: Int) {
        // The item is queued behind others: its first audio is when the player reaches the item's start.
        let start = lock.withLock { items.first { $0.tag == tag }?.startSample } ?? 0
        let now = playerSample() ?? 0
        let delay = max(0, Double(start - now) / outFormat.sampleRate)
        let ns = DispatchTime.now().uptimeNanoseconds + UInt64(delay * 1e9)
        onPlaybackStarted?(tag, ns)
    }

    private func bufferPlayed(tag: Int, last: Bool, generation gen: Int) {
        lock.lock()
        guard gen == generation else { lock.unlock(); return }
        pendingBuffers = max(0, pendingBuffers - 1)
        let idle = pendingBuffers == 0 && pendingSynth == 0
        if last { items.removeAll { $0.tag == tag } }
        lock.unlock()
        if last { onItemFinished?(tag) }
        if idle { onIdle?() }
    }

    private func playerSample() -> Int64? {
        guard let nt = player.lastRenderTime, let pt = player.playerTime(forNodeTime: nt) else { return nil }
        return pt.sampleTime
    }

    /// Stop speech immediately (R-12). Returns the reply part where playback stopped and the character position in its text.
    @discardableResult
    public func stopSpeaking() -> (tag: Int, charOffset: Int)? {
        let pos = playerSample()
        lock.lock()
        generation += 1
        let current = pos.flatMap { p in items.first { p >= $0.startSample && p < $0.startSample + $0.samples } } ?? items.first
        var result: (Int, Int)?
        if let it = current {
            let rel = (pos ?? it.startSample) - it.startSample
            // Not all voices provide word markers (standard macOS 15 voices do not — P-04);
            // then the position is proportional to the played share of the part.
            let char = it.markers.isEmpty
                ? Int(Double(it.textLength) * Double(max(0, rel)) / Double(max(1, it.samples)))
                : (it.markers.last { $0.0 <= rel }?.1 ?? 0)
            result = (it.tag, min(it.textLength, char))
        }
        items.removeAll()
        pendingBuffers = 0
        pendingSynth = 0
        scheduledTotal = 0
        lock.unlock()
        synth.stopSpeaking(at: .immediate)
        if hasOutput {
            player.stop()
            if running && engine.isRunning { player.play() }
        }
        return result
    }

    private func convert(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if b.format == outFormat { return b }
        guard let conv = AVAudioConverter(from: b.format, to: outFormat) else { return nil }
        let cap = AVAudioFrameCount(Double(b.frameLength) * outFormat.sampleRate / b.format.sampleRate + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: cap) else { return nil }
        final class Once: @unchecked Sendable { var used = false }
        let once = Once()
        var err: NSError?
        _ = conv.convert(to: out, error: &err) { _, st in
            if once.used { st.pointee = .endOfStream; return nil }
            once.used = true
            st.pointee = .haveData
            return b
        }
        return err == nil ? out : nil
    }

    /// Voice warm-up: the first synthesis with a voice takes ≈ 1 s (loading), later ones take tens of ms (P-04, tts-bench).
    /// Called when a session starts so that "repeat" sounds within 0.3 s (R-14).
    public func warmUp(lang: Lang, voiceID: String?) {
        synthQueue.async { [weak self] in
            guard let self else { return }
            let u = AVSpeechUtterance(string: lang == .ru ? "Да." : (lang == .de ? "Ja." : "Yes."))
            u.voice = Voices.voice(for: lang, preferred: voiceID)
            let done = DispatchSemaphore(value: 0)
            self.synth.write(u) { b in if (b as? AVAudioPCMBuffer)?.frameLength == 0 { done.signal() } }
            _ = done.wait(timeout: .now() + 10)
        }
    }

    /// Play a hint phrase (R-27): the microphone does not listen meanwhile.
    public func playPhrase(_ text: String, lang: Lang, voiceID: String?, rate: Float, tag: Int) {
        micMuted = true
        speak(text, lang: lang, voiceID: voiceID, rate: rate, tag: tag)
    }
}
