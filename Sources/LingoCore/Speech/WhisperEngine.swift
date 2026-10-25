// Перенесено из Interview Copilot (`Sources/CopilotCore/STT/WhisperEngine.swift`, коммит cf0e764) с адаптацией:
// языки-кандидаты задаются на реплику ({изучаемый, ru}, R-08), спорный язык — двойной прогон и выбор по уверенности токенов.
import Foundation
import whisper

public enum WhisperError: Error, CustomStringConvertible {
    case modelNotFound(String)
    case loadFailed(String)
    case inferenceFailed(Int32)
    case cancelled

    public var description: String {
        switch self {
        case .modelNotFound(let path): "Модель не найдена: \(path)"
        case .loadFailed(let path): "Не удалось загрузить модель: \(path)"
        case .inferenceFailed(let code): "whisper_full вернул \(code)"
        case .cancelled: "Распознавание отменено"
        }
    }
}

/// Обёртка C API whisper.cpp. Один экземпляр — один контекст; вызовы сериализуются.
public final class WhisperEngine: SpeechRecognizer, @unchecked Sendable {
    public let id: String
    /// Ниже этого уровня (dBFS по всему фрагменту) речи нет: на тишине whisper выдумывает текст (опыт IC).
    public static let silenceDB: Float = -60
    /// Если вероятность лучшего языка ниже, распознаём на обоих кандидатах и берём более уверенный вариант.
    public var ambiguousBelow: Float = 0.85
    /// Урезанный контекст энкодера: быстрее; меньше 512 кадров портит large-v3-turbo (D-13).
    public var reducedContext = false

    /// Как выбирается язык реплики среди кандидатов (R-08).
    public enum LanguageStrategy: String, Sendable, CaseIterable {
        /// Автоопределение whisper на полном контексте (≈ 2 с на M1).
        case detect
        /// Распознать на каждом кандидате и взять вариант с большей средней вероятностью токенов.
        case dual
        /// Автоопределение отдельной лёгкой моделью (`detector`), распознавание — основной.
        case smallDetect
    }
    public var strategy: LanguageStrategy = .detect
    /// Лёгкая модель для `.smallDetect`.
    public var detector: WhisperEngine?
    /// Распознавание смешанной речи по кускам (D-14).
    public var chunkedMixed = false
    /// Двуязычная затравка (`initial_prompt`) для смешанной речи (D-14): изучаемый язык + русский.
    /// Текст не пересекается с фразами evals/audio (иначе замер был бы завышен).
    public var mixedPrompt = true

    static func prompt(for candidates: [Lang]) -> String? {
        guard candidates.contains(.ru) else { return nil }
        if candidates.contains(.de) { return "Heute kaufe ich, ну, как это по-немецки, Gemüse. Ну вот. Das ist mein Freund." }
        if candidates.contains(.en) { return "Today I buy, ну, как это по-английски, vegetables. Ну вот. This is my friend." }
        return nil
    }

    /// Минимум кадров урезанного контекста (1500 = 30 с). Малые значения портят large-v3-turbo (D-13).
    public var minAudioContext = 64

    func audioContext(_ n: Int) -> Int32 {
        let frames = Int((Double(n) / 16_000 * 50).rounded(.up)) + 64
        return Int32(min(1500, max(minAudioContext, (frames + 63) / 64 * 64)))
    }

    public let modelPath: String
    private let ctx: OpaquePointer
    private let detectState: OpaquePointer
    private let lock = NSLock()
    private let abortFlag = AbortFlag()
    public let threads: Int32

    final class AbortFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set(_ v: Bool) { lock.withLock { value = v } }
    }

    public init(modelPath: String, useGPU: Bool = true, threads: Int32 = 4) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else { throw WhisperError.modelNotFound(modelPath) }
        Self.silenceNativeLogs()
        var cparams = whisper_context_default_params()
        cparams.use_gpu = useGPU
        cparams.flash_attn = useGPU
        guard let ctx = whisper_init_from_file_with_params(modelPath, cparams) else { throw WhisperError.loadFailed(modelPath) }
        guard let detectState = whisper_init_state(ctx) else {
            whisper_free(ctx)
            throw WhisperError.loadFailed(modelPath)
        }
        self.ctx = ctx
        self.detectState = detectState
        self.modelPath = modelPath
        self.threads = threads
        self.id = "whisper:" + ((modelPath as NSString).lastPathComponent as String)
        Log.speech.notice("whisper model loaded: \((modelPath as NSString).lastPathComponent, privacy: .public) gpu=\(useGPU)")
    }

    deinit {
        whisper_free_state(detectState)
        whisper_free(ctx)
    }

    /// Логи whisper.cpp/ggml не пишутся в stderr приложения (и не должны содержать текст речи, R-49).
    private static let silenced: Void = { whisper_log_set({ _, _, _ in }, nil) }()
    static func silenceNativeLogs() { _ = silenced }

    public func cancel() { abortFlag.set(true) }

    /// Тихий звук поднимается до пика 0,5, но не больше чем в 40 раз.
    static func normalized(_ samples: [Float]) -> [Float] {
        var peak: Float = 0
        for s in samples { peak = max(peak, abs(s)) }
        guard peak > 0, peak < 0.25 else { return samples }
        let gain = min(0.5 / peak, 40)
        return samples.map { $0 * gain }
    }

    public func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription {
        try transcribeSync(samples, candidates: candidates, forced: forced, context: context)
    }

    public func transcribeSync(_ input: [Float], candidates: [Lang], forced: Lang?, context: String? = nil) throws -> Transcription {
        lock.lock()
        defer { lock.unlock() }
        abortFlag.set(false)
        let started = DispatchTime.now()
        var samples = Self.normalized(input)
        let minSamples = 16_000 + 1_600
        if samples.count < minSamples { samples += [Float](repeating: 0, count: minSamples - samples.count) }
        let audioSeconds = Double(input.count) / 16_000
        let cands = candidates.isEmpty ? [Lang.en] : candidates
        if EnergyVAD.rmsDB(input[...]) < Self.silenceDB {
            return Transcription(text: "", lang: forced ?? cands[0], audioSeconds: audioSeconds, elapsedMs: 0, noSpeechProbability: 1)
        }
        var scores: [Lang: Float] = [:]
        var order: [Lang]
        var detectMs = 0.0
        if let f = forced {
            order = [f]
        } else {
            let d0 = DispatchTime.now()
            switch strategy {
            case .dual:
                order = cands
            case .detect, .smallDetect:
                if strategy == .smallDetect, let d = detector {
                    scores = try d.detectLanguage(samples, candidates: cands)
                } else {
                    scores = try detectLocked(samples, candidates: cands)
                }
                order = cands.sorted { (scores[$0] ?? 0) > (scores[$1] ?? 0) }
                if let best = order.first, (scores[best] ?? 0) >= ambiguousBelow { order = [best] }
            }
            detectMs = Double(DispatchTime.now().uptimeNanoseconds - d0.uptimeNanoseconds) / 1e6
        }
        // Затравка: двуязычный образец (D-14) + контекст разговора (R-51): контекст в конце — ближе к распознаваемой фразе.
        let base = mixedPrompt ? Self.prompt(for: Array(Set(cands + (forced.map { [$0] } ?? [])))) : nil
        currentPrompt = [base, context].compactMap { $0 }.joined(separator: " ").nilIfEmpty
        defer { currentPrompt = nil }
        var bestRun: Run?
        var runs: [Double] = []
        var runProbs: [Lang: Float] = [:]
        for lang in order {
            let r0 = DispatchTime.now()
            let r = try runLocked(samples, lang: lang, audioSeconds: audioSeconds)
            runs.append(Double(DispatchTime.now().uptimeNanoseconds - r0.uptimeNanoseconds) / 1e6)
            runProbs[lang] = r.avgTokenP
            if bestRun == nil || r.avgTokenP > bestRun!.avgTokenP { bestRun = r }
        }
        if strategy == .dual && forced == nil { scores = runProbs }
        // Метка языка (R-08) — по алфавиту итогового текста: кириллица → ru, латиница → изучаемый.
        // Уверенность токенов выбирает лучший текст, но смещена двуязычной затравкой (D-14).
        if forced == nil, var b = bestRun, let l = Self.scriptLang(b.text, candidates: cands) { b.lang = l; bestRun = b }
        var r = bestRun!
        // Смешанная речь (D-14): по кнопке «Говорю по-русски» и при подозрительно коротком тексте — распознавание по кускам.
        if chunkedMixed, cands.count > 1 || forced != nil {
            let mixedCands = forced.map { f in Array(Set(cands + [f])).sorted { $0 == f && $1 != f } } ?? cands
            let speech = Double(input.count) / 16_000
            if forced != nil || Self.lowCoverage(r.text, speechSeconds: speech) {
                let c0 = DispatchTime.now()
                if let (cr, cs) = try chunkedLocked(samples, candidates: mixedCands.count > 1 ? mixedCands : [forced!, cands[0]], audioSeconds: audioSeconds),
                   forced != nil || cr.text.split(separator: " ").count > r.text.split(separator: " ").count {
                    r = cr
                    scores = cs
                }
                runs.append(Double(DispatchTime.now().uptimeNanoseconds - c0.uptimeNanoseconds) / 1e6)
            }
        }
        lastTimings = (detectMs, runs)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1e6
        return Transcription(text: r.text, lang: r.lang, scores: scores, audioSeconds: audioSeconds, elapsedMs: elapsed,
                             noSpeechProbability: r.noSpeech)
    }

    struct Run { var text: String; var lang: Lang; var noSpeech: Float; var avgTokenP: Float }

    /// Разбивка времени последнего вызова (evals): определение языка, прогоны распознавания.
    public private(set) var lastTimings: (detectMs: Double, runs: [Double]) = (0, [])

    private var currentPrompt: String?

    private func runLocked(_ samples: [Float], lang: Lang, audioSeconds: Double) throws -> Run {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = threads
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.single_segment = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_nst = true
        params.temperature = 0
        params.temperature_inc = 0
        // Полный контекст энкодера: урезанный `audio_ctx` на large-v3-turbo давал мусор и зацикливание (eval `audio`, P-04, D-13).
        params.audio_ctx = reducedContext ? audioContext(samples.count) : 0
        // Ограничение длины ответа против зацикливания: с запасом, чтобы не обрезать быструю речь.
        params.max_tokens = Int32(min(440, Int(audioSeconds * 16) + 48))
        let flag = Unmanaged.passUnretained(abortFlag).toOpaque()
        params.abort_callback = { userData in
            guard let userData else { return false }
            return Unmanaged<AbortFlag>.fromOpaque(userData).takeUnretainedValue().isSet
        }
        params.abort_callback_user_data = flag
        let code: Int32 = lang.rawValue.withCString { langPtr in
            params.language = langPtr
            if let p = currentPrompt {
                return p.withCString { pp in
                    params.initial_prompt = pp
                    return samples.withUnsafeBufferPointer { whisper_full(ctx, params, $0.baseAddress, Int32($0.count)) }
                }
            }
            return samples.withUnsafeBufferPointer { whisper_full(ctx, params, $0.baseAddress, Int32($0.count)) }
        }
        if abortFlag.isSet { throw WhisperError.cancelled }
        guard code == 0 else { throw WhisperError.inferenceFailed(code) }
        var text = ""
        var noSpeech: Float = 0
        var pSum: Float = 0
        var pCount = 0
        let eot = whisper_token_eot(ctx)
        for i in 0..<whisper_full_n_segments(ctx) {
            if let cstr = whisper_full_get_segment_text(ctx, i) { text += String(cString: cstr) }
            noSpeech = max(noSpeech, whisper_full_get_segment_no_speech_prob(ctx, i))
            for j in 0..<whisper_full_n_tokens(ctx, i) {
                guard whisper_full_get_token_id(ctx, i, j) < eot else { continue }
                pSum += whisper_full_get_token_p(ctx, i, j)
                pCount += 1
            }
        }
        return Run(text: Self.clean(text), lang: lang, noSpeech: noSpeech, avgTokenP: pCount > 0 ? pSum / Float(pCount) : 0)
    }

    // MARK: Смешанная речь по кускам (D-14)

    /// Куски речи между паузами ≥ `gap` с: границы по EnergyVAD, короткие куски склеиваются с соседями.
    public static func speechChunks(_ s: [Float], gap: Double = 0.25, minChunk: Double = 0.8) -> [Range<Int>] {
        var cfg = VoiceDefaults.vad
        cfg.hangoverMs = Int(gap * 1000)
        var vad = EnergyVAD(config: cfg)
        var regions: [Range<Int>] = []
        var start: Int?
        var pos = 0
        let block = 320
        while pos < s.count {
            let end = min(s.count, pos + block)
            for e in vad.processEvents(Array(s[pos..<end])) {
                let at = pos + e.sampleOffset
                if e.isSpeech { start = max(0, at - cfg.attackFrames * vad.frameSize - 1600) }
                else if let st = start { regions.append(st..<min(s.count, at)); start = nil }
            }
            pos = end
        }
        if let st = start { regions.append(st..<s.count) }
        // Склейка коротких кусков с соседними.
        let minLen = Int(minChunk * 16_000)
        var out: [Range<Int>] = []
        for r in regions {
            if let last = out.last, (r.count < minLen || last.count < minLen) {
                out[out.count - 1] = last.lowerBound..<r.upperBound
            } else {
                out.append(r)
            }
        }
        return out
    }

    /// Распознавание по кускам с выбором языка каждого куска (двойной прогон по кандидатам).
    func chunkedLocked(_ samples: [Float], candidates: [Lang], audioSeconds: Double) throws -> (Run, [Lang: Float])? {
        let chunks = Self.speechChunks(samples)
        guard chunks.count > 1 else { return nil }
        var texts: [String] = []
        var langCount: [Lang: Int] = [:]
        var pSum: Float = 0
        for c in chunks {
            var part = Array(samples[c])
            if part.count < 17_600 { part += [Float](repeating: 0, count: 17_600 - part.count) }
            var best: Run?
            for l in candidates {
                let r = try runLocked(part, lang: l, audioSeconds: Double(c.count) / 16_000)
                if best == nil || r.avgTokenP > best!.avgTokenP { best = r }
            }
            if let b = best, !b.text.isEmpty {
                texts.append(b.text)
                langCount[b.lang, default: 0] += 1
                pSum += b.avgTokenP
            }
        }
        guard !texts.isEmpty else { return nil }
        let main = langCount.max { $0.value < $1.value }?.key ?? candidates[0]
        var scores: [Lang: Float] = [:]
        for (l, n) in langCount { scores[l] = Float(n) / Float(texts.count) }
        return (Run(text: texts.joined(separator: " "), lang: main, noSpeech: 0, avgTokenP: pSum / Float(texts.count)), scores)
    }

    /// Язык по алфавиту: доля кириллицы среди букв > 50% → ru; иначе — первый не-русский кандидат.
    public static func scriptLang(_ text: String, candidates: [Lang]) -> Lang? {
        var cyr = 0, lat = 0
        for u in text.unicodeScalars where CharacterSet.letters.contains(u) {
            if (0x0400...0x04FF).contains(u.value) { cyr += 1 } else { lat += 1 }
        }
        guard cyr + lat > 0 else { return nil }
        if Double(cyr) / Double(cyr + lat) > 0.5 { return candidates.contains(.ru) ? .ru : nil }
        return candidates.first { $0 != .ru }
    }

    /// Текст подозрительно короток для длины речи — вероятно, часть на другом языке выпала.
    static func lowCoverage(_ text: String, speechSeconds: Double) -> Bool {
        let words = text.split(whereSeparator: { $0 == " " }).count
        return speechSeconds >= 2.5 && Double(words) < speechSeconds * 1.2
    }

    /// Только определение языка (для `.smallDetect` у основной модели).
    public func detectLanguage(_ input: [Float], candidates: [Lang]) throws -> [Lang: Float] {
        lock.lock()
        defer { lock.unlock() }
        var samples = Self.normalized(input)
        if samples.count < 17_600 { samples += [Float](repeating: 0, count: 17_600 - samples.count) }
        return try detectLocked(samples, candidates: candidates)
    }

    /// Автоопределение языка среди кандидатов (вероятности нормируются на сумму кандидатов).
    private func detectLocked(_ samples: [Float], candidates: [Lang]) throws -> [Lang: Float] {
        let rc = samples.withUnsafeBufferPointer {
            whisper_pcm_to_mel_with_state(ctx, detectState, $0.baseAddress, Int32($0.count), threads)
        }
        guard rc == 0 else { throw WhisperError.inferenceFailed(rc) }
        var probs = [Float](repeating: 0, count: Int(whisper_lang_max_id()) + 1)
        let top = whisper_lang_auto_detect_with_state(ctx, detectState, 0, threads, &probs)
        guard top >= 0 else { throw WhisperError.inferenceFailed(top) }
        var result: [Lang: Float] = [:]
        for l in candidates {
            let id = whisper_lang_id(l.rawValue)
            if id >= 0 { result[l] = probs[Int(id)] }
        }
        let sum = result.values.reduce(0, +)
        if sum > 0 { for k in result.keys { result[k]! /= sum } }
        return result
    }

    /// Убирает служебные вставки вроде «[музыка]», «(applause)» и зацикленные повторы фраз.
    static func clean(_ text: String) -> String {
        var t = text.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = collapseRepeats(t.trimmingCharacters(in: .whitespacesAndNewlines))
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Фраза из 1–8 слов, повторённая 3+ раза подряд, оставляется один раз (галлюцинации; двойной повтор пользователя — P16 — сохраняется).
    static func collapseRepeats(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        guard words.count >= 6 else { return text }
        func norm(_ w: String) -> String { w.lowercased().trimmingCharacters(in: .punctuationCharacters) }
        var n = 1
        while n <= 8 {
            var i = 0
            var changed = false
            while i + n * 3 <= words.count {
                let unit = words[i..<(i + n)].map(norm)
                var reps = 1
                while i + n * (reps + 1) <= words.count,
                      words[(i + n * reps)..<(i + n * (reps + 1))].map(norm) == unit { reps += 1 }
                if reps >= 3 {
                    words.removeSubrange((i + n)..<(i + n * reps))
                    changed = true
                }
                i += 1
            }
            if !changed { n += 1 }
        }
        return words.joined(separator: " ")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
