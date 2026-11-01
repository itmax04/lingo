import LingoCore
import SwiftUI

/// A scenario title in the interface language (Russian or English).
func scenarioTitle(_ sc: Scenario) -> String {
    InterfacePreferences.localeIdentifier.hasPrefix("ru") ? sc.title_ru : sc.title_en
}

/// The scenario picker (LINGO-05 SR-01): the catalogue of a language with levels and done marks.
struct ScenarioPicker: View {
    @Bindable var model: AppModel
    @State private var lang: Lang
    init(model: AppModel) { self.model = model; _lang = State(initialValue: model.langFilter) }
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            HStack {
                Text("Scenarios").font(Theme.F.title)
                Spacer()
                Picker("Language", selection: $lang) {
                    Text("German").tag(Lang.de)
                    Text("English").tag(Lang.en)
                }
                .pickerStyle(.segmented).frame(width: 220)
            }
            ScrollView {
                VStack(spacing: Theme.S.s12) {
                    ForEach(ScenarioCatalog.scenarios(lang: lang)) { sc in row(sc) }
                }
            }
            HStack { Spacer(); Button("Close") { model.showScenarios = false }.keyboardShortcut(.cancelAction) }
        }
        .padding(Theme.S.s24)
        .frame(width: 640, height: 620)
        .background(Theme.C.bgWindow)
    }

    private func row(_ sc: Scenario) -> some View {
        let done = model.history.scenarioDone(sc.id)
        return HStack(alignment: .top, spacing: Theme.S.s12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(scenarioTitle(sc)).font(Theme.F.hintPhrase)
                    Text(sc.level).font(Theme.F.chip).foregroundStyle(Theme.accent(sc.lang))
                    if done { Image(systemName: "checkmark.circle").foregroundStyle(Theme.C.statusSuccess).accessibilityLabel("Done") }
                }
                Text(sc.situation).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).lineLimit(2)
            }
            Spacer()
            Button("Start") { model.showScenarios = false; model.services?.startScenario(sc.id) }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text("Start") + Text(": \(scenarioTitle(sc))"))
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}

/// The task checklist of a scenario session (SR-03), above the input.
struct ScenarioChecklist: View {
    let scenario: Scenario
    let done: [Int]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(scenarioTitle(scenario)).font(Theme.F.hintPhrase)
                Spacer()
                Text("\(done.count) of \(scenario.tasks.count) done").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
            ForEach(Array(scenario.tasks.enumerated()), id: \.offset) { i, task in
                let ok = done.contains(i + 1)
                Label { Text(task).font(Theme.F.meta).foregroundStyle(ok ? Theme.C.textSecondary : Theme.C.textPrimary).strikethrough(ok) }
                    icon: { Image(systemName: ok ? "checkmark.circle.fill" : "circle").foregroundStyle(ok ? Theme.C.statusSuccess : Theme.C.textTertiary) }
                    .accessibilityLabel(Text(task) + Text(ok ? ", done" : ""))
            }
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}
