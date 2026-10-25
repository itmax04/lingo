import AppKit
import LingoCore
import SwiftUI

/// Настройки → «Квота» (R-52): расход за сегодня по моделям из журнала расхода, без текста реплик и ключей.
struct QuotaView: View {
    let services: AppServices
    @State private var rows: [UsageRecorder.DaySummary] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Расход сегодня",
                             subtitle: "По данным провайдера: входные / выходные / кэшированные токены (кэшированные у Groq не идут в лимиты). Пусто — провайдер не сообщил. Бесплатный Groq: 8 000 токенов в минуту и 200 000 в сутки на модель на весь аккаунт.") {
                    if rows.isEmpty {
                        Text("Сегодня запросов не было.").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary)
                    }
                    ForEach(rows, id: \.model) { r in QuotaRow(r: r) }
                    HStack(spacing: Theme.S.s12) {
                        Button("Обновить") { rows = services.usage.today() }
                        Button("Показать журнал расхода") { NSWorkspace.shared.activateFileViewerSelecting([services.usage.dir]) }
                    }
                }
                SettingsCard(title: "Версия") {
                    Text(AppVersion.string).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
        .onAppear { rows = services.usage.today() }
    }

}

struct QuotaRow: View {
    let r: UsageRecorder.DaySummary

    var counts: String { "запросов \(r.requests) (успешно \(r.ok), отказов по лимиту \(r.limited)) · вход \(r.input) · выход \(r.output) · кэш \(r.cached)" }
    var details: String {
        var t = "по назначению: " + r.byPurpose.sorted { $0.key < $1.key }.map { "\(Self.label($0.key)) \($0.value)" }.joined(separator: ", ")
        if let rem = r.lastRemainingTokens { t += " · остаток на минуту: \(rem) токенов" }
        if let l = r.lastLimit { t += " · последний отказ: \(l.title)" }
        return t
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            Text(StepInfo.shortModel(r.model)).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
            Text(counts).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            Text(details).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
        }
    }

    static func label(_ p: String) -> String {
        switch p {
        case "dialog": "диалог"
        case "summary": "краткое содержание"
        case "topicPhrases": "фразы темы"
        case "recap": "итог"
        case "eval": "оценки"
        default: p
        }
    }
}

enum AppVersion {
    static var string: String {
        let i = Bundle.main.infoDictionary ?? [:]
        let v = i["CFBundleShortVersionString"] as? String ?? "dev"
        let b = i["CFBundleVersion"] as? String ?? "0"
        let rev = i["LingoGitRevision"] as? String ?? "локальная сборка"
        let date = i["LingoBuildDate"] as? String ?? ""
        return "Lingo \(v) (сборка \(b), \(rev))" + (date.isEmpty ? "" : " · \(date)")
    }
}
