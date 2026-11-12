import LingoCore
import SwiftUI

/// A scenario title in the interface language (Russian or English): the same choice the views' `\.locale` follows
/// (`InterfaceAppearance`), so titles match the rest of the screen even before a restart.
func scenarioTitle(_ sc: Scenario) -> String {
    InterfacePreferences.localeIdentifier.hasPrefix("ru") ? sc.title_ru : sc.title_en
}

/// The scenario picker (LINGO-05 SR-01): the catalogue of a language with levels and done marks, and, on its own tab, the learner's own
/// scenarios of that language with an editor.
struct ScenarioPicker: View {
    @Bindable var model: AppModel
    @State private var lang: Lang
    @State private var mine: Bool
    /// The scenario being written or edited; nil shows the list.
    @State private var editing: CustomScenario?
    @State private var deleting: CustomScenario?
    init(model: AppModel) {
        self.model = model
        _lang = State(initialValue: model.langFilter == .en ? .en : .de)
        _mine = State(initialValue: model.scenarioTabMine)
    }

    var body: some View {
        Group {
            if let draft = editing {
                CustomScenarioEditor(draft: draft, onCancel: { editing = nil }, onSave: { c in
                    if model.services?.saveCustomScenario(c) == true { editing = nil }
                })
            } else {
                list
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 640, height: 620)
        .background(Theme.C.bgWindow)
        // A sheet does not get the main window's interface language; set it here like the other sheets.
        .modifier(InterfaceAppearance())
    }

    private var list: some View {
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
            Picker("Scenarios", selection: $mine) {
                Text("Ready-made").tag(false)
                Text("My scenarios").tag(true)
            }
            .pickerStyle(.segmented).labelsHidden()
            if mine {
                myList
            } else {
                ScrollView {
                    VStack(spacing: Theme.S.s12) {
                        ForEach(ScenarioCatalog.scenarios(lang: lang)) { sc in row(sc) }
                    }
                }
            }
            HStack {
                if mine {
                    Button { editing = CustomScenario(lang: lang, level: model.history.learnerLevel(lang: lang)) } label: {
                        Label("New scenario", systemImage: "plus")
                    }
                }
                Spacer()
                Button("Close") { model.showScenarios = false }.keyboardShortcut(.cancelAction)
            }
        }
        .confirmationDialog(Text("Delete the scenario?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            presenting: deleting) { c in
            Button("Delete", role: .destructive) { model.services?.deleteCustomScenario(c.id); deleting = nil }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: { c in
            Text("“\(c.title)” will be removed from the list. Conversations you already had with it stay.")
        }
    }

    @ViewBuilder private var myList: some View {
        let items = model.customScenarios.filter { $0.lang == lang }
        if items.isEmpty {
            VStack(alignment: .leading, spacing: Theme.S.s8) {
                Text("Describe a situation you want to practise").font(Theme.F.hintPhrase)
                Text("Who Lingo plays, what is going on and, if you like, what you want to get done. Lingo plays the scene in the study language and adapts to your answers. You can write the description in Russian.")
                    .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.S.s16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
            .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: Theme.S.s12) {
                    ForEach(items) { c in customRow(c) }
                }
            }
        }
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

    private func customRow(_ c: CustomScenario) -> some View {
        HStack(alignment: .top, spacing: Theme.S.s12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(c.title).font(Theme.F.hintPhrase)
                    Text(c.level).font(Theme.F.chip).foregroundStyle(Theme.accent(c.lang))
                    if !c.tasks.isEmpty {
                        Text("Goals: \(c.tasks.count)").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    }
                }
                Text(c.situation).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).lineLimit(2)
            }
            Spacer()
            Button { editing = c } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("Edit")
                .accessibilityLabel(Text("Edit") + Text(": \(c.title)"))
            Button { deleting = c } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("Delete")
                .accessibilityLabel(Text("Delete") + Text(": \(c.title)"))
            Button("Start") { model.showScenarios = false; model.services?.startCustomScenario(c) }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Text("Start") + Text(": \(c.title)"))
        }
        .padding(Theme.S.s12)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}

/// Writing or editing the learner's own scenario: title, level, Lingo's role, the situation and optional goals (one per line).
struct CustomScenarioEditor: View {
    @State private var draft: CustomScenario
    @State private var tasksText: String
    let isNew: Bool
    let onCancel: () -> Void
    let onSave: (CustomScenario) -> Void

    init(draft: CustomScenario, onCancel: @escaping () -> Void, onSave: @escaping (CustomScenario) -> Void) {
        _draft = State(initialValue: draft)
        _tasksText = State(initialValue: draft.tasks.joined(separator: "\n"))
        isNew = draft.title.isEmpty && draft.situation.isEmpty
        self.onCancel = onCancel
        self.onSave = onSave
    }

    /// The draft as it would be saved; goals beyond the fifth are dropped.
    private var result: CustomScenario {
        var c = draft
        c.tasks = tasksText.components(separatedBy: .newlines)
        return c.normalized
    }
    private var goalCount: Int {
        tasksText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            HStack {
                Text(isNew ? "New scenario" : "Edit scenario").font(Theme.F.title)
                Spacer()
                Text(draft.lang == .de ? "German" : "English").font(Theme.F.chip).foregroundStyle(Theme.accent(draft.lang))
            }
            Text("You can write in Russian: Lingo plays the scene in the study language and adapts to what you say.")
                .font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.S.s16) {
                    field("Title", count: draft.title, limit: CustomScenario.titleLimit) {
                        TextField("for example: Talking to my landlord", text: $draft.title).textFieldStyle(.roundedBorder)
                    }
                    field("Level") {
                        Picker("Level", selection: $draft.level) { ForEach(Scenario.levels, id: \.self) { Text($0).tag($0) } }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 220)
                    }
                    field("Who Lingo plays", count: draft.role, limit: Scenario.roleLimit) {
                        TextField("for example: my landlord, strict but fair", text: $draft.role).textFieldStyle(.roundedBorder)
                    }
                    field("Situation", count: draft.situation, limit: Scenario.situationLimit) {
                        editor($draft.situation, placeholder: "What is going on, where you are, what you need. For example: the heating in my flat has not worked for a week, and I want it repaired before the weekend.")
                    }
                    field("Your goals (optional)") {
                        VStack(alignment: .leading, spacing: Theme.S.s4) {
                            editor($tasksText, placeholder: "One goal per line, up to 5. For example:\nDescribe the problem\nAsk when the repair can happen")
                            goalsNote
                        }
                    }
                }
                .padding(.trailing, Theme.S.s8)
            }
            if !result.isValid {
                Text("Title, role and situation are required.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(result) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .disabled(!result.isValid)
            }
        }
    }

    @ViewBuilder private var goalsNote: some View {
        if goalCount > CustomScenario.maxTasks {
            Text("Only the first 5 goals are kept.").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
        } else if result.tasks.contains(where: { $0.count > Scenario.taskLimit }) {
            Text("A goal is longer than \(Scenario.taskLimit) characters; shorten it.").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
        } else {
            Text("With goals Lingo leads you through them and ticks them off; without goals the scene runs freely.")
                .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
        }
    }

    @ViewBuilder private func field<C: View>(_ title: LocalizedStringKey, count: String? = nil, limit: Int = 0,
                                             @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            HStack {
                Text(title).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
                Spacer()
                if let count {
                    let n = count.trimmingCharacters(in: .whitespacesAndNewlines).count
                    Text(verbatim: "\(n)/\(limit)").font(Theme.F.meta).monospacedDigit()
                        .foregroundStyle(n > limit ? Theme.C.statusDanger : Theme.C.textTertiary)
                        .accessibilityLabel(Text("\(n) of \(limit) characters"))
                }
            }
            content()
        }
    }

    private func editor(_ text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(Theme.F.rowTitle)
                .frame(minHeight: 96)
                .scrollContentBackground(.hidden)
                .padding(Theme.S.s4)
                .background(Theme.C.surfaceInput, in: RoundedRectangle(cornerRadius: Theme.R.button))
                .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
            if text.wrappedValue.isEmpty {
                Text(placeholder).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textTertiary)
                    .padding(Theme.S.s8).allowsHitTesting(false)
            }
        }
    }
}

/// The task checklist of a scenario session (SR-03), above the input.
struct ScenarioChecklist: View {
    let scenario: Scenario
    let recorded: [Int]
    /// Only numbers of this scenario's tasks count (another writer could have stored more).
    private var done: [Int] { recorded.filter { $0 >= 1 && $0 <= scenario.tasks.count } }
    init(scenario: Scenario, done: [Int]) { self.scenario = scenario; self.recorded = done }
    var body: some View {
        if scenario.tasks.isEmpty { EmptyView() } else { content }
    }
    private var content: some View {
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
