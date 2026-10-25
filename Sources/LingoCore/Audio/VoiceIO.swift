@preconcurrency import AVFoundation
import Foundation

/// Звук голосового режима (ADR-0001 п. 7–8): один `AVAudioEngine` для микрофона и озвучки.
/// - Вход: voice processing (эхоподавление) → 16 кГц моно → `onSamples`. Аудио на диск не пишется (R-08).
/// - Выход: озвучка `AVSpeechSynthesizer.write` → `AVAudioPlayerNode` того же движка: эхоподавление «видит» голос помощника,
///   а позиция воспроизведения даёт точное место перебивания (R-12).
public final class VoiceIO: @unchecked Sendable {
    public typealias SamplesHandler = @Sendable ([Float]) -> Void

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private let synth = AVSpeechSynthesizer()
    private let converter = PCMConverter()
    private let lock = NSLock()
    private let synthQueue = DispatchQueue(label: "lingo.tts")
    /// Формат озвучки. С voice processing плеер подключается в формате выхода устройства (с 24 кГц моно движок
    /// не запускался: CoreAudio −10875, диагностика H-2); буферы голосов приводятся к нему.
    var outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 24_000, channels: 1, interleaved: false)!
    private var hasOutput = false

    public var onSamples: SamplesHandler?
    /// Формат входа после запуска (диагностика).
    public private(set) var inputFormatDescription = ""
    /// Сырые пики по каналам входа (диагностика).
    public var onRawPeaks: (@Sendable ([Float]) -> Void)?
    /// Первый звук элемента озвучки (момент uptime в нс) — метрика `first_audio` (R-47).
    public var onPlaybackStarted: (@Sendable (_ tag: Int, _ uptimeNs: UInt64) -> Void)?
    /// Элемент озвучки доигран до конца.
    public var onItemFinished: (@Sendable (_ tag: Int) -> Void)?
    /// Вся очередь озвучки доиграна.
    public var onIdle: (@Sendable () -> Void)?

    public private(set) var voiceProcessing = false
    public private(set) var running = false
    /// Микрофон временно не слушает (прослушивание подсказки, R-27).
    public var micMuted: Bool {
        get { lock.withLock { _micMuted } }
        set { lock.withLock { _micMuted = newValue } }
    }
    private var _micMuted = false

    struct Item {
        var tag: Int
        var startSample: Int64
        var samples: Int64
        /// (смещение в сэмплах от начала элемента, позиция символа в тексте элемента)
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

    // MARK: Старт и стоп

    /// Последняя ошибка запуска по каждой попытке (диагностика H-2).
    public private(set) var startLog: [String] = []

    /// `voiceProcessing` — эхоподавление системы. Если запуск с ним не удался (CoreAudio −10875 и т. п.),
    /// движок пересоздаётся и запускается без эхоподавления; перебивание тогда опирается на порог VAD (риск в plan.md).
    public func start(voiceProcessing wantVP: Bool = true, output: Bool = true) throws {
        guard !running else { return }
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
        hasOutput = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        voiceProcessing = false
    }

    private func startOnce(voiceProcessing vp: Bool, output: Bool) throws {
        let input = engine.inputNode
        if vp {
            try input.setVoiceProcessingEnabled(true)
            voiceProcessing = true
            if #available(macOS 14.0, iOS 17.0, *) {
                input.voiceProcessingOtherAudioDuckingConfiguration = .init(enableAdvancedDucking: false, duckingLevel: .min)
            }
        }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
        #endif
        if output || vp {
            // Схема Apple для voice processing: выход движка должен работать (иначе вход не отдаёт сэмплы),
            // микшер → выход соединяется в формате голосового входа.
            let ioFormat = input.outputFormat(forBus: 0)
            let mixer = engine.mainMixerNode
            if vp, ioFormat.sampleRate > 0 { engine.connect(mixer, to: engine.outputNode, format: ioFormat) }
            let rate = vp && ioFormat.sampleRate > 0 ? ioFormat.sampleRate : engine.outputNode.outputFormat(forBus: 0).sampleRate
            if rate > 0 { outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)! }
            engine.attach(player)
            engine.connect(player, to: mixer, format: outFormat)
            hasOutput = true
        }
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else { throw VoiceIOError.noInput }
        inputFormatDescription = "\(fmt.sampleRate) Hz, \(fmt.channelCount) ch, \(fmt.commonFormat.rawValue), interleaved=\(fmt.isInterleaved)"
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buffer, _ in
            guard let self, !self.micMuted else { return }
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
            if !s.isEmpty { self.onSamples?(s) }
        }
        engine.prepare()
        try engine.start()
        if output { player.play() }
        running = true
        Log.speech.notice("voice io started vp=\(self.voiceProcessing, privacy: .public) in=\(fmt.sampleRate, privacy: .public)Hz/\(fmt.channelCount, privacy: .public)ch")
    }

    public func stop() {
        guard running else { return }
        if hasOutput { _ = stopSpeaking() }
        engine.inputNode.removeTap(onBus: 0)
        if hasOutput { player.stop() }
        engine.stop()
        running = false
    }

    public enum VoiceIOError: Error { case noInput }

    // MARK: Озвучка

    public var isSpeaking: Bool { lock.withLock { pendingBuffers > 0 || pendingSynth > 0 } }

    /// Поставить фразу в очередь озвучки. `tag` — номер части ответа (для «прервано» и метрик). `pauseAfter` — тишина после (R-15).
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
        pendingSynth -= 1
        guard gen == generation, running else {
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
        // После паузы очереди воспроизведение продолжается с текущей позиции плеера.
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
        // Элемент встал в очередь за другими: его первый звук — когда плеер дойдёт до начала элемента.
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

    /// Немедленно остановить озвучку (R-12). Возвращает часть ответа, на которой остановились, и позицию символа в её тексте.
    @discardableResult
    public func stopSpeaking() -> (tag: Int, charOffset: Int)? {
        let pos = playerSample()
        lock.lock()
        generation += 1
        let current = pos.flatMap { p in items.first { p >= $0.startSample && p < $0.startSample + $0.samples } } ?? items.first
        var result: (Int, Int)?
        if let it = current {
            let rel = (pos ?? it.startSample) - it.startSample
            // Маркеры слов есть не у всех голосов (у стандартных голосов macOS 15 их нет — P-04);
            // тогда позиция — пропорционально проигранной доле части.
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
            if running { player.play() }
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

    /// Прогрев голоса: первый синтез голосом занимает ≈ 1 с (загрузка), следующие — десятки мс (P-04, tts-bench).
    /// Вызывается при старте сессии, чтобы «повтори» звучало не позже 0,3 с (R-14).
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

    /// Прослушать фразу подсказки (R-27): микрофон на это время не слушает.
    public func playPhrase(_ text: String, lang: Lang, voiceID: String?, rate: Float, tag: Int) {
        micMuted = true
        speak(text, lang: lang, voiceID: voiceID, rate: rate, tag: tag)
    }
}
