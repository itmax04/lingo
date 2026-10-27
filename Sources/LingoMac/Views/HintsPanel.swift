import LingoCore
import SwiftUI

/// Right column "Hints" (R-27, DESIGN.md §5): topic phrases, corrections, "how to say", vocabulary ★.
/// Each phrase has ▶ (voice of the phrase's language, works offline), a translation and ★.
struct HintsPanel: View {
    let phrases: [Phrase]
    let starred: Set<String>
    var corrections: [Phrase] = []
    var dictionary: [Phrase] = []
    var onPlay: (Phrase) -> Void = { _ in }
    var onStar: (Phrase) -> Void = { _ in }
    var onClose: () -> Void = {}
    @State private var collapsed: Set<String> = []

    var sections: [(String, String, [Phrase])] {
        let topic = phrases.filter { $0.source == .topic || $0.source == .hint }
        let how = phrases.filter { $0.source == .howToSay }
        return [("topic", String(localized: "Topic phrases"), topic), ("fix", String(localized: "Corrections"), uniq(corrections)), ("how", String(localized: "How to say"), how), ("dict", String(localized: "Vocabulary ★"), dictionary)].filter { !$0.2.isEmpty }
    }

    func uniq(_ p: [Phrase]) -> [Phrase] {
        var seen = Set<String>()
        return p.filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.S.s12) {
                Button(action: onClose) {
                    Image(systemName: "book")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Collapse hints")
                Text("Hints")
                    .font(Theme.F.panelTitle)
                    .foregroundStyle(Theme.C.textPrimary)
            }
            .padding(.top, Theme.S.s20)
            .padding(.bottom, Theme.S.s8)
            Text("Useful phrases for this topic")
                .font(Theme.F.section)
                .foregroundStyle(Theme.C.textSecondary)
                .padding(.bottom, Theme.S.s16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.S.cardGap) {
                    ForEach(sections, id: \.0) { key, title, list in
                        Group {
                            Button {
                                if collapsed.contains(key) { collapsed.remove(key) } else { collapsed.insert(key) }
                            } label: {
                                HStack(spacing: Theme.S.s4) {
                                    Image(systemName: collapsed.contains(key) ? "chevron.right" : "chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("\(title) · \(list.count)").font(Theme.F.section)
                                }
                                .foregroundStyle(Theme.C.textSecondary)
                            }
                            .buttonStyle(LingoButtonStyle())
                            .accessibilityLabel("\(title), \(list.count)")
                            if !collapsed.contains(key) {
                                ForEach(list) { p in
                                    HintCard(phrase: p, starred: starred.contains(p.id), onPlay: { onPlay(p) }, onStar: { onStar(p) })
                                }
                            }
                        }
                    }
                    if sections.allSatisfy({ $0.2.isEmpty }) {
                        Text("Phrases appear after the first turns of the conversation.")
                            .font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textTertiary)
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

/// Hint card: phrase, translation, ▶, ★ (R-27).
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
                .accessibilityLabel("Play")
                Button(action: onStar) {
                    Image(systemName: starred ? "star.fill" : "star")
                        .font(.system(size: 14))
                        .foregroundStyle(starred ? Theme.accent(phrase.lang) : Theme.C.textPrimary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel(starred ? "Remove from vocabulary" : "Save to vocabulary")
            }
        }
        .padding(.horizontal, Theme.S.s16)
        .padding(.vertical, Theme.S.s12)
        .frame(minHeight: Theme.R.hintCardMinHeight)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
    }
}
