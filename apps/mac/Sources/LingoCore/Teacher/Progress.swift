import Foundation

/// One local day on the Progress charts (GR-04).
public struct DayMinutes: Sendable, Hashable, Identifiable {
    public var day: Date
    public var minutes: Int
    public var id: Date { day }
}

/// One ISO week on the Progress charts (GR-04). `mistakesPer100` is nil for a week without learner words.
public struct WeekPoint: Sendable, Hashable, Identifiable {
    public var start: Date
    public var words: Int
    public var mistakesPer100: Double?
    public var id: Date { start }
}

/// Everything the Progress screen shows, computed locally from the journal (GR-04).
public struct ProgressData: Sendable, Hashable {
    /// The last 30 local days, oldest first; the last 7 are the "7 days" view.
    public var days: [DayMinutes] = []
    /// The last 8 ISO weeks (Monday first), oldest first.
    public var weeks: [WeekPoint] = []
    /// Cards by state over both languages; suspended cards are left out.
    public var cards = CardCounts()
    public var totalMinutes = 0
    public var totalWords = 0
    public var totalMistakes = 0
    public var vocabularyUsed = 0
    public var hasData: Bool { totalMinutes > 0 || totalWords > 0 || cards.new + cards.learning + cards.mature > 0 }
}

public extension HistoryState {
    static let progressDays = 30
    static let progressWeeks = 8

    func progress(now: Date, calendar: Calendar = .autoupdatingCurrent) -> ProgressData {
        var out = ProgressData()
        let stats = dayStats(calendar: calendar)
        let today = calendar.startOfDay(for: now)
        func previous(_ d: Date, _ n: Int) -> Date { calendar.startOfDay(for: calendar.date(byAdding: .day, value: -n, to: d) ?? d.addingTimeInterval(-Double(n) * 86_400)) }
        out.days = (0..<Self.progressDays).reversed().map { n in
            let d = previous(today, n)
            return DayMinutes(day: d, minutes: stats[d]?.practiceMinutes ?? 0)
        }
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        var words: [Date: Int] = [:]
        for (d, s) in stats {
            if let start = iso.dateInterval(of: .weekOfYear, for: d)?.start { words[start, default: 0] += s.learnerWords }
        }
        let rates = mistakesPer100Words(calendar: calendar)
        let thisWeek = iso.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        out.weeks = (0..<Self.progressWeeks).reversed().map { n in
            let start = iso.date(byAdding: .weekOfYear, value: -n, to: thisWeek) ?? thisWeek
            return WeekPoint(start: start, words: words[start] ?? 0, mistakesPer100: rates[start])
        }
        for lang in [Lang.de, .en] {
            let c = cardCounts(lang: lang, now: now, calendar: calendar)
            out.cards.new += c.new; out.cards.learning += c.learning; out.cards.mature += c.mature; out.cards.dueToday += c.dueToday
        }
        out.totalMinutes = Int(stats.values.reduce(Int64(0)) { $0 + $1.practiceMs } / 60_000)
        out.totalWords = stats.values.reduce(0) { $0 + $1.learnerWords }
        out.totalMistakes = stats.values.reduce(0) { $0 + $1.mistakes }
        out.vocabularyUsed = stats.values.reduce(0) { $0 + $1.vocabularyUsed }
        return out
    }
}
