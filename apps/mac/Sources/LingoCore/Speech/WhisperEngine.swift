// Ported from Interview Copilot (`Sources/CopilotCore/STT/WhisperEngine.swift`, commit cf0e764) and adapted:
// candidate languages are set per utterance ({target, ru}, R-08); an uncertain language gets a double pass chosen by token confidence.
import Foundation
import whisper

public enum WhisperError: Error, CustomStringConvertible {
    case modelNotFound(String)
    case loadFailed(String)
    case inferenceFailed(Int32)
    case cancelled

    public var description: String {
        switch self {
        case .modelNotFound(let path): String(localized: "Model not found: \(path)")
        case .loadFailed(let path): String(localized: "Could not load the model: \(path)")
        case .inferenceFailed(let code): "whisper_full returned \(code)"
        case .cancelled: String(localized: "Speech recognition cancelled")
        }
    }
}

/// A wrapper over the whisper.cpp C API. One instance — one context; calls are serialized.
public final class WhisperEngine: SpeechRecognizer, @unchecked Sendable {
    public let id: String
    /// Below this level (dBFS over the whole fragment) there is no speech: on silence whisper invents text (IC experience).
    public static let silenceDB: Float = -60
    /// If the probability of the best language is lower, recognize with both candidates and take the more confident result.
    public var ambiguousBelow: Float = 0.85
    /// Reduced encoder context: faster; fewer than 512 frames breaks large-v3-turbo (D-13).
    public var reducedContext = false

    /// How the utterance language is chosen among the candidates (R-08).
    public enum LanguageStrategy: String, Sendable, CaseIterable {
        /// whisper auto-detection on the full context (≈ 2 s on M1).
        case detect
        /// Recognize with each candidate and take the result with the higher mean token probability.
        case dual
        /// Auto-detection with a separate light model (`detector`), recognition with the main one.
        case smallDetect
    }
    public var strategy: LanguageStrategy = .detect
    /// Light model for `.smallDetect`.
    public var detector: WhisperEngine?
    /// Chunked recognition of mixed speech (D-14).
    public var chunkedMixed = false
    /// Bilingual prompt (`initial_prompt`) for mixed speech (D-14): the target language + Russian.
    /// The text does not overlap the evals/audio phrases (otherwise the measurement would be inflated).
    public var mixedPrompt = true

    static func prompt(for candidates: [Lang]) -> String? {
        guard candidates.contains(.ru) else { return nil }
        if candidates.contains(.de) { return "Heute kaufe ich, ну, как это по-немецки, Gemüse. Ну вот. Das ist mein Freund." }
        if candidates.contains(.en) { return "Today I buy, ну, как это по-английски, vegetables. Ну вот. This is my friend." }
        return nil
    }

    /// Minimum frames of the reduced context (1500 = 30 s). Small values break large-v3-turbo (D-13).
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

    /// whisper.cpp/ggml logs are not written to the app's stderr (and must not contain speech text, R-49).
    private static let silenced: Void = { whisper_log_set({ _, _, _ in }, nil) }()
    static func silenceNativeLogs() { _ = silenced }

    public func cancel() { abortFlag.set(true) }

    /// Quiet audio is boosted to a peak of 0.5, but by no more than 40×.
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
        // Prompt: a bilingual sample (D-14) + the conversation context (R-51): context at the end — closer to the phrase being recognized.
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
        // Language label (R-08) — by the alphabet of the final text: Cyrillic → ru, Latin → the target language.
        // Token confidence picks the best text but is biased by the bilingual prompt (D-14).
        if forced == nil, var b = bestRun, let l = Self.scriptLang(b.text, candidates: cands) { b.lang = l; bestRun = b }
        var r = bestRun!
        // Mixed speech (D-14): with the "I'm speaking Russian" button and for suspiciously short text — chunked recognition.
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

    /// Timing breakdown of the last call (evals): language detection, recognition passes.
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
        // Full encoder context: a reduced `audio_ctx` on large-v3-turbo produced garbage and loops (eval `audio`, P-04, D-13).
        params.audio_ctx = reducedContext ? audioContext(samples.count) : 0
        // Reply length limit against loops: with headroom so fast speech is not cut off.
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

    // MARK: Chunked mixed speech (D-14)

    /// Speech chunks between pauses ≥ `gap` s: boundaries from EnergyVAD, short chunks are merged with neighbours.
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
        // Merge short chunks with their neighbours.
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

    /// Chunked recognition choosing the language of each chunk (a double pass over the candidates).
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

    /// Language by alphabet: Cyrillic share among letters > 50% → ru; otherwise the first non-Russian candidate.
    public static func scriptLang(_ text: String, candidates: [Lang]) -> Lang? {
        var cyr = 0, lat = 0
        for u in text.unicodeScalars where CharacterSet.letters.contains(u) {
            if (0x0400...0x04FF).contains(u.value) { cyr += 1 } else { lat += 1 }
        }
        guard cyr + lat > 0 else { return nil }
        if Double(cyr) / Double(cyr + lat) > 0.5 { return candidates.contains(.ru) ? .ru : nil }
        return candidates.first { $0 != .ru }
    }

    /// The text is suspiciously short for the speech length — probably a part in the other language was lost.
    static func lowCoverage(_ text: String, speechSeconds: Double) -> Bool {
        let words = text.split(whereSeparator: { $0 == " " }).count
        return speechSeconds >= 2.5 && Double(words) < speechSeconds * 1.2
    }

    /// Language detection only (for `.smallDetect` with the main model).
    public func detectLanguage(_ input: [Float], candidates: [Lang]) throws -> [Lang: Float] {
        lock.lock()
        defer { lock.unlock() }
        var samples = Self.normalized(input)
        if samples.count < 17_600 { samples += [Float](repeating: 0, count: 17_600 - samples.count) }
        return try detectLocked(samples, candidates: candidates)
    }

    /// Language auto-detection among the candidates (probabilities normalized to the candidates' sum).
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

    /// Removes service insertions like "[музыка]", "(applause)" and looping phrase repeats.
    static func clean(_ text: String) -> String {
        var t = text.replacingOccurrences(of: #"\[[^\]]*\]|\([^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = collapseRepeats(t.trimmingCharacters(in: .whitespacesAndNewlines))
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A 1–8 word phrase repeated 3+ times in a row is kept once (hallucinations; a user's double repeat — P16 — is kept).
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
