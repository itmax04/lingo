import Foundation

/// Recognition result of one utterance (R-08).
public struct Transcription: Sendable, Equatable {
    public var text: String
    public var lang: Lang
    /// Probabilities (whisper) or confidence (Apple) per candidate language.
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

/// Recognition engine (ADR-0001 §6). The utterance language is chosen among the candidates {target, ru} (R-08);
/// `forced` — the "I'm speaking Russian" button (R-09). Audio is 16 kHz mono in memory and is never written to disk.
public protocol SpeechRecognizer: Sendable {
    var id: String { get }
    /// `context` — a hint from the conversation (R-51): the assistant's last line, the topic, hint phrases.
    func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription
}

public extension SpeechRecognizer {
    func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?) async throws -> Transcription {
        try await transcribe(samples, candidates: candidates, forced: forced, context: nil)
    }
}

/// Recognition hint from the conversation context (R-51). whisper uses up to ~224 prompt tokens,
/// so it takes the last sentences of the assistant's line, the topic and a few hint phrases.
public enum RecognitionContext {
    /// `targets` (LINGO-08 VR-07c): the learner's own words of the session, at most 30 words and `maxTargetChars` characters (whole words only);
    /// they are put last so that they survive the cut, and the cap leaves room for the topic and the assistant's line.
    public static let maxTargetChars = 160

    public static func make(lastAssistant: String?, topic: String, phrases: [String], targets: [String] = [], maxChars: Int = 360) -> String? {
        var parts: [String] = []
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { parts.append(t + ".") }
        for p in phrases.prefix(4) where !p.isEmpty { parts.append(p) }
        if let a = lastAssistant?.trimmingCharacters(in: .whitespacesAndNewlines), !a.isEmpty {
            parts.append(String(a.suffix(200)))
        }
        var words: [String] = []
        var chars = 0
        for w in targets.flatMap({ $0.split(separator: " ").map(String.init) }).prefix(30) {
            guard chars + w.count + (words.isEmpty ? 0 : 1) <= maxTargetChars else { break }
            chars += w.count + (words.isEmpty ? 0 : 1)
            words.append(w)
        }
        if !words.isEmpty { parts.append(words.joined(separator: " ") + ".") }
        guard !parts.isEmpty else { return nil }
        let joined = parts.joined(separator: " ")
        return String(joined.suffix(maxChars))
    }
}

/// In-memory utterance buffer: at most 60 s (R-08). Old samples are dropped.
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
