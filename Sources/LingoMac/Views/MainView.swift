import LingoCore
import SwiftUI

/// Окно из трёх колонок (R-40): сайдбар | лента + голосовая панель + ввод | подсказки.
struct MainView: View {
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= Theme.S.hintsCollapseWidth
            HStack(spacing: 0) {
                SidebarView(model: model)
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
    }

    private var hints: some View {
        HintsPanel(phrases: model.phrases, starred: model.starred, onClose: { model.hintsVisible = false })
    }

    private var center: some View {
        VStack(spacing: 0) {
            ChatHeader(title: model.selectedSession?.title ?? "Lingo",
                       subtitle: model.selectedSession?.settings.subtitle ?? "",
                       sourceLabel: model.sourceLabel, online: model.online)
            MessageList(messages: model.messages)
            VStack(spacing: Theme.S.s16) {
                VoicePanel(state: model.voiceState, levels: model.levels)
                InputBar(text: $model.draft, enabled: model.online,
                         disabledReason: "Нет сети: ответы модели недоступны")
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
