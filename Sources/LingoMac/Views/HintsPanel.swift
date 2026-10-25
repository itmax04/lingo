import LingoCore
import SwiftUI

/// Правая колонка «Подсказки» (R-27, DESIGN.md §5).
struct HintsPanel: View {
    let phrases: [Phrase]
    let starred: Set<String>
    var onPlay: (Phrase) -> Void = { _ in }
    var onStar: (Phrase) -> Void = { _ in }
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.S.s12) {
                Button(action: onClose) {
                    Image(systemName: "book")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Свернуть подсказки")
                Text("Подсказки")
                    .font(Theme.F.panelTitle)
                    .foregroundStyle(Theme.C.textPrimary)
            }
            .padding(.top, Theme.S.s20)
            .padding(.bottom, Theme.S.s8)
            Text("Полезные фразы для этой темы")
                .font(Theme.F.section)
                .foregroundStyle(Theme.C.textSecondary)
                .padding(.bottom, Theme.S.s16)

            ScrollView {
                LazyVStack(spacing: Theme.S.cardGap) {
                    ForEach(phrases) { p in
                        HintCard(phrase: p, starred: starred.contains(p.id),
                                 onPlay: { onPlay(p) }, onStar: { onStar(p) })
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(.horizontal, Theme.S.columnPadding)
        .frame(width: Theme.S.hintsWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.C.bgHints)
    }
}

/// Карточка подсказки: фраза, перевод, ▶, ★ (R-27).
struct HintCard: View {
    let phrase: Phrase
    let starred: Bool
    var onPlay: () -> Void
    var onStar: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.S.s12) {
            VStack(alignment: .leading, spacing: Theme.S.s4) {
                Text(phrase.text)
                    .font(Theme.F.hintPhrase)
                    .foregroundStyle(Theme.C.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Text(phrase.translation)
                    .font(Theme.F.hintTranslation)
                    .foregroundStyle(Theme.C.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: Theme.S.s8) {
                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Прослушать")
                Button(action: onStar) {
                    Image(systemName: starred ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(starred ? Theme.C.accentPrimary : Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel(starred ? "Убрать из словаря" : "Сохранить в словарь")
            }
        }
        .padding(.horizontal, Theme.S.s16)
        .padding(.vertical, Theme.S.s12)
        .frame(minHeight: Theme.R.hintCardMinHeight)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}
