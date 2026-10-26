import Foundation

/// Model context policy (R-04): system wrapper + summary + the last N turns.
/// A turn is a user utterance together with the assistant's reply.
public struct ContextPolicy: Sendable, Hashable, Codable {
    /// N: 8 by default (Q29, was 20), from 6 to 40.
    public var maxTurns: Int
    /// The summary is updated every 10 turns and when the session ends.
    public var summaryEvery: Int

    public static let turnsRange: ClosedRange<Int> = 6...40

    /// Character budget for the transcript in a request (≈ 1800 tokens, R-04 in spec v2.2): old turns are dropped before N is reached.
    public static let transcriptCharBudget = 6300

    public init(maxTurns: Int = 8, summaryEvery: Int = 10) {
        self.maxTurns = maxTurns.clamped(to: Self.turnsRange)
        self.summaryEvery = summaryEvery
    }

    /// Messages for `<transcript>`: starting from the N-th user utterance from the end (plus the assistant's first message if it started).
    /// Service messages (recap, chain errors) are not included in the context.
    public func window(_ messages: [ChatMessage]) -> [ChatMessage] {
        let real = messages.filter { $0.kind == .normal }
        let userIdx = real.indices.filter { real[$0].role == .user }
        var w = userIdx.count > maxTurns ? Array(real[userIdx[userIdx.count - maxTurns]...]) : real
        // Character budget: drop the oldest turns, but always keep the last turn.
        func size(_ m: [ChatMessage]) -> Int { m.reduce(0) { $0 + ($1.role == .assistant ? $1.spokenText.count + 40 : $1.text.count) + 24 } }
        while size(w) > Self.transcriptCharBudget, let next = w.dropFirst().firstIndex(where: { $0.role == .user }) {
            w = Array(w[next...])
        }
        return w
    }

    /// Number of turns (user utterances) since the last summary.
    public func turnsSinceSummary(_ messages: [ChatMessage], through: String?) -> Int {
        let real = messages.filter { $0.kind == .normal }
        var after = real[...]
        if let t = through, let i = real.firstIndex(where: { $0.id == t }) { after = real[(i + 1)...] }
        return after.filter { $0.role == .user }.count
    }

    public func needsSummary(_ messages: [ChatMessage], through: String?) -> Bool {
        turnsSinceSummary(messages, through: through) >= summaryEvery
    }

    /// Header hint (S-16): the UI does not promise that the model remembers everything.
    public func memoryNote() -> String {
        String(localized: "The assistant remembers a summary and the last \(maxTurns) turns")
    }
}
