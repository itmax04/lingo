import LingoCore
import SwiftUI

/// New session setup screen (S-01, R-02, A-3, A-8). No "Thomas/A2" defaults; the prompt example is only a placeholder.
struct NewSessionView: View {
    @State var settings: SessionSettings
    @State private var title = ""
    @State private var levelChoice = ""
    @State private var customLevel = ""
    let onStart: (SessionSettings, String?) -> Void
    let onCancel: () -> Void

    init(lang: Lang, lastCorrections: Set<CorrectionMode>, onStart: @escaping (SessionSettings, String?) -> Void, onCancel: @escaping () -> Void) {
        _settings = State(initialValue: SessionSettings(lang: lang, mode: .free, corrections: lastCorrections))
        self.onStart = onStart
        self.onCancel = onCancel
    }

    static let promptExample = String(localized: "For example: “You are my new neighbour. We met at the mailboxes. Speak simply, ask one question at a time and start first.”")

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            HStack(spacing: 12) {
                LingoMark().frame(width: 32, height: 32)
                Text("New session").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
                Spacer()
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], alignment: .leading, spacing: 20) {
                    field("Language") { LanguageSegment(selection: $settings.lang).frame(width: Theme.S.sidebarWidth) }
                    field("Mode") {
                        Picker("", selection: $settings.mode) {
                            ForEach(SessionMode.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }
                    if settings.mode != .customPrompt {
                        field("Topic") { TextField("optional: introductions, café, work…", text: $settings.topic).textFieldStyle(.roundedBorder) }
                        field("Partner's role") { TextField("optional: neighbour, waiter, colleague…", text: $settings.role).textFieldStyle(.roundedBorder) }
                    } else {
                        field("Custom prompt") {
                            VStack(alignment: .leading, spacing: Theme.S.s4) {
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $settings.customPrompt)
                                        .font(Theme.F.rowTitle)
                                        .frame(minHeight: 96)
                                        .scrollContentBackground(.hidden)
                                        .padding(Theme.S.s4)
                                        .background(Theme.C.surfaceInput, in: RoundedRectangle(cornerRadius: Theme.R.button))
                                        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
                                    if settings.customPrompt.isEmpty {
                                        Text(Self.promptExample).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textTertiary)
                                            .padding(Theme.S.s8).allowsHitTesting(false)
                                    }
                                }
                                Text("Lingo's rules take precedence over a custom prompt: the reply language, the reply format and the ban on rating pronunciation do not change (R-03).")
                                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                            }
                        }
                    }
                    field("Planned modes") {
                        HStack {
                            Label("Scenario", systemImage: "book").font(Theme.F.rowTitle)
                            Label("Exam", systemImage: "graduationcap").font(Theme.F.rowTitle)
                            Text("Coming soon").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                        }
                    }
                    field("Level") {
                        HStack(spacing: Theme.S.s8) {
                            Picker("", selection: $levelChoice) {
                                Text("not set").tag("")
                                ForEach(Levels.cefr, id: \.self) { Text($0).tag($0) }
                                Text("custom text").tag("custom")
                            }
                            .labelsHidden().frame(width: 140)
                            if levelChoice == "custom" {
                                TextField("for example: intermediate, I want more conversational speech", text: $customLevel).textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    field("Error correction") {
                        VStack(alignment: .leading, spacing: Theme.S.s4) {
                            ForEach(CorrectionMode.allCases, id: \.self) { c in
                                Toggle(isOn: Binding(get: { settings.corrections.contains(c) },
                                                     set: { on in if on { settings.corrections.insert(c) } else { settings.corrections.remove(c) } })) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(c.title).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                                        Text(note(c)).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                            if settings.corrections.isEmpty {
                                Text("Choose at least one mode").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
                            }
                        }
                    }
                    field("Who starts") {
                        Picker("", selection: $settings.starter) {
                            ForEach(Starter.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: Theme.S.sidebarWidth)
                    }
                    field("Title") { TextField(settings.defaultTitle, text: $title).textFieldStyle(.roundedBorder) }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction).controlSize(.large)
                Button("Start") {
                    var s = settings
                    s.level = levelChoice == "custom" ? customLevel : levelChoice
                    onStart(s, title.isEmpty ? nil : title)
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!startEnabled)
                .help(startEnabled ? "" : (settings.corrections.isEmpty ? "Choose at least one correction mode" : "Write your custom prompt"))
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 820, height: 680)
        .background(Theme.C.bgWindow)
        .modifier(InterfaceAppearance())
        .environment(\.studyLanguage, settings.lang)
    }

    var startEnabled: Bool {
        var s = settings
        s.level = levelChoice == "custom" ? customLevel : levelChoice
        return s.canStart
    }

    func note(_ c: CorrectionMode) -> String {
        switch c {
        case .inline: String(localized: "The assistant immediately offers a natural version and asks you to repeat it")
        case .after: String(localized: "Mistakes are collected silently; a recap in Russian comes after “Finish”")
        case .onDemand: String(localized: "A review of your last utterances when you ask “were there mistakes?”")
        }
    }

    @ViewBuilder func field<C: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            Text(title).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
            content()
        }
    }
}
