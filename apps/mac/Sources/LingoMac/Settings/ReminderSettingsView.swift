import LingoCore
import SwiftUI

/// Settings → "Reminder" (LINGO-05 GR-08): one local notification a day while the goal is not reached. Off by default; the system
/// permission is asked only when the switch is turned on, and a refusal is shown next to the switch.
struct ReminderSettingsView: View {
    let services: AppServices
    var model: AppModel { services.model }

    private var timeBinding: Binding<Date> {
        Binding(get: {
            let m = services.settings.reminderTime
            return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
        }, set: {
            let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
            services.setReminderTime(minutes: (c.hour ?? 19) * 60 + (c.minute ?? 0))
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Daily reminder",
                             subtitle: "A notification on this Mac at the chosen time while today's goal is not reached. It is local to this Mac; nothing is sent anywhere.") {
                    Toggle("Remind me to practise", isOn: Binding(get: { services.settings.reminderOn }, set: { services.setReminder(on: $0) }))
                        .tint(Theme.accent(model.studyLanguage))
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .disabled(!services.settings.reminderOn)
                    status
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }

    @ViewBuilder private var status: some View {
        switch model.reminderStatus {
        case .blocked(let auth):
            VStack(alignment: .leading, spacing: Theme.S.s8) {
                Label(auth == .notDetermined
                      ? "Lingo has not been allowed to show notifications yet. Turn the switch off and on again, or allow them in System Settings → Notifications."
                      : "Notifications are not allowed for Lingo, so no reminder can be shown. Allow them in System Settings → Notifications.",
                      systemImage: "exclamationmark.triangle")
                    .font(Theme.F.hintTranslation).foregroundStyle(Theme.C.statusDanger).fixedSize(horizontal: false, vertical: true)
                Button("Open Notification Settings") { services.openNotificationSettings() }
            }
        case .scheduled(let date):
            Text("Next reminder: \(date.formatted(date: .abbreviated, time: .shortened))")
                .font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
        case .off, .idle:
            EmptyView()
        }
    }
}
