import Foundation

/// Practice of one local day (LINGO-05 GR-01).
public struct DayStats: Sendable, Hashable {
    public var practiceSeconds: Double = 0
    public var sessions = 0
    public var learnerWords = 0
    public var vocabularyUsed = 0
    public var mistakes = 0
    /// Shown minutes are rounded down.
    public var practiceMinutes: Int { Int(practiceSeconds / 60) }
    public init() {}
}

/// Cards by state (GR-01); suspended cards are left out.
public struct CardCounts: Sendable, Hashable {
    public var new = 0, learning = 0, mature = 0, dueToday = 0
}

/// A `goal.set` event (GR-02).
public struct GoalSet: Sendable, Hashable {
    public var minutes: Int
    public var ts: Date
    public var version: Version
}

public extension HistoryState {
    static let gapCap: TimeInterval = 120
    /// A longer gap is a break (e.g. a session resumed days later) and adds nothing.
    static let breakGap: TimeInterval = 600
    static let defaultGoalMinutes = 15
    static let goalRange = 5...120
    static let matureStability = 21.0

    /// Statistics per local day (start of day → stats), per language or in total. A pure function of the state and the calendar.
    func dayStats(lang: Lang? = nil, calendar: Calendar = .autoupdatingCurrent) -> [Date: DayStats] {
        var out: [Date: DayStats] = [:]
        func day(_ d: Date) -> Date { calendar.startOfDay(for: d) }
        let live = sessions.values.filter { !$0.deleted && (lang == nil || $0.settings.lang == lang) }
        let liveIDs = Set(live.map(\.id))
        for s in live {
            let counted = (messages[s.id] ?? []).filter { $0.kind == .normal }
            // Each gap between consecutive messages, capped at 2 minutes, belongs to the day of the later message; a break adds nothing.
            for (a, b) in zip(counted, counted.dropFirst()) {
                let gap = max(0, b.createdAt.timeIntervalSince(a.createdAt))
                out[day(b.createdAt), default: DayStats()].practiceSeconds += gap > Self.breakGap ? 0 : min(Self.gapCap, gap)
            }
            var days: Set<Date> = []
            for m in counted where m.role == .user {
                out[day(m.createdAt), default: DayStats()].learnerWords += Self.wordCount(m.text)
                days.insert(day(m.createdAt))
            }
            for d in days { out[d, default: DayStats()].sessions += 1 }
        }
        for u in vocabUses where u.by == .learner && liveIDs.contains(u.session) {
            out[day(u.at), default: DayStats()].vocabularyUsed += 1
        }
        for (sid, list) in fixes where liveIDs.contains(sid) {
            var seen: Set<String> = []
            for f in list where seen.insert([f.message, VocabularyText.normalize(f.fix.original), VocabularyText.normalize(f.fix.corrected)].joined(separator: "\u{0}")).inserted {
                out[day(f.ts), default: DayStats()].mistakes += 1
            }
        }
        return out
    }

    /// Mistakes per 100 learner words per ISO week (Monday–Sunday, local; week start → rate), for weeks with learner words.
    func mistakesPer100Words(lang: Lang? = nil, calendar: Calendar = .autoupdatingCurrent) -> [Date: Double] {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        var weeks: [Date: (mistakes: Int, words: Int)] = [:]
        for (d, s) in dayStats(lang: lang, calendar: calendar) {
            guard let start = iso.dateInterval(of: .weekOfYear, for: d)?.start else { continue }
            weeks[start, default: (0, 0)].mistakes += s.mistakes
            weeks[start, default: (0, 0)].words += s.learnerWords
        }
        return weeks.compactMapValues { $0.words > 0 ? Double($0.mistakes) * 100 / Double($0.words) : nil }
    }

    /// Cards by state for a language (GR-01): new, learning (S < 21), mature (S ≥ 21), and due today (CR-04, the due part only).
    func cardCounts(lang: Lang, now: Date, calendar: Calendar = .autoupdatingCurrent) -> CardCounts {
        var c = CardCounts()
        let today = calendar.startOfDay(for: now)
        for card in cards(lang: lang) where !suspendedCards.contains(card.id) {
            guard let st = cardState(card.id) else { c.new += 1; continue }
            if st.stability < Self.matureStability { c.learning += 1 } else { c.mature += 1 }
            if calendar.startOfDay(for: st.due) <= today { c.dueToday += 1 }
        }
        return c
    }

    /// The goal in force at the end of a local day (GR-02): the last writer among `goal.set` events made up to then; 15 before any.
    func goalMinutes(on day: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return goalSets.filter { $0.ts < end }.max { $0.version < $1.version }?.minutes ?? Self.defaultGoalMinutes
    }

    /// Consecutive local days that reached their goal, up to today (today counts once reached, otherwise the streak runs to
    /// yesterday). All languages together.
    func streak(now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        let stats = dayStats(calendar: calendar)
        func counted(_ d: Date) -> Bool { (stats[d]?.practiceMinutes ?? 0) >= goalMinutes(on: d, calendar: calendar) }
        var d = calendar.startOfDay(for: now)
        if !counted(d) { d = calendar.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while counted(d) {
            n += 1
            d = calendar.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    /// Words of a learner message: tokens split on Unicode whitespace that contain a letter.
    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).filter { $0.contains(where: \.isLetter) }.count
    }
}
