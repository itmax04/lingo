import Charts
import LingoCore
import SwiftUI

/// "Progress" (LINGO-05 GR-04, GR-05): practice minutes, words and mistakes per week, cards by state and totals, drawn from the journal,
/// and the weekly advice. Every number is computed on this Mac; the advice request carries numbers and examples only.
struct ProgressScreen: View {
    @Bindable var model: AppModel
    @State var range = 7

    var body: some View {
        TimelineView(.everyMinute) { context in
            content(model.history.progress(now: context.date), model.history.weekSummary(now: context.date),
                    model.history.weeklyReport(now: context.date))
        }
    }

    func content(_ p: ProgressData, _ week: WeekSummary, _ report: WeeklyReport?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                BannerLine(model: model)
                Text("Progress").font(Theme.F.title)
                if !p.hasData {
                    Text("No practice yet. Start a conversation or a warm-up and your progress appears here.")
                        .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                }
                totals(p)
                practiceCard(p)
                HStack(alignment: .top, spacing: Theme.S.s16) {
                    weeksCard("Learner words per week", p.weeks.map { ($0.start, Double($0.words)) }, Theme.C.accentGerman)
                    weeksCard("Mistakes per 100 words per week", p.weeks.compactMap { w in w.mistakesPer100.map { (w.start, $0) } }, Theme.C.accentEnglish)
                }
                cardsCard(p.cards)
                WeeklyReportCard(model: model, week: week, report: report)
            }.padding(Theme.S.s32)
        }
        .foregroundStyle(Theme.C.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bgWindow)
    }

    // MARK: pieces

    func totals(_ p: ProgressData) -> some View {
        HStack(spacing: Theme.S.s16) {
            stat(duration(p.totalMinutes), "Total practice")
            stat("\(p.totalWords)", "Learner words")
            stat("\(p.totalMistakes)", "Mistakes found")
            stat("\(p.vocabularyUsed)", "My words used")
        }
    }

    func duration(_ minutes: Int) -> String {
        minutes < 60 ? String(localized: "\(minutes) min") : String(localized: "\(minutes / 60) h \(minutes % 60) min")
    }

    func stat(_ value: String, _ caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(Theme.F.title)
            Text(caption).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
        }
        .padding(Theme.S.s16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .combine)
    }

    func practiceCard(_ p: ProgressData) -> some View {
        let days = Array(p.days.suffix(range))
        let total = days.reduce(0) { $0 + $1.minutes }
        return SettingsCard(title: "Practice time") {
            Picker("Period", selection: $range) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220)
            Chart(days) { d in
                BarMark(x: .value("Day", d.day, unit: .day), y: .value("Minutes", d.minutes))
                    .foregroundStyle(Theme.C.accentEnglish).cornerRadius(2)
            }
            .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
            .frame(height: 160)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Minutes per day"))
            .accessibilityValue(Text("Last \(range) days: \(total) min"))
            .accessibilityHint(Text(days.map { "\($0.minutes)" }.joined(separator: ", ")))
        }
    }

    func weeksCard(_ title: LocalizedStringKey, _ points: [(Date, Double)], _ color: Color) -> some View {
        SettingsCard(title: title) {
            if points.isEmpty {
                Text("No data yet").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).frame(maxWidth: .infinity, minHeight: 132)
            } else {
                Chart(Array(points.enumerated()), id: \.offset) { _, pt in
                    LineMark(x: .value("Week", pt.0, unit: .weekOfYear), y: .value("Value", pt.1)).foregroundStyle(color)
                    PointMark(x: .value("Week", pt.0, unit: .weekOfYear), y: .value("Value", pt.1)).foregroundStyle(color)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 132)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(title))
                .accessibilityValue(Text(points.map { String(format: "%.0f", $0.1) }.joined(separator: ", ")))
            }
        }
    }

    func cardsCard(_ c: CardCounts) -> some View {
        SettingsCard(title: "Cards") {
            HStack(spacing: Theme.S.s16) {
                stat("\(c.new)", "New"); stat("\(c.learning)", "Learning"); stat("\(c.mature)", "Mature"); stat("\(c.dueToday)", "Due today")
            }
        }
    }
}

/// The weekly advice (GR-05): the local numbers of the last 7 days, the stored advice of this ISO week, and the button.
struct WeeklyReportCard: View {
    @Bindable var model: AppModel
    let week: WeekSummary
    let report: WeeklyReport?

    var body: some View {
        SettingsCard(title: "Weekly report", subtitle: "Last 7 days. The advice is written from these numbers, not from your conversations.") {
            HStack(spacing: Theme.S.s16) {
                number("\(week.minutes)", "Minutes"); number("\(week.countedDays) / 7", "Goal days"); number("\(week.sessions)", "Sessions")
                number("\(week.learnerWords)", "Words"); number("\(week.mistakes)", "Mistakes"); number("\(week.cardsReviewed)", "Cards reviewed")
            }
            if !week.topMistakes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(week.topMistakes.enumerated()), id: \.offset) { _, g in
                        Text("\(g.original) → \(g.corrected)").font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary).textSelection(.enabled)
                    }
                }
            }
            if let report {
                Text(report.text).font(Theme.F.bubble).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.S.s12) {
                if model.weeklyRunning {
                    ProgressView().controlSize(.small).accessibilityHidden(true)
                    Text("Writing the advice…").font(Theme.F.meta)
                } else if model.weeklyFailed {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.C.statusDanger).accessibilityHidden(true)
                    Text("Advice not available. The models did not answer. Try again in a moment.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                } else if week.isEmpty {
                    Text("Practise a little this week to get advice.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
                Spacer(minLength: 0)
                Button(model.weeklyFailed ? "Retry" : (report == nil ? "Advice from Lingo" : "Update")) { model.services?.runWeeklyReport() }
                    .buttonStyle(.borderedProminent).tint(Theme.accent(model.langFilter))
                    .disabled(model.weeklyRunning || week.isEmpty || !model.online || model.readOnly)
            }
        }
    }

    func number(_ value: String, _ caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Theme.F.panelTitle)
            Text(caption).font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}
