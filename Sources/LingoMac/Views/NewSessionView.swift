import LingoCore
import SwiftUI

/// Экран настройки новой сессии (S-01, R-02, A-3, A-8). Значений «Thomas/A2» по умолчанию нет; пример промпта — только плейсхолдер.
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

    static let promptExample = "Например: «Ты мой новый сосед по дому. Мы встретились у почтовых ящиков. Говори просто, задавай по одному вопросу и начни первым.»"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            Text("Новая сессия").font(Theme.F.title).foregroundStyle(Theme.C.textPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.S.s16) {
                    field("Язык") { LanguageSegment(selection: $settings.lang).frame(width: Theme.S.sidebarWidth) }
                    field("Режим") {
                        Picker("", selection: $settings.mode) {
                            ForEach(SessionMode.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }
                    if settings.mode != .customPrompt {
                        field("Тема") { TextField("необязательно: знакомство, кафе, работа…", text: $settings.topic).textFieldStyle(.roundedBorder) }
                        field("Роль собеседника") { TextField("необязательно: сосед, официант, коллега…", text: $settings.role).textFieldStyle(.roundedBorder) }
                    } else {
                        field("Свой промпт") {
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
                                Text("Правила Lingo сильнее своего промпта: язык ответа, формат ответа и запрет оценки произношения не меняются (R-03).")
                                    .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                            }
                        }
                    }
                    field("Уровень") {
                        HStack(spacing: Theme.S.s8) {
                            Picker("", selection: $levelChoice) {
                                Text("не указан").tag("")
                                ForEach(Levels.cefr, id: \.self) { Text($0).tag($0) }
                                Text("свой текст").tag("custom")
                            }
                            .labelsHidden().frame(width: 140)
                            if levelChoice == "custom" {
                                TextField("например: средний, хочу больше разговорной речи", text: $customLevel).textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    field("Исправление ошибок") {
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
                                Text("Выберите хотя бы один режим").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger)
                            }
                        }
                    }
                    field("Кто начинает") {
                        Picker("", selection: $settings.starter) {
                            ForEach(Starter.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: Theme.S.sidebarWidth)
                    }
                    field("Название") { TextField(settings.defaultTitle, text: $title).textFieldStyle(.roundedBorder) }
                }
            }
            HStack {
                Spacer()
                Button("Отмена", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Начать") {
                    var s = settings
                    s.level = levelChoice == "custom" ? customLevel : levelChoice
                    onStart(s, title.isEmpty ? nil : title)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!startEnabled)
                .help(startEnabled ? "" : (settings.corrections.isEmpty ? "Выберите хотя бы один режим исправления" : "Напишите свой промпт"))
            }
        }
        .padding(Theme.S.s24)
        .frame(width: 620, height: 640)
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
    }

    var startEnabled: Bool {
        var s = settings
        s.level = levelChoice == "custom" ? customLevel : levelChoice
        return s.canStart
    }

    func note(_ c: CorrectionMode) -> String {
        switch c {
        case .inline: "Помощник сразу предлагает естественный вариант и просит повторить"
        case .after: "Ошибки копятся молча, итог по-русски — после «Завершить»"
        case .onDemand: "Разбор последних реплик, когда спросите «были ошибки?»"
        }
    }

    @ViewBuilder func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            Text(title).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
            content()
        }
    }
}
