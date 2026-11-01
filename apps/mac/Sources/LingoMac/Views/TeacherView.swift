import LingoCore
import SwiftUI

/// "Teacher" (LINGO-05 GR-07): the warm-up now; the other flows arrive in later steps and stay "Coming soon".
struct TeacherView: View {
    @Bindable var model: AppModel
    private let soon: [(title: LocalizedStringKey, symbol: String)] = [
        ("Scenarios", "bubble.left.and.bubble.right"), ("German B1 exam", "graduationcap"), ("IELTS Speaking", "mic"),
        ("Weekly report", "calendar"), ("What Lingo knows about me", "person.text.rectangle"),
    ]
    var body: some View {
        let now = Date()
        let plans = model.history.todaySummary(now: now).plans
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                Text("Teacher").font(Theme.F.title)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    warmupCard(plans)
                    ForEach(Array(soon.enumerated()), id: \.offset) { index, item in
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: item.symbol).font(.system(size: 24))
                                .foregroundStyle(index.isMultiple(of: 2) ? Theme.C.accentEnglish : Theme.C.accentGerman)
                            Text(item.title).font(Theme.F.panelTitle)
                            Label("Coming soon", systemImage: "clock").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                        }
                        .padding(24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
                        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
                        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
                    }
                }
                suspended
            }.padding(32)
        }
        .foregroundStyle(Theme.C.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bgWindow)
    }

    private func warmupCard(_ plans: [LanguagePlan]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "rectangle.on.rectangle").font(.system(size: 24)).foregroundStyle(Theme.C.accentGerman)
            Text("Warm-up").font(Theme.F.panelTitle)
            Text("Your words and mistakes, ready for another try.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            ForEach(plans) { plan in
                HStack {
                    Text(languageTitle(plan.lang)).font(Theme.F.hintPhrase)
                    Spacer()
                    if case .warmup(let n) = plan.next {
                        Text("\(n) cards").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                        Button("Start") { model.services?.startWarmup(plan.lang) }.buttonStyle(.borderedProminent)
                    } else {
                        Text("Nothing to review").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    }
                }
            }
        }
        .padding(24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }

    /// The "Suspended cards" list (WR-05) with a way back.
    @ViewBuilder private var suspended: some View {
        let cards = [Lang.de, .en].flatMap { model.history.suspendedCardList(lang: $0) }
        if !cards.isEmpty {
            SettingsCard(title: "Suspended cards") {
                ForEach(cards) { c in
                    HStack {
                        Text(c.front).font(Theme.F.hintPhrase).lineLimit(1)
                        Spacer()
                        Button("Practise again") { model.services?.setCardSuspended(c.id, false) }.buttonStyle(LingoButtonStyle())
                    }
                }
            }
        }
    }
}

/// Shown in a warm-up session once every card is reviewed (WR-04): counts, the next review date and a way to drop a noisy card (WR-05).
struct WarmupEndCard: View {
    let summary: WarmupSummary
    var onSuspend: (String, Bool) -> Void
    var suspended: Set<String>
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            HStack(spacing: Theme.S.s12) {
                Image(systemName: "checkmark.circle").font(.system(size: 18)).foregroundStyle(Theme.C.statusSuccess).accessibilityHidden(true)
                Text("Warm-up done").font(Theme.F.hintPhrase)
                Spacer()
                Text("\(summary.reviewed) cards reviewed").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
            HStack(spacing: Theme.S.s16) {
                count("Again", summary.again); count("Hard", summary.hard); count("Good", summary.good); count("Easy", summary.easy)
                Spacer()
                if let due = summary.nextDue {
                    Text("Next review: \(due.formatted(.dateTime.weekday(.wide).day().month()))").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
            ForEach(Array(summary.cards.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.card.front).font(Theme.F.hintTranslation).lineLimit(1)
                    Spacer()
                    let off = suspended.contains(item.card.id)
                    Button(off ? "Practise again" : "Don't practise this card") { onSuspend(item.card.id, !off) }.buttonStyle(LingoButtonStyle())
                        .font(Theme.F.meta)
                }
            }
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
    }

    private func count(_ title: LocalizedStringKey, _ n: Int) -> some View {
        VStack(spacing: 2) { Text("\(n)").font(Theme.F.panelTitle); Text(title).font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary) }
    }
}
