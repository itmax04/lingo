import LingoCore
import SwiftUI

/// "What Lingo knows about me" (LINGO-05 GR-06): the profile, the recurring mistakes and the memory facts, with edit, delete and the switch.
/// Opened from the Teacher card. A deleted fact is hidden from Lingo and from this screen; its text stays in the journal history.
struct MemoryScreen: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: String?
    @State private var draft = ""
    @State private var deleting: MemoryFact?

    var body: some View {
        let st = model.history
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            HStack {
                Text("What Lingo knows about me").font(Theme.F.panelTitle)
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.S.s16) {
                    switchCard(st.memoryOn)
                    factsCard(st)
                    profileCard(st.profile)
                    mistakesCard(st)
                    Text("A deleted fact is hidden from Lingo and from this screen. Its text stays in the journal history, the sync folder and backups until data deletion arrives with the account.")
                        .font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.S.s24)
        .foregroundStyle(Theme.C.textPrimary)
        .frame(minWidth: 640, idealWidth: 720, minHeight: 520, idealHeight: 680)
        .background(Theme.C.bgWindow)
        .confirmationDialog("Delete this fact?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { fact in
            Button("Delete", role: .destructive) { model.services?.removeMemory(fact.id) }
            Button("Cancel", role: .cancel) {}
        } message: { fact in
            Text(fact.text) + Text("\n") + Text("Lingo stops using it and it disappears from this screen.")
        }
    }

    private func switchCard(_ on: Bool) -> some View {
        SettingsCard(title: "Memory", subtitle: "Once per conversation Lingo may note a few short facts you mention, and uses the latest five as background. Turn off to stop both.") {
            Toggle("Remember facts about me", isOn: Binding(get: { on }, set: { model.services?.setMemory(on: $0) }))
                .toggleStyle(.switch).disabled(model.readOnly)
        }
    }

    private func profileCard(_ p: LearnerProfile) -> some View {
        SettingsCard(title: "Profile", subtitle: "Change goals and interests in Settings.") {
            labelled("Goals", p.goals)
            labelled("Interests", p.interests)
        }
    }

    private func labelled(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary)
            if value.isEmpty { Text("Not set").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary) }
            else { Text(value).font(Theme.F.rowTitle).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
        }
        .accessibilityElement(children: .combine)
    }

    private func mistakesCard(_ st: HistoryState) -> some View {
        let all = Lang.studied.map { ($0, st.recurringMistakes(lang: $0, before: Date().addingTimeInterval(1))) }
        return SettingsCard(title: "Recurring mistakes", subtitle: "Rules that came up at least twice in the last 30 days.") {
            if all.allSatisfy({ $0.1.isEmpty }) {
                Text("No recurring mistakes yet.").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary)
            }
            ForEach(all, id: \.0) { lang, list in
                ForEach(Array(list.enumerated()), id: \.offset) { _, m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageTitle(lang)).font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary)
                        Text(m.rule).font(Theme.F.rowTitle).textSelection(.enabled)
                        if !m.example.isEmpty { Text(m.example).font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary).textSelection(.enabled) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func factsCard(_ st: HistoryState) -> some View {
        SettingsCard(title: "Facts", subtitle: "Short sentences from your own words. Edit or delete any of them.") {
            if st.memoryFacts.isEmpty {
                Text(st.memoryOn ? "No facts yet. After a conversation with at least four of your messages Lingo may note a few here." : "Memory is off. No facts are noted or used.")
                    .font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(st.memoryFacts.reversed()) { fact in row(fact) }
        }
    }

    @ViewBuilder
    private func row(_ fact: MemoryFact) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.S.s12) {
            Text(fact.lang.map { $0 == .de ? "DE" : "EN" } ?? "—").font(Theme.F.caption).foregroundStyle(Theme.C.textSecondary)
                .frame(width: 28, alignment: .leading)
                .accessibilityLabel(fact.lang.map { Text(languageTitle($0)) } ?? Text("General"))
            if editing == fact.id {
                TextField("Fact", text: $draft).textFieldStyle(.roundedBorder).onSubmit { save(fact) }
                Button("Save") { save(fact) }.buttonStyle(.borderedProminent).tint(Theme.accent(model.langFilter))
                    .disabled(MemoryText.clean(draft).isEmpty)
                Button("Cancel") { editing = nil }
            } else {
                Text(fact.text).font(Theme.F.rowTitle).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Edit") { draft = fact.text; editing = fact.id }
                    .accessibilityLabel(Text("Edit") + Text(": ") + Text(fact.text))
                Button("Delete", role: .destructive) { deleting = fact }
                    .accessibilityLabel(Text("Delete") + Text(": ") + Text(fact.text))
            }
        }
        .disabled(model.readOnly)
    }

    private func save(_ fact: MemoryFact) {
        let clean = MemoryText.clean(draft)
        if !clean.isEmpty, clean != fact.text { model.services?.updateMemory(fact.id, clean) }
        editing = nil
    }
}
