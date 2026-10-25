import Foundation

/// Результат распознавания одной реплики (R-08).
public struct Transcription: Sendable, Equatable {
    public var text: String
    public var lang: Lang
    /// Вероятности (whisper) или уверенность (Apple) по языкам-кандидатам.
    public var scores: [Lang: Float]
    public var audioSeconds: Double
    public var elapsedMs: Double
    public var noSpeechProbability: Float

    public init(text: String, lang: Lang, scores: [Lang: Float] = [:], audioSeconds: Double, elapsedMs: Double, noSpeechProbability: Float = 0) {
        self.text = text
        self.lang = lang
        self.scores = scores
        self.audioSeconds = audioSeconds
        self.elapsedMs = elapsedMs
        self.noSpeechProbability = noSpeechProbability
    }
}

/// Движок распознавания (ADR-0001 п. 6). Язык реплики выбирается среди кандидатов {изучаемый, ru} (R-08);
/// `forced` — кнопка «Говорю по-русски» (R-09). Аудио — 16 кГц моно в памяти, на диск не пишется.
public protocol SpeechRecognizer: Sendable {
    var id: String { get }
    /// `context` — подсказка из разговора (R-51): последняя реплика помощника, тема, фразы подсказок.
    func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription
}

public extension SpeechRecognizer {
    func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?) async throws -> Transcription {
        try await transcribe(samples, candidates: candidates, forced: forced, context: nil)
    }
}

/// Подсказка распознаванию из контекста разговора (R-51). whisper учитывает до ~224 токенов затравки,
/// поэтому берутся последние предложения реплики помощника, тема и несколько фраз подсказок.
public enum RecognitionContext {
    public static func make(lastAssistant: String?, topic: String, phrases: [String], maxChars: Int = 360) -> String? {
        var parts: [String] = []
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { parts.append(t + ".") }
        for p in phrases.prefix(4) where !p.isEmpty { parts.append(p) }
        if let a = lastAssistant?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
            parts.append(String(a.suffix(200)))
        }
        guard !parts.isEmpty else { return nil }
        let joined = parts.joined(separator: " ")
        return String(joined.suffix(maxChars))
    }
}

/// Буфер реплики в памяти: не больше 60 с (R-08). Старые сэмплы отбрасываются.
public struct UtteranceBuffer: Sendable {
    public static let maxSeconds = 60.0
    public private(set) var samples: [Float] = []
    public let sampleRate: Double

    public init(sampleRate: Double = 16_000) { self.sampleRate = sampleRate }

    public mutating func append(_ s: [Float]) {
        samples.append(contentsOf: s)
        let cap = Int(Self.maxSeconds * sampleRate)
        if samples.count > cap { samples.removeFirst(samples.count - cap) }
    }

    public mutating func clear() { samples.removeAll(keepingCapacity: true) }
    public var seconds: Double { Double(samples.count) / sampleRate }
}
