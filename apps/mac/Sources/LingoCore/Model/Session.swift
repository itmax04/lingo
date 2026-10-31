import Foundation

/// A session (R-01). Built from journal events (R-35, R-37).
public struct Session: Sendable, Hashable, Identifiable {
    public enum State: String, Codable, Sendable, Hashable { case active, ended }

    public var id: String
    public var title: String
    public var settings: SessionSettings
    public var createdAt: Date
    public var lastActivity: Date
    public var state: State
    public var deleted: Bool
    /// Summary for the model context (R-04).
    public var summary: String
    /// The last message included in the summary.
    public var summaryThrough: String?

    public init(id: String, title: String, settings: SessionSettings, createdAt: Date, lastActivity: Date,
                state: State = .active, deleted: Bool = false, summary: String = "", summaryThrough: String? = nil) {
        self.id = id
        self.title = title
        self.settings = settings
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.state = state
        self.deleted = deleted
        self.summary = summary
        self.summaryThrough = summaryThrough
    }
}

/// Session row dates in the mockup style: "Today, 14:28", "12 May, 17:03", "28 Apr, 14:06" (R-05).
public enum SessionDateFormat {
    /// Locale of the interface language (the app's chosen localization), so dates match the UI text.
    public static var locale: Locale { Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en") }

    public static func rowDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
            .locale(locale))
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today, \(time)") }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) {
            return String(localized: "Yesterday, \(time)")
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted).locale(locale).day().month(.abbreviated)
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        return "\(date.formatted(style)), \(time)"
    }

    /// Time in a bubble: "14:28".
    public static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
}
