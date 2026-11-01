import Foundation

/// Where a warm-up stands (LINGO-05 WR-01…WR-03): a pure function of the journal and the time, so a restart or Resume continues it.
public struct WarmupState: Sendable, Equatable {
    /// The frozen queue (`activity.cards`).
    public var cards: [String]
    /// Counted reviews of this session (a skip is `again`).
    public var reviewed: [String: CardRating]
    /// The card being practised; nil once every card is reviewed or the time limit has passed with the last card done.
    public var current: String?
    /// The card after it; nil after the time limit.
    public var next: String?
    /// Answers on the current card that got no rating (only the "no valid `@grade`" row counts; WR-03).
    public var unratedAnswers: Int
    /// The learner spoke Russian on the current card: its rating is capped at `hard`.
    public var russianOnCurrent: Bool
    /// The time budget runs from the start or the latest Resume.
    public var startedAt: Date
    public var timeUp: Bool

    public var finished: Bool { current == nil }
}

public enum Warmup {
    public static let maxCards = 8
    public static let duration: TimeInterval = 5 * 60
    /// The second unrated answer on the same card skips it.
    public static let unratedLimit = 2

    /// A warm-up session over the frozen queue (WR-01): "Questions" with a fixed title for older builds, the assistant opens, no
    /// vocabulary block (PX-02).
    public static func settings(lang: Lang, cards: [String], corrections: Set<CorrectionMode>, level: String = "") -> SessionSettings {
        SessionSettings(lang: lang, mode: .questions, topic: title(lang), level: level,
                        corrections: corrections.isEmpty ? [.inline] : corrections, starter: .assistant, useVocabulary: false,
                        activity: .warmup(Array(cards.prefix(maxCards))))
    }

    /// The topic an older build shows (study language).
    public static func title(_ lang: Lang) -> String {
        lang == .de ? "Wiederholung meiner Wörter" : "Reviewing my words"
    }

    /// The fixed closing line when the warm-up ends without a model turn (WR-04).
    public static func closingLine(_ lang: Lang) -> String {
        lang == .de ? "Das war's für heute. Gut gemacht!" : "That's it for today. Well done!"
    }

    /// The rating in a reply: the first valid `@grade` line ("wait" included), nil when there is none (WR-03).
    public static func grade(in reply: String) -> String? {
        let valid = Set(CardRating.allCases.map(\.rawValue) + ["wait"])
        return ReplyProtocol.silentValues(reply, tag: "grade").map { $0.lowercased() }.first { valid.contains($0) }
    }

    /// A rating capped at `hard` after a Russian turn on the card.
    public static func capped(_ r: CardRating, russian: Bool) -> CardRating {
        russian && (r == .good || r == .easy) ? .hard : r
    }
}

public extension HistoryState {
    /// The state of a warm-up session at `now`; nil for other sessions.
    func warmupState(session sid: String, now: Date) -> WarmupState? {
        guard let s = sessions[sid], let cards = s.settings.warmupCards else { return nil }
        var reviewed: [String: CardRating] = [:]
        var lastReview: Date?
        for (card, list) in cardReviews {
            guard let r = list.first(where: { $0.session == sid }) else { continue }
            reviewed[card] = r.rating
            lastReview = max(lastReview ?? r.at, r.at)
        }
        let startedAt = max(s.createdAt, s.resumedAt ?? s.createdAt)
        let deadline = startedAt.addingTimeInterval(Warmup.duration)
        let timeUp = now >= deadline
        let open = cards.filter { reviewed[$0] == nil }
        // After the limit, the card in progress is finished and the warm-up ends with its review.
        let doneAfterLimit = timeUp && (lastReview.map { $0 >= deadline } ?? false)
        let current = doneAfterLimit ? nil : open.first
        let next = timeUp || current == nil ? nil : open.dropFirst().first
        // Learner turns on the current card: after the last review of this session.
        var unrated = 0, russian = false
        let msgs = (messages[sid] ?? []).filter { $0.kind == .normal }
        for (i, m) in msgs.enumerated() where m.role == .user && lastReview.map({ m.createdAt > $0 }) ?? true {
            if m.lang == .ru { russian = true; continue }
            if CommandDetector.detect(m.text) != nil { continue }
            guard let reply = msgs[(i + 1)...].first(where: { $0.role == .assistant }) else { continue }
            if Warmup.grade(in: reply.text) == nil { unrated += 1 }
        }
        return WarmupState(cards: cards, reviewed: reviewed, current: current, next: next, unratedAnswers: unrated,
                           russianOnCurrent: russian, startedAt: startedAt, timeUp: timeUp)
    }

    /// A card of a language by id (for the `<card>` block).
    func card(_ id: String, lang: Lang) -> Card? { cards(lang: lang).first { $0.id == id } }
}
