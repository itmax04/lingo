import LingoCore
import SwiftUI

/// Settings → "Keys and models" (R-44): providers, an unlimited list of keys, "Check", chain order,
/// models from `GET /models`, first-token timeout. After saving, a key is shown only by its last 4 characters (R-48).
struct KeysSettingsView: View {
    @Bindable var keys: KeysController
    @State private var provider: ProviderID = .groq

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                Text("Keys are stored only in this Mac's Keychain. The model receives the text of utterances; audio never leaves the Mac.")
                    .font(Theme.F.section)
                    .foregroundStyle(Theme.C.textSecondary)
                Picker("Provider", selection: $provider) {
                    ForEach(ProviderID.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.frame(maxWidth: 320, alignment: .leading)
                ProviderKeysCard(keys: keys, provider: provider).id(provider)
                ChainCard(keys: keys)
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }
}

struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s12) {
            Text(title).font(Theme.F.panelTitle).foregroundStyle(Theme.C.textPrimary)
            if let subtitle {
                Text(subtitle).font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
        }
        .padding(Theme.S.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}

struct ProviderKeysCard: View {
    @Bindable var keys: KeysController
    let provider: ProviderID
    @State private var newKey = ""

    private var subtitle: LocalizedStringKey {
        switch provider {
        case .groq: "Main provider, free tier. Add as many keys as you like: on a limit the chain moves to the next one."
        case .mistral: "Fallback: the free Free plan without a card."
        case .openrouter: "Fallback: only free “:free” models."
        case .custom: "Any OpenAI-compatible endpoint: https://…/v1 (or http://localhost for your own server)."
        }
    }

    var body: some View {
        SettingsCard(title: LocalizedStringKey(provider.displayName), subtitle: subtitle) {
            if provider == .custom {
                TextField("https://example.org/v1", text: Binding(get: { keys.settings.customBaseURL },
                                                                  set: { v in keys.update { $0.customBaseURL = v } }))
                    .textFieldStyle(.roundedBorder)
                if !keys.settings.customBaseURL.isEmpty && keys.settings.customBase == nil {
                    Text("An https:// address is required (http — localhost only)").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
                }
            }
            let list = keys.settings.keys(for: provider)
            ForEach(Array(list.enumerated()), id: \.element.id) { i, k in
                HStack(spacing: Theme.S.s12) {
                    Circle().fill(k.invalid ? Theme.C.statusDanger : Theme.C.statusSuccess)
                        .frame(width: Theme.S.s8, height: Theme.S.s8)
                    Text("Key \(i + 1)  ••••\(k.last4)").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 0) {
                        if !k.label.isEmpty { Text(k.label).foregroundStyle(Theme.C.textSecondary) }
                        if k.invalid { Text(String(localized: "Invalid") + (k.invalidReason.map { " (\($0))" } ?? "")).foregroundStyle(Theme.C.statusDanger) }
                        if let c = keys.checks[k.id] { Text(c).foregroundStyle(Theme.C.textSecondary).lineLimit(2) }
                    }
                    .font(Theme.F.meta)
                    Spacer(minLength: 0)
                    TextField("Optional key label", text: Binding(get: { k.label }, set: { value in
                        keys.update { settings in
                            if let index = settings.keys.firstIndex(where: { $0.id == k.id }) { settings.keys[index].label = value }
                        }
                    })).frame(width: 120).textFieldStyle(.roundedBorder)
                    Button("Check") { keys.verify(k.id) }.disabled(keys.busy.contains(k.id))
                    Button("Delete", role: .destructive) { keys.delete(k.id) }
                }
            }
            HStack(spacing: Theme.S.s12) {
                SecureField(list.isEmpty ? "Paste a key" : "One more key", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add).disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if provider.keysPage != nil {
                    Button("Get a key…") { keys.openKeysPage(provider) }
                }
            }
            if let e = keys.addError[provider] {
                Text(e).font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
            }
            if let models = keys.settings.knownModels[provider], !models.isEmpty {
                Text(String(localized: "Models (GET /models): \(models.count)") + (keys.settings.knownModelsAt[provider].map { ", \(SessionDateFormat.rowDate($0))" } ?? ""))
                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            }
        }
    }

    private func add() {
        keys.addKey(provider, value: newKey)
        newKey = ""
    }
}

struct ChainCard: View {
    @Bindable var keys: KeysController
    @State private var newProvider: ProviderID = .groq
    @State private var newModel = ""

    var body: some View {
        SettingsCard(title: "Chain order",
                     subtitle: "Steps are tried top to bottom; each step uses all working keys of its provider in order. It moves on after a rate limit (429), a server or network error, a model refusal, or no first token within the timeout.") {
            ForEach(Array(keys.settings.chain.enumerated()), id: \.element.id) { i, e in
                HStack(spacing: Theme.S.s8) {
                    Toggle("", isOn: Binding(get: { e.enabled }, set: { keys.setEnabled(e.id, $0) })).labelsHidden()
                    Text("\(i + 1). \(e.provider.displayName)").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                        .frame(width: 120, alignment: .leading)
                    ModelField(model: e.model, options: keys.settings.knownModels[e.provider] ?? []) { keys.setModel(e.id, $0) }
                    let n = keys.settings.keys(for: e.provider).filter { !$0.invalid }.count
                    Text(n == 0 ? "no keys" : "keys: \(n)").font(Theme.F.meta)
                        .foregroundStyle(n == 0 ? Theme.C.statusDanger : Theme.C.textSecondary)
                        .frame(width: 80, alignment: .leading)
                    Button { keys.move(e.id, by: -1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0)
                        .accessibilityLabel("Move up")
                    Button { keys.move(e.id, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(i == keys.settings.chain.count - 1).accessibilityLabel("Move down")
                    Button { keys.removeStep(e.id) } label: { Image(systemName: "trash") }.accessibilityLabel("Delete step")
                }
            }
            HStack(spacing: Theme.S.s8) {
                Picker("", selection: $newProvider) {
                    ForEach(ProviderID.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .frame(width: 140)
                ModelField(model: newModel, options: keys.settings.knownModels[newProvider] ?? []) { newModel = $0 }
                Button("Add step") { keys.addStep(newProvider, model: newModel); newModel = "" }
                    .disabled(newModel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            HStack(spacing: Theme.S.s12) {
                Text("First-token timeout").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                Slider(value: Binding(get: { keys.settings.firstTokenTimeout }, set: { v in keys.update { $0.firstTokenTimeout = v.rounded() } }),
                       in: LLMSettings.timeoutRange, step: 1)
                    .frame(maxWidth: 240)
                Text("\(Int(keys.settings.firstTokenTimeout)) s").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary).monospacedDigit()
            }
        }
    }
}

/// Model field: pick from `GET /models` or type your own ID.
struct ModelField: View {
    let model: String
    let options: [String]
    let onChange: (String) -> Void
    @State private var text = ""

    var body: some View {
        HStack(spacing: Theme.S.s4) {
            TextField("Model ID", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onChange(text) }
                .onChange(of: text) { _, v in onChange(v) }
            if !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { m in Button(m) { text = m; onChange(m) } }
                } label: { Image(systemName: "list.bullet") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Choose a model from the list")
            }
            if !options.isEmpty && !model.isEmpty && !options.contains(model) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.C.statusDanger)
                    .help("This model is not in the GET /models list")
                    .accessibilityLabel("The model is not in the provider's list")
            }
        }
        .onAppear { text = model }
        .onChange(of: model) { _, v in if v != text { text = v } }
    }
}
