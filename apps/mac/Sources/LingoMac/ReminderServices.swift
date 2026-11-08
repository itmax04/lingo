import AppKit
import Foundation
import LingoCore
import UserNotifications

/// The system notification centre behind `ReminderCenter` (GR-08). Outside an app bundle (tests, command-line checks) there is no
/// centre: it reports "denied" and does nothing.
struct SystemReminderCenter: ReminderCenter {
    private var center: UNUserNotificationCenter? { Bundle.main.bundleURL.pathExtension == "app" ? UNUserNotificationCenter.current() : nil }

    func authorization() async -> ReminderAuth {
        guard let center else { return .denied }
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .authorized
        }
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func cancel(id: String) async {
        center?.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func schedule(id: String, fire: Date, title: String, body: String) async {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var parts = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        parts.second = 0
        // The same identifier replaces the pending request: exactly one is ever pending.
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}

@MainActor
extension AppServices {
    /// "Time for 15 minutes of German?" in the interface language (RU/EN catalog), from the learner's goal and study language.
    nonisolated static func reminderText(minutes: Int, lang: Lang) -> (title: String, body: String) {
        let body = lang == .de ? String(localized: "Time for \(minutes) minutes of German?") : String(localized: "Time for \(minutes) minutes of English?")
        return ("Lingo", body)
    }

    /// Makes the pending notification match the journal and the settings (never asks for permission).
    func syncReminder(state: HistoryState? = nil) async {
        let st: HistoryState
        if let state { st = state } else { st = await store.state }
        let status = await Reminder.sync(state: st, settings: settings, now: Date(), center: SystemReminderCenter(),
                                         text: { Self.reminderText(minutes: $0, lang: $1) })
        model.reminderStatus = status
        reminderSignature = signature(for: st)
    }

    /// A journal change: re-sync only when something the reminder depends on changed (goal reached, goal, day).
    func reminderStateChanged(_ state: HistoryState) {
        guard settings.reminderOn, signature(for: state) != reminderSignature else { return }
        Task { await syncReminder(state: state) }
    }

    private func signature(for state: HistoryState) -> String {
        let t = state.todaySummary(now: Date())
        let day = Calendar.autoupdatingCurrent.startOfDay(for: Date()).timeIntervalSince1970
        return "\(settings.reminderOn)|\(settings.reminderTime)|\(settings.lastLang.rawValue)|\(t.goalReached)|\(t.goalMinutes)|\(day)"
    }

    /// The switch: asks the system for permission only now, then schedules (or shows why it cannot).
    func setReminder(on: Bool) {
        updateSettings { $0.reminderOn = on }
        Task {
            let center = SystemReminderCenter()
            if on, await center.authorization() == .notDetermined { _ = await center.requestAuthorization() }
            await syncReminder()
        }
    }

    func setReminderTime(minutes: Int) {
        updateSettings { $0.reminderTime = Reminder.clamp(minutes) }
        Task { await syncReminder() }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}
