import AppKit
import LingoCore
import SwiftUI

/// Settings → "Quota" (R-52): today's usage per model from the usage log, without utterance texts or keys.
struct QuotaView: View {
    let services: AppServices
    @State private var rows: [UsageRecorder.DaySummary] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Usage today",
                             subtitle: "As reported by the provider: input / output / cached tokens (on Groq cached tokens do not count toward limits). Empty — the provider did not report it. Free Groq: 8,000 tokens per minute and 200,000 per day per model for the whole account.") {
                    if rows.isEmpty {
                        Text("No requests today.").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary)
                    }
                    ForEach(rows, id: \.model) { r in QuotaRow(r: r) }
                    HStack(spacing: Theme.S.s12) {
                        Button("Refresh") { rows = services.usage.today() }
                        Button("Show usage log") { NSWorkspace.shared.activateFileViewerSelecting([services.usage.dir]) }
                    }
                }
                SettingsCard(title: "Version") {
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

    var counts: String { String(localized: "requests \(r.requests) (succeeded \(r.ok), rate-limited \(r.limited)) · input \(r.input) · output \(r.output) · cached \(r.cached)") }
    var details: String {
        var t = String(localized: "by purpose: ") + r.byPurpose.sorted { $0.key < $1.key }.map { "\(Self.label($0.key)) \($0.value)" }.joined(separator: ", ")
        if let rem = r.lastRemainingTokens { t += " · " + String(localized: "left this minute: \(rem) tokens") }
        if let l = r.lastLimit { t += " · " + String(localized: "last refusal: \(l.title)") }
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
        case "dialog": String(localized: "dialogue")
        case "summary": String(localized: "summary")
        case "topicPhrases": String(localized: "topic phrases")
        case "recap": String(localized: "recap")
        case "examFeedback": String(localized: "exam debrief")
        case "weeklyReport": String(localized: "weekly report")
        case "memory": String(localized: "memory")
        case "replyOptions": String(localized: "reply options")
        case "eval": String(localized: "evals")
        case "translate": String(localized: "translation")
        default: p
        }
    }
}

enum AppVersion {
    static var string: String {
        let i = Bundle.main.infoDictionary ?? [:]
        let v = i["CFBundleShortVersionString"] as? String ?? "dev"
        let b = i["CFBundleVersion"] as? String ?? "0"
        let rev = i["LingoGitRevision"] as? String ?? String(localized: "local build")
        let date = i["LingoBuildDate"] as? String ?? ""
        return String(localized: "Lingo \(v) (build \(b), \(rev))") + (date.isEmpty ? "" : " · \(date)")
    }
}
