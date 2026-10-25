import Foundation

/// Сессия (R-01). Строится из событий журнала (R-35, R-37).
public struct Session: Sendable, Hashable, Identifiable {
    public enum State: String, Codable, Sendable, Hashable { case active, ended }

    public var id: String
    public var title: String
    public var settings: SessionSettings
    public var createdAt: Date
    public var lastActivity: Date
    public var state: State
    public var deleted: Bool
    /// Краткое содержание для контекста модели (R-04).
    public var summary: String
    /// Последнее сообщение, учтённое в кратком содержании.
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

/// Даты строки сессии в стиле макета: «Сегодня, 14:28», «12 мая, 17:03», «28 апр., 14:06» (R-05).
public enum SessionDateFormat {
    public static func rowDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened)
            .locale(Locale(identifier: "ru_RU")))
        if calendar.isDate(date, inSameDayAs: now) { return "Сегодня, \(time)" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) {
            return "Вчера, \(time)"
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted).locale(Locale(identifier: "ru_RU")).day().month(.abbreviated)
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        return "\(date.formatted(style)), \(time)"
    }

    /// Время в пузыре: «14:28».
    public static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(Locale(identifier: "ru_RU")))
    }
}
