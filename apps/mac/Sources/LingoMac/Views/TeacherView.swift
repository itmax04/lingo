import LingoCore
import SwiftUI

/// "Teacher" (LINGO-05 GR-07): the warm-up now; the other flows arrive in later steps and stay "Coming soon".
struct TeacherView: View {
    @Bindable var model: AppModel
    var body: some View {
        TimelineView(.everyMinute) { context in content(model.history.todaySummary(now: context.date).plans) }
    }

    private func content(_ plans: [LanguagePlan]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                BannerLine(model: model)
                Text("Teacher").font(Theme.F.title)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 16) {
                    warmupCard(plans)
                    scenariosCard
                    examCard(.goetheB1, title: "German B1 exam")
                    examCard(.ielts, title: "IELTS Speaking")
                    weeklyCard
                    memoryCard
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
                            .disabled(model.startingWarmup.contains(plan.lang)).accessibilityLabel(Text("Start warm-up") + Text(", ") + Text(languageTitle(plan.lang)))
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

    private var scenariosCard: some View {
        let done = ScenarioCatalog.all.filter { model.history.scenarioDone($0.id) }.count
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 24)).foregroundStyle(Theme.C.accentEnglish)
            Text("Scenarios").font(Theme.F.panelTitle)
            Text("Situations from life and work, with tasks to get done.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            HStack {
                Text("\(done) of \(ScenarioCatalog.all.count) done").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                Spacer()
                Button("Choose") { model.showScenarios = true }.buttonStyle(.borderedProminent)
            }
        }
        .padding(24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }

    /// GR-07: "What Lingo knows about me" opens as a sheet (GR-06).
    private var memoryCard: some View {
        let facts = model.history.memoryFacts.count
        return VStack(alignment: .leading, spacing: Theme.S.s12) {
            Image(systemName: "person.text.rectangle").font(.system(size: 24)).foregroundStyle(Theme.C.accentEnglish)
            Text("What Lingo knows about me").font(Theme.F.panelTitle)
            Text("Facts, goals and recurring mistakes that Lingo uses. Edit or delete them.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            HStack {
                Text(model.history.memoryOn ? "\(facts) facts" : "Memory is off").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                Spacer()
                Button("Open") { model.showMemory = true }.buttonStyle(.borderedProminent)
                    .accessibilityLabel(Text("Open") + Text(": ") + Text("What Lingo knows about me"))
            }
        }
        .padding(Theme.S.s24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }

    /// GR-07: the weekly report lives on the Progress screen; this card opens it.
    private var weeklyCard: some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            Image(systemName: "calendar").font(.system(size: 24)).foregroundStyle(Theme.C.accentGerman)
            Text("Weekly report").font(Theme.F.panelTitle)
            Text("Your last 7 days in numbers, with advice from Lingo.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            Button("Open") { model.section = .progress }.buttonStyle(.borderedProminent)
                .accessibilityLabel(Text("Open") + Text(": ") + Text("Weekly report"))
        }
        .padding(Theme.S.s24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }

    private func examCard(_ kind: ExamKind, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            Image(systemName: "graduationcap").font(Theme.F.title).foregroundStyle(Theme.accent(kind.lang))
            Text(title).font(Theme.F.panelTitle)
            Text("Speaking practice with timed parts and preparation.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            if kind == .goetheB1 {
                // LINGO-10 BR-33: the German exam opens its own screen (Training and Debriefs; the Mock follows in G-5b).
                Button("Open") { model.showGoethe = true }.buttonStyle(.borderedProminent)
                    .tint(Theme.accent(kind.lang))
                    .accessibilityLabel(Text("Open") + Text(": ") + Text(title))
            } else {
                Button("Start exam") { model.services?.startExam(kind) }.buttonStyle(.borderedProminent)
                    .disabled(model.startingExam || !model.online || model.readOnly)
                    .tint(Theme.accent(kind.lang))
                    .accessibilityLabel(Text("Start exam") + Text(": ") + Text(title))
            }
        }
        .padding(Theme.S.s24).frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
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
                            .accessibilityLabel(Text("Practise again") + Text(": \(c.front)"))
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
            // A long list scrolls instead of squeezing the conversation.
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(summary.cards.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Text(item.card.front).font(Theme.F.hintTranslation).lineLimit(1)
                            Spacer()
                            let off = suspended.contains(item.card.id)
                            Button(off ? "Practise again" : "Don't practise this card") { onSuspend(item.card.id, !off) }.buttonStyle(LingoButtonStyle())
                                .font(Theme.F.meta)
                                .accessibilityLabel(Text(off ? "Practise again" : "Don't practise this card") + Text(": \(item.card.front)"))
                        }
                    }
                }
            }
            .frame(maxHeight: 132)
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

/// Shows the end card of a warm-up once the engine says it is over (the card the model already set up after the time limit is still practised).
struct WarmupEndHost: View {
    @Bindable var model: AppModel
    let session: String
    @State private var finished = false
    var body: some View {
        Group {
            if finished, let sum = model.history.warmupSummary(session: session), sum.reviewed > 0 {
                WarmupEndCard(summary: sum, onSuspend: { model.services?.setCardSuspended($0, $1) }, suspended: model.history.suspendedCards)
            }
        }
        .task(id: "\(session)-\(model.history.eventCount)") { finished = await model.services?.engine.warmupFinished(session) ?? false }
    }
}

