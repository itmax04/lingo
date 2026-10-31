import AppKit
import LingoCore
import SwiftUI

/// Settings → "Voice" (R-44): voice and rate for en, de, ru; pause T; merge G; echo cancellation; recognition engine.
struct VoiceSettingsView: View {
    let services: AppServices
    @State var voice: VoiceSettings

    init(services: AppServices) {
        self.services = services
        _voice = State(initialValue: services.settings.voice)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                InterfaceSettingsView()
                SettingsCard(title: "Voices", subtitle: "By default — the best installed voice of the language (Premium → Enhanced → Default).") {
                    ForEach(Lang.allCases, id: \.self) { l in
                        let list = Voices.available(l)
                        HStack(spacing: Theme.S.s12) {
                            Text(l.nativeName).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).frame(width: 92, alignment: .leading)
                            Picker("", selection: Binding(get: { voice.voiceIDs[l] ?? "" }, set: { voice.voiceIDs[l] = $0.isEmpty ? nil : $0; save() })) {
                                Text(String(localized: "Best installed") + (list.first.map { " (\($0.name), \($0.qualityTitle))" } ?? "")).tag("")
                                ForEach(list) { v in Text("\(v.name) · \(v.language) · \(v.qualityTitle)").tag(v.id) }
                            }
                            .labelsHidden()
                            Button("▶") { services.playPhrase(Phrase(lang: l, text: sample(l), translation: "", source: .hint)) }
                                .accessibilityLabel("Play the voice")
                        }
                        if Voices.needsBetterVoice(l) {
                            Text("Only a basic-quality voice is installed for \(l.nativeName). For a better one: System Settings → Accessibility → Spoken Content → System voice → Manage Voices… → download Enhanced or Premium.")
                                .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    slider("Speech rate", value: $voice.pace, range: 0.6...1.4, step: 0.05, format: { String(format: "×%.2f", $0) })
                }
                SettingsCard(title: "End of utterance and merging", subtitle: "In continuous mode an utterance is sent after pause T. If a new utterance starts within G and the assistant has not started speaking, it is merged with the previous one (R-10, R-11).") {
                    slider("Pause T", value: $voice.turn.silence, range: TurnConfig.silenceRange, step: 0.1, format: { String(localized: "\(String(format: "%.1f", $0)) s") })
                    slider("Merge G", value: $voice.turn.mergeGap, range: TurnConfig.mergeRange, step: 0.1, format: { String(localized: "\(String(format: "%.1f", $0)) s") })
                }
                SettingsCard(title: "Audio and recognition") {
                    Toggle("Echo cancellation (voice processing) — barge-in without headphones", isOn: Binding(get: { voice.voiceProcessing }, set: { voice.voiceProcessing = $0; save() }))
                    Text("Recognition: whisper.cpp large-v3-turbo on this Mac (chosen by the P-04 measurements and the H-2 live check). Audio never leaves the Mac and is not saved.")
                        .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Button("Speech recognition check…") { STTCheckWindow.show(part: "part2") }
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }

    func sample(_ l: Lang) -> String {
        switch l {
        case .en: "Hi, I'm Alex. Nice to meet you."
        case .de: "Hallo, ich heiße Alex. Freut mich."
        case .ru: "Привет! Давай продолжим."
        }
    }

    func save() { let v = voice; services.updateSettings { $0.voice = v } }

    func slider(_ title: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) -> some View {
        HStack(spacing: Theme.S.s12) {
            Text(title).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).frame(width: 120, alignment: .leading)
            Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; save() }), in: range, step: step).frame(maxWidth: 260)
            Text(format(value.wrappedValue)).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary).monospacedDigit()
        }
    }
}

/// Settings → "Sync" (R-36…R-38).
struct SyncSettingsView: View {
    let services: AppServices
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Sync folder",
                             subtitle: "History is shared between devices through a folder in iCloud Drive: each device writes only its own journal. No paid developer features are needed. iCloud decides when changes appear on another device — sync is not instant.") {
                    Text(model.syncFolderPath ?? String(localized: "Not selected")).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                    Text(model.syncStatus).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    HStack(spacing: Theme.S.s12) {
                        Button(model.syncFolderPath == nil ? "Choose a folder…" : "Choose another…") { services.chooseSyncFolder() }
                        Button("Sync now") { services.syncNow() }.disabled(model.syncFolderPath == nil)
                        if model.syncFolderPath != nil { Button("Disconnect") { services.forgetSyncFolder() } }
                    }
                    Text("✓ — saved on this Mac, ✓✓ — written to the sync folder.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }
}

/// Settings → "Data" (R-44): journal path, ZIP export, deleting the local history.
struct DataSettingsView: View {
    let services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Local journal", subtitle: "The source of truth on this Mac is its event journal (append-only). Keys never get into the journal.") {
                    Text(services.store.ownDir.path).font(Theme.F.meta).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                    HStack(spacing: Theme.S.s12) {
                        Button("Show in Finder") { services.revealJournal() }
                        Button("Export to ZIP…") { services.exportHistory() }
                        Button("Restore from ZIP…") { services.restoreHistory() }
                        Button("Delete local history…", role: .destructive) { services.deleteLocalHistory() }
                    }
                }
                SettingsCard(title: "Voice loop metrics", subtitle: "Turn timing and memory (without utterance text) — for checking latency and resources.") {
                    Text(services.store.base.appendingPathComponent("metrics").path).font(Theme.F.meta).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }
}

/// Settings → "About me" (LINGO-08 PR-01): goals and interests for the learner profile, at most 300 characters each. They reach the
/// model in the next session (the profile is frozen per session).
struct ProfileSettingsView: View {
    let services: AppServices
    @State private var goals: String
    @State private var interests: String

    init(services: AppServices) {
        self.services = services
        _goals = State(initialValue: services.model.profile.goals)
        _interests = State(initialValue: services.model.profile.interests)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Learner profile",
                             subtitle: "Lingo uses this to choose topics and examples. Changes apply from the next conversation. At most 300 characters each.") {
                    editor("Goals", hint: "For example: speak confidently at work, prepare for the B1 exam", text: $goals)
                    editor("Interests", hint: "For example: hiking, cooking, jazz", text: $interests)
                    HStack {
                        Button("Save") { services.updateProfile(goals: goals, interests: interests) }
                            .buttonStyle(.borderedProminent)
                            .disabled(goals == services.model.profile.goals && interests == services.model.profile.interests)
                        Spacer()
                    }
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }

    private func editor(_ title: LocalizedStringKey, hint: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            Text(title).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
            ZStack(alignment: .topLeading) {
                TextEditor(text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(300)) }))
                    .font(Theme.F.rowTitle).frame(minHeight: 64)
                    .scrollContentBackground(.hidden).padding(Theme.S.s4)
                    .background(Theme.C.surfaceInput, in: RoundedRectangle(cornerRadius: Theme.R.button))
                    .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.button))
                if text.wrappedValue.isEmpty {
                    Text(hint).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textTertiary).padding(Theme.S.s8).allowsHitTesting(false)
                }
            }
            Text("\(text.wrappedValue.count) / 300").font(Theme.F.meta).foregroundStyle(Theme.C.textTertiary)
        }
    }
}
