import Foundation

/// End-of-utterance and merging parameters (R-10, R-11).
public struct TurnConfig: Codable, Sendable, Hashable {
    /// T — silence after which the utterance is over: 1.5 s, from 0.6 to 3.0 s, step 0.1.
    public var silence: Double
    /// Minimum speech in an utterance: 0.3 s (shorter is noise, not an utterance).
    public var minSpeech: Double
    /// G — a new utterance started no later than G after the previous one ended is merged with it if the assistant has not started speaking.
    public var mergeGap: Double

    public static let silenceRange: ClosedRange<Double> = 0.6...3.0
    public static let mergeRange: ClosedRange<Double> = 0...4

    public init(silence: Double = 1.5, minSpeech: Double = 0.3, mergeGap: Double = 2.0) {
        self.silence = silence.clamped(to: Self.silenceRange)
        self.minSpeech = minSpeech
        self.mergeGap = mergeGap.clamped(to: Self.mergeRange)
    }
}

/// Utterance boundaries from VAD events (speech started/ended) and the passage of time. Pure logic: time is passed in.
public struct TurnSegmenter: Sendable {
    public struct Span: Sendable, Equatable, Codable {
        public var start: Double
        public var end: Double
        public init(start: Double, end: Double) { self.start = start; self.end = end }
        public var duration: Double { end - start }
    }

    public enum Event: Sendable, Equatable {
        /// Speech of a new utterance started (for barge-in and the UI).
        case speechBegan(at: Double, mergesWithPrevious: Bool)
        /// The utterance is over (silence ≥ T).
        case utterance(Span)
        /// The utterance is over and merged with the previous one (R-11): cancel the pending request and send the combined text.
        /// `span` — from the start of the previous utterance to the end of the new one.
        case merged(previous: Span, span: Span)
        /// Speech too short (< minSpeech) — not an utterance.
        case discarded(Span)
    }

    public var config: TurnConfig
    private var inSpeech = false
    private var segStart: Double = 0
    private var curStart: Double?
    private var lastSpeechEnd: Double = 0
    private var speechSum: Double = 0
    private var mergeCandidate = false
    private var previous: Span?
    private var assistantStarted = false

    public init(config: TurnConfig = TurnConfig()) { self.config = config }

    /// Whether an utterance is in progress (speech or a pause shorter than T).
    public var isInUtterance: Bool { curStart != nil }
    public var isSpeaking: Bool { inSpeech }

    public mutating func speechStarted(at t: Double) -> [Event] {
        guard !inSpeech else { return [] }
        inSpeech = true
        segStart = t
        if curStart == nil {
            curStart = t
            speechSum = 0
            if let p = previous, !assistantStarted, t - p.end <= config.mergeGap + 1e-6 {
                mergeCandidate = true
            } else {
                mergeCandidate = false
            }
            return [.speechBegan(at: t, mergesWithPrevious: mergeCandidate)]
        }
        return []
    }

    public mutating func speechEnded(at t: Double) -> [Event] {
        guard inSpeech else { return [] }
        inSpeech = false
        speechSum += max(0, t - segStart)
        lastSpeechEnd = t
        return []
    }

    /// Passage of time: closes the utterance after silence ≥ T.
    public mutating func advance(to t: Double) -> [Event] {
        guard !inSpeech, let start = curStart, t - lastSpeechEnd >= config.silence - 1e-6 else { return [] }
        let span = Span(start: start, end: lastSpeechEnd)
        curStart = nil
        if speechSum < config.minSpeech { return [.discarded(span)] }
        defer { assistantStarted = false }
        if mergeCandidate, let p = previous {
            let merged = Span(start: p.start, end: span.end)
            previous = merged
            mergeCandidate = false
            return [.merged(previous: p, span: merged)]
        }
        previous = span
        return [.utterance(span)]
    }

    /// The assistant started speaking: the next utterance is a new turn, not a merge (R-11 → R-12).
    public mutating func assistantStartedSpeaking() {
        assistantStarted = true
        mergeCandidate = false
    }

    /// Force the utterance to end (space released, the "Speak" button — R-06).
    public mutating func flush(at t: Double) -> [Event] {
        var out = speechEnded(at: t)
        let saved = config.silence
        config.silence = 0
        out += advance(to: max(t, lastSpeechEnd))
        config.silence = saved
        return out
    }

    public mutating func reset() {
        self = TurnSegmenter(config: config)
    }
}

/// Runs a speech/silence timeline (ms) through the segmenter — the `turn` eval and tests.
public enum TurnTimeline {
    public enum Piece: Sendable, Equatable { case speech(Int), silence(Int) }

    /// Final utterances after merges. `assistantAt` — moments (ms) when the assistant started speaking.
    public static func run(_ pieces: [Piece], config: TurnConfig = TurnConfig(), assistantAt: [Int] = [], stepMs: Int = 20) -> [TurnSegmenter.Span] {
        var seg = TurnSegmenter(config: config)
        var spans: [TurnSegmenter.Span] = []
        var t = 0
        var pendingAssistant = assistantAt.sorted()
        func apply(_ ev: [TurnSegmenter.Event]) {
            for e in ev {
                switch e {
                case .utterance(let s): spans.append(s)
                case .merged(_, let s):
                    if !spans.isEmpty { spans.removeLast() }
                    spans.append(s)
                default: break
                }
            }
        }
        for p in pieces {
            let (isSpeech, ms) = { switch p { case .speech(let m): return (true, m); case .silence(let m): return (false, m) } }()
            let sec = Double(t) / 1000
            apply(isSpeech ? seg.speechStarted(at: sec) : seg.speechEnded(at: sec))
            var k = 0
            while k < ms {
                k += stepMs
                let now = t + min(k, ms)
                while let a = pendingAssistant.first, a <= now { seg.assistantStartedSpeaking(); pendingAssistant.removeFirst() }
                apply(seg.advance(to: Double(now) / 1000))
            }
            t += ms
        }
        apply(seg.speechEnded(at: Double(t) / 1000))
        apply(seg.advance(to: Double(t) / 1000 + 100))
        return spans
    }
}
