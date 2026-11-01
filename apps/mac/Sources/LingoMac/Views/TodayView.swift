import LingoCore
import SwiftUI

func languageTitle(_ lang: Lang) -> LocalizedStringKey {
    switch lang {
    case .de: "German"
    case .en: "English"
    case .ru: "Russian"
    }
}

/// "Today" (LINGO-05 GR-03): the plan per language, the daily goal and the streak.
struct TodayView: View {
    @Bindable var model: AppModel
    var body: some View {
        // The clock ticks every minute: left open over midnight, the screen moves on to the new day.
        TimelineView(.everyMinute) { context in content(model.history.todaySummary(now: context.date)) }
    }

    private func content(_ t: TodaySummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                BannerLine(model: model)
                Text("Today").font(Theme.F.title)
                HStack(alignment: .top, spacing: 16) {
                    goalCard(t)
                    streakCard(t)
                }
                Text("Plan").font(Theme.F.panelTitle)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(t.plans) { plan in planCard(plan) }
                }
                Button("Continue conversation") { model.section = .conversations }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }.padding(32)
        }
        .foregroundStyle(Theme.C.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bgWindow)
    }

    private func goalCard(_ t: TodaySummary) -> some View {
        let fraction = min(1, Double(t.minutesToday) / Double(max(1, t.goalMinutes)))
        return SettingsCard(title: "Daily goal") {
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Theme.C.borderSubtle, lineWidth: 8)
                    Circle().trim(from: 0, to: fraction).stroke(t.goalReached ? Theme.C.statusSuccess : Theme.C.accentGerman,
                                                               style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("\(t.minutesToday)").font(Theme.F.title)
                }
                .frame(width: 88, height: 88)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(t.minutesToday) of \(t.goalMinutes) minutes today")
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(t.minutesToday) of \(t.goalMinutes) min today").font(Theme.F.hintPhrase)
                    Stepper(value: Binding(get: { t.goalMinutes }, set: { model.services?.setDailyGoal($0) }), in: HistoryState.goalRange, step: 5) {
                        Text("Goal: \(t.goalMinutes) min").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    }
                }
            }
        }
    }

    private func streakCard(_ t: TodaySummary) -> some View {
        SettingsCard(title: "Streak") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(t.streak) days in a row").font(Theme.F.panelTitle)
            }
            HStack(spacing: 8) {
                ForEach(Array(t.week.enumerated()), id: \.offset) { _, reached in
                    Circle().fill(reached ? Theme.C.statusSuccess : Theme.C.borderSubtle).frame(width: 12, height: 12)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(t.week.filter { $0 }.count) of the last 7 days reached the goal")
        }
    }

    private func planCard(_ plan: LanguagePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.lang.tag).font(Theme.F.chip).foregroundStyle(Theme.accent(plan.lang))
            Text(languageTitle(plan.lang)).font(Theme.F.panelTitle)
            switch plan.next {
            case .warmup(let n):
                Text("Warm-up").font(Theme.F.hintPhrase)
                HStack(spacing: 6) { Text("\(n) cards"); Text("·"); Text("about \(plan.warmupMinutes) min") }
                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                Button("Start warm-up") { model.services?.startWarmup(plan.lang) }.buttonStyle(.borderedProminent)
                    .disabled(model.startingWarmup.contains(plan.lang)).accessibilityLabel(Text("Start warm-up") + Text(", ") + Text(languageTitle(plan.lang)))
            case .scenario(let id):
                if let sc = ScenarioCatalog.scenario(id) {
                    Text("Scenario").font(Theme.F.hintPhrase)
                    Text("\(scenarioTitle(sc)) · \(sc.level)").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    Button("Start scenario") { model.services?.startScenario(id) }.buttonStyle(.borderedProminent)
                        .accessibilityLabel(Text("Start scenario") + Text(": \(scenarioTitle(sc))"))
                }
            case .freeConversation:
                Text("Nothing to review today. Free conversation?").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                Button("New session") { model.langFilter = plan.lang; model.section = .conversations; model.showNewSession = true }
                    .buttonStyle(.bordered).accessibilityLabel(Text("New session") + Text(", ") + Text(languageTitle(plan.lang)))
            }
        }
        .padding(20).frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}
