import AppKit
import LingoCore
import SwiftUI

/// Настройки → «Голос» (R-44): голос и темп для en, de, ru; пауза T; склейка G; эхоподавление; движок распознавания.
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
                SettingsCard(title: "Голоса", subtitle: "По умолчанию — лучший установленный голос языка (Premium → Enhanced → Default).") {
                    ForEach(Lang.allCases, id: \.self) { l in
                        let list = Voices.available(l)
                        HStack(spacing: Theme.S.s12) {
                            Text(l.nativeName).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).frame(width: 90, alignment: .leading)
                            Picker("", selection: Binding(get: { voice.voiceIDs[l] ?? "" }, set: { voice.voiceIDs[l] = $0.isEmpty ? nil : $0; save() })) {
                                Text("Лучший установленный" + (list.first.map { " (\($0.name), \($0.qualityTitle))" } ?? "")).tag("")
                                ForEach(list) { v in Text("\(v.name) · \(v.language) · \(v.qualityTitle)").tag(v.id) }
                            }
                            .labelsHidden()
                            Button("▶") { services.playPhrase(Phrase(lang: l, text: sample(l), translation: "", source: .hint)) }
                                .accessibilityLabel("Прослушать голос")
                        }
                        if Voices.needsBetterVoice(l) {
                            Text("Для \(l.nativeName) установлен только голос базового качества. Улучшенный: Системные настройки → Универсальный доступ → Устное содержимое → Системный голос → Управлять голосами… → скачать Enhanced или Premium.")
                                .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    slider("Темп речи", value: $voice.pace, range: 0.6...1.4, step: 0.05, format: { String(format: "×%.2f", $0) })
                }
                SettingsCard(title: "Конец реплики и склейка", subtitle: "В непрерывном режиме реплика отправляется после паузы T. Если новая реплика началась не позже G и помощник ещё не начал говорить, она склеивается с предыдущей (R-10, R-11).") {
                    slider("Пауза T", value: $voice.turn.silence, range: TurnConfig.silenceRange, step: 0.1, format: { String(format: "%.1f с", $0) })
                    slider("Склейка G", value: $voice.turn.mergeGap, range: TurnConfig.mergeRange, step: 0.1, format: { String(format: "%.1f с", $0) })
                }
                SettingsCard(title: "Звук и распознавание") {
                    Toggle("Эхоподавление (voice processing) — перебивание без наушников", isOn: Binding(get: { voice.voiceProcessing }, set: { voice.voiceProcessing = $0; save() }))
                    Text("Распознавание: whisper.cpp large-v3-turbo на этом Mac (выбрано по замерам P-04 и живой проверке H-2). Звук не покидает Mac и не сохраняется.")
                        .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
                    Button("Проверка распознавания…") { STTCheckWindow.show(part: "part2") }
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

    func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: @escaping (Double) -> String) -> some View {
        HStack(spacing: Theme.S.s12) {
            Text(title).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).frame(width: 120, alignment: .leading)
            Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; save() }), in: range, step: step).frame(maxWidth: 260)
            Text(format(value.wrappedValue)).font(Theme.F.rowTitle).foregroundStyle(Theme.C.textSecondary).monospacedDigit()
        }
    }
}

/// Настройки → «Синхронизация» (R-36…R-38).
struct SyncSettingsView: View {
    let services: AppServices
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Папка синхронизации",
                             subtitle: "История общая между устройствами через папку в iCloud Drive: каждое устройство пишет только свой журнал. Платные возможности разработчика не нужны. Срок появления на другом устройстве определяет iCloud — синхронизация не мгновенная.") {
                    Text(model.syncFolderPath ?? "Не выбрана").font(Theme.F.rowTitle).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                    Text(model.syncStatus).font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    HStack(spacing: Theme.S.s12) {
                        Button(model.syncFolderPath == nil ? "Выбрать папку…" : "Выбрать другую…") { services.chooseSyncFolder() }
                        Button("Синхронизировать сейчас") { services.syncNow() }.disabled(model.syncFolderPath == nil)
                        if model.syncFolderPath != nil { Button("Отключить") { services.forgetSyncFolder() } }
                    }
                    Text("✓ — сохранено на этом Mac, ✓✓ — записано в папку синхронизации.").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }
}

/// Настройки → «Данные» (R-44): путь к журналу, экспорт в ZIP, удаление локальной истории.
struct DataSettingsView: View {
    let services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.S.s24) {
                SettingsCard(title: "Локальный журнал", subtitle: "Источник истины на этом Mac — его журнал событий (только дописывание). Ключи в журнал не попадают.") {
                    Text(services.store.ownDir.path).font(Theme.F.meta).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                    HStack(spacing: Theme.S.s12) {
                        Button("Показать в Finder") { services.revealJournal() }
                        Button("Экспорт в ZIP…") { services.exportHistory() }
                        Button("Удалить локальную историю…", role: .destructive) { services.deleteLocalHistory() }
                    }
                }
                SettingsCard(title: "Метрики голосового цикла", subtitle: "Время хода и память (без текста реплик) — для проверки задержки и ресурсов.") {
                    Text(services.store.base.appendingPathComponent("metrics").path).font(Theme.F.meta).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                }
            }
            .padding(Theme.S.s24)
        }
        .background(Theme.C.bgWindow)
    }
}
