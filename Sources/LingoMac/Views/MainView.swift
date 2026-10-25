import LingoCore
import SwiftUI

/// Окно из трёх колонок (R-40): сайдбар | лента + голосовая панель + ввод | подсказки.
struct MainView: View {
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= Theme.S.hintsCollapseWidth
            HStack(spacing: 0) {
                SidebarView(model: model, onNewSession: { model.showNewSession = true })
                ColumnDivider()
                center
                if wide && model.hintsVisible {
                    ColumnDivider()
                    hints
                }
            }
            .overlay(alignment: .trailing) {
                // R-40: при ширине < 1280 подсказки выдвигаются поверх ленты.
                if !wide && model.hintsVisible {
                    HStack(spacing: 0) { ColumnDivider(); hints }
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
        .sheet(item: $model.editing) { m in
            EditMessageView(message: m, onSave: { t in model.editing = nil; model.services?.editMessage(m.id, text: t) },
                            onRegenerate: { t in
                                model.editing = nil
                                if t != m.text { model.services?.editMessage(m.id, text: t) }
                                model.services?.regenerate(userMessageID: m.id)
                            },
                            onCancel: { model.editing = nil })
        }
        .sheet(isPresented: $model.showNewSession) {
            NewSessionView(lang: model.langFilter, lastCorrections: model.services?.settings.lastCorrections ?? [],
                           onStart: { s, t in model.showNewSession = false; model.services?.createSession(s, title: t) },
                           onCancel: { model.showNewSession = false })
        }
    }

    private var hints: some View {
        HintsPanel(phrases: model.phrases, starred: model.starred, onClose: { model.hintsVisible = false })
    }

    private var center: some View {
        VStack(spacing: 0) {
            ChatHeader(title: model.selectedSession?.title ?? "Lingo",
                       subtitle: model.selectedSession?.settings.subtitle ?? "Создайте сессию: «Новая сессия»",
                       sourceLabel: model.sourceLabel, online: model.online, memoryNote: model.memoryNote)
            if let b = model.banner {
                Text(b).font(Theme.F.rowMeta).foregroundStyle(Theme.C.statusDanger).padding(Theme.S.s8)
                    .onTapGesture { model.banner = nil }
            }
            MessageList(messages: model.displayMessages, onTap: { m in model.services?.tapped(m) })
            VStack(spacing: Theme.S.s16) {
                VoicePanel(state: model.voiceState, levels: model.levels,
                           onMic: { model.services?.micTapped() }, onPause: { model.services?.pauseTapped() },
                           onEnd: { model.services?.endTapped() },
                           extraControls: AnyView(VoiceToggles(model: model)))
                    .disabled(!model.online || model.selectedSession == nil || model.readOnly)
                    .help(model.online ? "" : "Нет ключа или сети: ответы модели недоступны")
                InputBar(text: $model.draft, enabled: model.online && model.selectedSession != nil && !model.readOnly,
                         disabledReason: model.readOnly ? "Журнал новой версии — только чтение"
                            : (model.selectedSession == nil ? "Создайте сессию" : "Нет ключа или сети: ответы модели недоступны"),
                         onSend: { model.services?.sendText() })
            }
            .padding(.horizontal, Theme.S.columnPadding)
            .padding(.bottom, Theme.S.columnPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.C.bgWindow)
        .overlay(alignment: .topTrailing) {
            if !model.hintsVisible {
                Button { model.hintsVisible = true } label: {
                    Image(systemName: "book").font(.system(size: 18)).foregroundStyle(Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Показать подсказки")
                .padding(Theme.S.s8)
            }
        }
    }
}

/// Переключатели голосовой панели (R-42): непрерывный режим, «Говорю по-русски» (R-09, ⌥R), «Медленный темп» (R-15).
struct VoiceToggles: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: Theme.S.s8) {
            toggle("Непрерывно", symbol: "infinity", on: model.continuous) { model.services?.toggleContinuous() }
            toggle("По-русски", symbol: "character.bubble", on: model.russianOnce) { model.services?.toggleRussian() }
            toggle("Медленно", symbol: "tortoise", on: model.slowPace) { model.services?.toggleSlowPace() }
        }
    }

    func toggle(_ title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.S.s4) {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? Theme.C.voiceAccent : Theme.C.textSecondary)
                    .frame(width: Theme.R.sendButton, height: Theme.R.sendButton)
                    .background(on ? Theme.C.voiceAccentSoft : Theme.C.surfaceControl, in: Circle())
                Text(title).font(Theme.F.caption).foregroundStyle(Theme.C.textPrimary).lineLimit(1).fixedSize()
            }
        }
        .buttonStyle(LingoButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
