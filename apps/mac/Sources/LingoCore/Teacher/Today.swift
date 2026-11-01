import Foundation

/// What to do next in one language (LINGO-05 GR-03): the warm-up when cards are due, else the next scenario, else free conversation.
public enum NextActivity: Sendable, Equatable {
    case warmup(cards: Int)
    case scenario(id: String)
    case freeConversation
}

public struct LanguagePlan: Sendable, Equatable, Identifiable {
    public var lang: Lang
    public var next: NextActivity
    public var id: Lang { lang }
    /// About how long the warm-up takes: ⌈min(queue, 8) × 0.6⌉ minutes.
    public var warmupMinutes: Int {
        if case .warmup(let n) = next { return Int((Double(min(n, Warmup.maxCards)) * 0.6).rounded(.up)) }
        return 0
    }
}

/// The "Today" screen (GR-03): a plan per study language, the daily goal and the streak.
public struct TodaySummary: Sendable, Equatable {
    public var plans: [LanguagePlan]
    public var goalMinutes: Int
    public var minutesToday: Int
    public var streak: Int
    /// The last seven local days, oldest first, today last: whether the day reached its goal.
    public var week: [Bool]
    public var goalReached: Bool { minutesToday >= goalMinutes }
}

/// How a finished (or running) warm-up went (WR-04).
public struct WarmupSummary: Sendable, Equatable {
    public var reviewed: Int
    public var again: Int, hard: Int, good: Int, easy: Int
    /// The session's cards that have a rating, in queue order.
    public var cards: [(card: Card, rating: CardRating)]
    /// The earliest due time among the cards reviewed in this session (not suspended); nil when none.
    public var nextDue: Date?

    public static func == (a: WarmupSummary, b: WarmupSummary) -> Bool {
        a.reviewed == b.reviewed && a.again == b.again && a.hard == b.hard && a.good == b.good && a.easy == b.easy
            && a.nextDue == b.nextDue && a.cards.map(\.card) == b.cards.map(\.card) && a.cards.map(\.rating) == b.cards.map(\.rating)
    }
}

public extension HistoryState {
    static let activeLanguageDays = 30

    /// The plan, goal and streak for `now`. Languages with a live session in the last 30 days, otherwise German and English.
    func todaySummary(now: Date, calendar: Calendar = .autoupdatingCurrent) -> TodaySummary {
        let since = now.addingTimeInterval(-Double(Self.activeLanguageDays) * 86_400)
        var langs = Set(sessions.values.filter { !$0.deleted && $0.lastActivity >= since }.map(\.settings.lang)).intersection([.de, .en])
        if langs.isEmpty { langs = [.de, .en] }
        let plans = [Lang.de, .en].filter(langs.contains).map { lang -> LanguagePlan in
            let queue = dueCards(lang: lang, now: now, calendar: calendar).count
            let next: NextActivity = queue > 0 ? .warmup(cards: min(queue, Warmup.maxCards))
                : nextScenario(lang: lang).map { .scenario(id: $0.id) } ?? .freeConversation
            return LanguagePlan(lang: lang, next: next)
        }
        let stats = dayStats(calendar: calendar)
        let today = calendar.startOfDay(for: now)
        func counted(_ d: Date) -> Bool { (stats[d]?.practiceMinutes ?? 0) >= goalMinutes(on: d, calendar: calendar) }
        let week = (0..<7).reversed().map { back -> Bool in
            counted(calendar.startOfDay(for: calendar.date(byAdding: .day, value: -back, to: today)!))
        }
        return TodaySummary(plans: plans, goalMinutes: goalMinutes(on: now, calendar: calendar), minutesToday: stats[today]?.practiceMinutes ?? 0,
                            streak: streak(now: now, calendar: calendar), week: week)
    }

    /// Counts, cards and the next due time of a warm-up session; nil for other sessions.
    func warmupSummary(session sid: String) -> WarmupSummary? {
        guard let s = sessions[sid], let queue = s.settings.warmupCards else { return nil }
        let byID = Dictionary(uniqueKeysWithValues: cards(lang: s.settings.lang).map { ($0.id, $0) })
        var rated: [(card: Card, rating: CardRating)] = []
        var due: [Date] = []
        for id in queue {
            guard let r = cardReviews[id]?.first(where: { $0.session == sid }), let card = byID[id] else { continue }
            rated.append((card, r.rating))
            if !suspendedCards.contains(id), let st = cardState(id) { due.append(st.due) }
        }
        func n(_ r: CardRating) -> Int { rated.filter { $0.rating == r }.count }
        return WarmupSummary(reviewed: rated.count, again: n(.again), hard: n(.hard), good: n(.good), easy: n(.easy), cards: rated, nextDue: due.min())
    }

    /// Suspended cards of a language that still exist, by id bytes (the "Suspended cards" list, WR-05).
    func suspendedCardList(lang: Lang) -> [Card] {
        cards(lang: lang).filter { suspendedCards.contains($0.id) }
    }
}
