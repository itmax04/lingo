import LingoCore
import SwiftUI

/// LINGO-10 BR-30, BR-31: the Goethe debrief as a card. Per Teil: points over the maximum, each criterion with its letter and sentence,
/// strengths and improvements. No overall total, pass or fail, level or band, and no pronunciation row. The points are computed by the app
/// from the model's letters (BR-28); a Teil without all its letters shows the text without points (BR-29).
struct GoetheDebriefCard: View {
    let card: GoetheDebrief.Card
    private let lang = Lang.de

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s16) {
            HStack(spacing: Theme.S.s8) {
                Label("Exam debrief", systemImage: "checkmark.circle").font(Theme.F.panelTitle)
                if card.incomplete {
                    Text("Incomplete").font(Theme.F.chip).foregroundStyle(Theme.C.textSecondary)
                        .padding(.horizontal, Theme.S.s12).frame(height: Theme.R.chipHeight)
                        .background(Theme.C.surfaceChip, in: Capsule())
                }
            }
            ForEach(card.teile, id: \.teil) { teil(card.structured ? $0 : $0.withoutDetails) }
            if !card.structured {
                Text(verbatim: card.text).font(Theme.F.bubble).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }
            Text("This is a practice estimate, not an official result. Lingo does not assess pronunciation.")
                .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.S.s16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.surfaceBubbleAssistant, in: RoundedRectangle(cornerRadius: Theme.R.bubble))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.bubble))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func teil(_ t: GoetheDebrief.CardTeil) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            switch t.status {
            case .scored(let r):
                heading(t, points: r.points)
                if r.zeroedByE {
                    Text("Task fulfilment is E, so this Teil scores 0 points.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                }
                details(r)
            case .unscored(let r):
                heading(t, points: nil)
                Text("Points are not shown for this part: the reply was incomplete.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
                details(r)
            case .notAssessed:
                heading(t, points: nil)
                Text("Not assessed: there was nothing to assess.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            case .unfinished:
                heading(t, points: nil)
                Text("Not finished: this part is not assessed.").font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            }
        }
        .padding(Theme.S.s12).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.bgWindow, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
    }

    private func heading(_ t: GoetheDebrief.CardTeil, points: Int?) -> some View {
        HStack {
            Text(verbatim: "Teil \(t.teil)").font(Theme.F.hintPhrase)
            if let points { Text(verbatim: "· \(points) / \(t.maximum)").font(Theme.F.hintPhrase).foregroundStyle(Theme.accent(lang)) }
        }
    }

    @ViewBuilder private func details(_ r: GoetheTeilResult) -> some View {
        ForEach(GoetheCriterion.criteria(teil: r.teil), id: \.self) { c in
            if let letter = r.letters[c] {
                HStack(alignment: .firstTextBaseline, spacing: Theme.S.s8) {
                    Text(verbatim: letter.rawValue).font(Theme.F.button).frame(width: Theme.S.s20, alignment: .center)
                        .foregroundStyle(Theme.accent(lang)).accessibilityLabel(Text(c.title) + Text(": ") + Text(verbatim: letter.rawValue))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
                        if let sentence = r.sentences[c], !sentence.isEmpty { Text(verbatim: sentence).font(Theme.F.subtitle).fixedSize(horizontal: false, vertical: true) }
                    }
                }
            }
        }
        if !r.strengths.isEmpty { list("Strengths", r.strengths, symbol: "plus.circle") }
        if !r.improvements.isEmpty { list("To improve", r.improvements, symbol: "arrow.right.circle") }
    }

    private func list(_ title: LocalizedStringKey, _ items: [String], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.S.s4) {
            Text(title).font(Theme.F.section).foregroundStyle(Theme.C.textSecondary)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: Theme.S.s8) {
                    Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(Theme.C.textSecondary).accessibilityHidden(true)
                    Text(verbatim: item).font(Theme.F.subtitle).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
            }
        }
    }
}

private extension GoetheDebrief.CardTeil {
    /// BR-29: when no `[T<n>]` header was found the whole stored text is shown unstructured, and each Teil keeps only its heading with points.
    var withoutDetails: GoetheDebrief.CardTeil {
        var copy = self
        switch status {
        case .scored(var r): r.letters = [:]; r.sentences = [:]; r.strengths = []; r.improvements = []; copy.status = .scored(r)
        case .unscored(var r): r.letters = [:]; r.sentences = [:]; r.strengths = []; r.improvements = []; copy.status = .unscored(r)
        default: break
        }
        return copy
    }
}
