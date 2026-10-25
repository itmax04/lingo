import LingoCore
import SwiftUI

/// Настройки → «Ключи и модели» (R-44): провайдеры, неограниченный список ключей, «Проверить», порядок цепочки,
/// модели из `GET /models`, таймаут первого токена. Ключ после сохранения показывается только последними 4 символами (R-48).
struct KeysSettingsView: View {
    @Bindable var keys: KeysController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                Text("Ключи хранятся только в Связке ключей этого Mac. В модель уходит текст реплик; аудио не покидает Mac.")
                    .font(Theme.F.section)
                    .foregroundStyle(Theme.C.textSecondary)
                ForEach(ProviderID.allCases, id: \.self) { p in
                    ProviderKeysCard(keys: keys, provider: p)
                }
                ChainCard(keys: keys)
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String?
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

    private var subtitle: String {
        switch provider {
        case .groq: "Основной провайдер, бесплатный тариф. Можно добавить сколько угодно ключей: при лимите цепочка перейдёт к следующему."
        case .mistral: "Запасной: бесплатный режим Free без карты."
        case .openrouter: "Запасной: только бесплатные модели «:free»."
        case .custom: "Любой OpenAI-совместимый адрес: https://…/v1 (или http://localhost для своего сервера)."
        }
    }

    var body: some View {
        SettingsCard(title: provider.displayName, subtitle: subtitle) {
            if provider == .custom {
                TextField("https://example.org/v1", text: Binding(get: { keys.settings.customBaseURL },
                                                                  set: { v in keys.update { $0.customBaseURL = v } }))
                    .textFieldStyle(.roundedBorder)
                if !keys.settings.customBaseURL.isEmpty && keys.settings.customBase == nil {
                    Text("Нужен адрес https:// (http — только localhost)").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
                }
            }
            let list = keys.settings.keys(for: provider)
            ForEach(Array(list.enumerated()), id: \.element.id) { i, k in
                HStack(spacing: Theme.S.s12) {
                    Circle().fill(k.invalid ? Theme.C.statusDanger : Theme.C.statusSuccess)
                        .frame(width: Theme.S.s8, height: Theme.S.s8)
                    Text("Ключ \(i + 1)  ••••\(k.last4)").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 0) {
                        if k.invalid { Text("Недействителен" + (k.invalidReason.map { " (\($0))" } ?? "")).foregroundStyle(Theme.C.statusDanger) }
                        if let c = keys.checks[k.id] { Text(c).foregroundStyle(Theme.C.textSecondary).lineLimit(2) }
                    }
                    .font(Theme.F.meta)
                    Spacer(minLength: 0)
                    Button("Проверить") { keys.verify(k.id) }.disabled(keys.busy.contains(k.id))
                    Button("Удалить", role: .destructive) { keys.delete(k.id) }
                }
            }
            HStack(spacing: Theme.S.s12) {
                SecureField(list.isEmpty ? "Вставьте ключ" : "Ещё один ключ", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Добавить", action: add).disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if provider.keysPage != nil {
                    Button("Получить ключ…") { keys.openKeysPage(provider) }
                }
            }
            if let e = keys.addError[provider] {
                Text(e).font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
            }
            if let models = keys.settings.knownModels[provider], !models.isEmpty {
                Text("Модели (GET /models): \(models.count)" + (keys.settings.knownModelsAt[provider].map { ", \(SessionDateFormat.rowDate($0))" } ?? ""))
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
        SettingsCard(title: "Порядок цепочки",
                     subtitle: "Шаги пробуются сверху вниз, у каждого шага — все действующие ключи провайдера по порядку. Переход дальше: лимит (429), ошибка сервера или сети, отказ модели, нет первого токена за таймаут.") {
            ForEach(Array(keys.settings.chain.enumerated()), id: \.element.id) { i, e in
                HStack(spacing: Theme.S.s8) {
                    Toggle("", isOn: Binding(get: { e.enabled }, set: { keys.setEnabled(e.id, $0) })).labelsHidden()
                    Text("\(i + 1). \(e.provider.displayName)").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                        .frame(width: 120, alignment: .leading)
                    ModelField(model: e.model, options: keys.settings.knownModels[e.provider] ?? []) { keys.setModel(e.id, $0) }
                    let n = keys.settings.keys(for: e.provider).filter { !$0.invalid }.count
                    Text(n == 0 ? "нет ключей" : "ключей: \(n)").font(Theme.F.meta)
                        .foregroundStyle(n == 0 ? Theme.C.statusDanger : Theme.C.textSecondary)
                        .frame(width: 80, alignment: .leading)
                    Button { keys.move(e.id, by: -1) } label: { Image(systemName: "chevron.up") }.disabled(i == 0)
                        .accessibilityLabel("Выше")
                    Button { keys.move(e.id, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(i == keys.settings.chain.count - 1).accessibilityLabel("Ниже")
                    Button { keys.removeStep(e.id) } label: { Image(systemName: "trash") }.accessibilityLabel("Удалить шаг")
                }
            }
            HStack(spacing: Theme.S.s8) {
                Picker("", selection: $newProvider) {
                    ForEach(ProviderID.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .frame(width: 140)
                ModelField(model: newModel, options: keys.settings.knownModels[newProvider] ?? []) { newModel = $0 }
                Button("Добавить шаг") { keys.addStep(newProvider, model: newModel); newModel = "" }
                    .disabled(newModel.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            HStack(spacing: Theme.S.s12) {
                Text("Таймаут первого токена").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary)
                Slider(value: Binding(get: { keys.settings.firstTokenTimeout }, set: { v in keys.update { $0.firstTokenTimeout = v.rounded() } }),
                       in: LLMSettings.timeoutRange, step: 1)
                    .frame(maxWidth: 240)
                Text("\(Int(keys.settings.firstTokenTimeout)) с").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary).monospacedDigit()
            }
        }
    }
}

/// Поле модели: выбор из `GET /models` или свой ID.
struct ModelField: View {
    let model: String
    let options: [String]
    let onChange: (String) -> Void
    @State private var text = ""

    var body: some View {
        HStack(spacing: Theme.S.s4) {
            TextField("ID модели", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onChange(text) }
                .onChange(of: text) { _, v in onChange(v) }
            if !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { m in Button(m) { text = m; onChange(m) } }
                } label: { Image(systemName: "list.bullet") }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel("Выбрать модель из списка")
            }
            if !options.isEmpty && !model.isEmpty && !options.contains(model) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.C.statusDanger)
                    .help("Этой модели нет в списке GET /models")
                    .accessibilityLabel("Модели нет в списке провайдера")
            }
        }
        .onAppear { text = model }
        .onChange(of: model) { _, v in if v != text { text = v } }
    }
}
