import Foundation

/// Authorization of the system notification centre, as far as the reminder cares (GR-08).
public enum ReminderAuth: Sendable, Equatable { case notDetermined, authorized, denied }

/// What the reminder is doing, for the settings screen.
public enum ReminderStatus: Sendable, Equatable {
    case off
    /// On, but the system has not allowed notifications (denied or not yet asked): nothing is pending.
    case blocked(ReminderAuth)
    case scheduled(Date)
    /// On and allowed, nothing pending (cannot happen with a valid time; kept so the switch never lies).
    case idle
}

/// The system side of the reminder (a `UNUserNotificationCenter` in the app, a fake in tests).
public protocol ReminderCenter: Sendable {
    func authorization() async -> ReminderAuth
    /// Shows the system prompt (only when the learner turns the reminder on). True when allowed.
    func requestAuthorization() async -> Bool
    func cancel(id: String) async
    /// Replaces the pending notification `id` with one at `fire`.
    func schedule(id: String, fire: Date, title: String, body: String) async
}

/// The daily reminder (LINGO-05 GR-08): one pending local notification for the next reminder time. Device-local by design.
public enum Reminder {
    public static let notificationID = "lingo.daily-reminder"
    public static let defaultTime = 19 * 60  // minutes after local midnight
    public static func clamp(_ minutes: Int) -> Int { min(max(minutes, 0), 24 * 60 - 1) }

    /// The time of the one pending notification, or nil when the reminder is off. Today's time while it is still ahead and today's goal is
    /// not reached; otherwise tomorrow's (reaching the goal removes today's and schedules tomorrow's).
    public static func next(now: Date, calendar: Calendar = .autoupdatingCurrent, goalReached: Bool, on: Bool, time: Int) -> Date? {
        guard on else { return nil }
        let m = clamp(time)
        func at(_ day: Date) -> Date? {
            calendar.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: day, matchingPolicy: .nextTime)
        }
        let today = calendar.startOfDay(for: now)
        if !goalReached, let t = at(today), t > now { return t }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        return at(tomorrow)
    }

    /// Makes the system's pending notification match the state: cancels it, or replaces it with the next one. Never asks for permission.
    /// `text` builds the title and body from the learner's goal and language (localised by the app).
    @discardableResult
    public static func sync(state: HistoryState, settings: AppSettings, now: Date, calendar: Calendar = .autoupdatingCurrent,
                            center: ReminderCenter, text: @Sendable (_ minutes: Int, _ lang: Lang) -> (title: String, body: String)) async -> ReminderStatus {
        guard settings.reminderOn else { await center.cancel(id: notificationID); return .off }
        let auth = await center.authorization()
        guard auth == .authorized else { await center.cancel(id: notificationID); return .blocked(auth) }
        let today = state.todaySummary(now: now, calendar: calendar)
        guard let fire = next(now: now, calendar: calendar, goalReached: today.goalReached, on: true, time: settings.reminderTime) else {
            await center.cancel(id: notificationID); return .idle
        }
        let t = text(today.goalMinutes, settings.lastLang)
        await center.schedule(id: notificationID, fire: fire, title: t.title, body: t.body)
        return .scheduled(fire)
    }
}
