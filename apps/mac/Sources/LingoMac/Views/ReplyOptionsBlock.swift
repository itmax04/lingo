import LingoCore
import SwiftUI

/// "Reply options" under the anchor message (LINGO-09 MR-51, MR-52, DESIGN.md §5): the first words of two or three answers, revealed one by one.
/// Nothing is sent automatically: the learner says an option or inserts it into the message field.
struct ReplyOptionsBlock: View {
    let options: [ReplyOption]
    let revealed: Set<Int>
    let starred: Set<String>
    var collapsed = false
    var refreshing = false
    var canRefresh = true
    var error: String?
    var canPlay = true
    var canInsert = true
    var lang: Lang = .en
    var onReveal: (Int) -> Void = { _ in }
    var onRevealAll: () -> Void = {}
    var onPlay: (ReplyOption) -> Void = { _ in }
    var onStar: (ReplyOption) -> Void = { _ in }
    var onInsert: (ReplyOption) -> Void = { _ in }
    var onRefresh: () -> Void = {}
    var onToggleCollapsed: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            header
            if !collapsed {
                if options.isEmpty {
                    Text("No options for this turn").font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
                } else {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, o in row(i, o) }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(Theme.F.rowMeta).foregroundStyle(Theme.C.statusDanger).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.S.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
        .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reply options")
    }

    var header: some View {
        HStack(spacing: Theme.S.s8) {
            Button(action: onToggleCollapsed) {
                HStack(spacing: Theme.S.s4) {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.system(size: 10, weight: .semibold))
                    Text("Reply options").font(Theme.F.section)
                }.foregroundStyle(Theme.C.textSecondary)
            }
            .buttonStyle(LingoButtonStyle())
            .accessibilityLabel(collapsed ? "Expand reply options" : "Collapse reply options")
            Spacer(minLength: 0)
            if !collapsed {
                if revealed.count < options.count {
                    Button("Show all", action: onRevealAll).font(Theme.F.caption).foregroundStyle(Theme.accent(lang)).buttonStyle(LingoButtonStyle())
                }
                Button(action: onRefresh) {
                    if refreshing { ProgressView().controlSize(.mini) }
                    else { Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.C.textPrimary) }
                }
                .buttonStyle(LingoButtonStyle()).disabled(!canRefresh)
                .accessibilityLabel("Refresh options")
            }
        }
    }

    @ViewBuilder func row(_ i: Int, _ o: ReplyOption) -> some View {
        if revealed.contains(i) {
            HStack(alignment: .center, spacing: Theme.S.s12) {
                VStack(alignment: .leading, spacing: Theme.S.s4) {
                    Text(o.text).font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    if !o.translation.isEmpty {
                        Text(o.translation).font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { onPlay(o) } label: {
                    Image(systemName: "speaker.wave.2").font(.system(size: 16)).foregroundStyle(Theme.C.textPrimary)
                }.buttonStyle(LingoButtonStyle()).disabled(!canPlay).accessibilityLabel("Play option \(i + 1)")
                let on = starred.contains(Phrase(lang: o.lang, text: o.text, translation: o.translation, source: .hint).id)
                Button { onStar(o) } label: {
                    Image(systemName: on ? "star.fill" : "star").font(.system(size: 14)).foregroundStyle(on ? Theme.accent(o.lang) : Theme.C.textPrimary)
                }.buttonStyle(LingoButtonStyle()).accessibilityLabel(on ? "Remove option \(i + 1) from vocabulary" : "Save option \(i + 1) to vocabulary")
                if canInsert {
                    Button("Insert") { onInsert(o) }.font(Theme.F.caption).foregroundStyle(Theme.accent(o.lang))
                        .buttonStyle(LingoButtonStyle()).accessibilityLabel("Insert option \(i + 1) into the message field")
                }
            }
            .padding(.horizontal, Theme.S.s12).padding(.vertical, Theme.S.s8)
            .background(Theme.C.surfaceControl, in: RoundedRectangle(cornerRadius: Theme.R.button))
        } else {
            Button { onReveal(i) } label: {
                HStack {
                    Text(ReplyOptions.firstWords(o.text)).font(Theme.F.hintPhrase).foregroundStyle(Theme.C.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "eye").font(.system(size: 12)).foregroundStyle(Theme.C.textSecondary)
                }
                .padding(.horizontal, Theme.S.s12).padding(.vertical, Theme.S.s8)
                .background(Theme.C.surfaceControl, in: RoundedRectangle(cornerRadius: Theme.R.button))
            }
            .buttonStyle(LingoButtonStyle())
            .accessibilityLabel("Option \(i + 1): \(ReplyOptions.firstWords(o.text))")
            .accessibilityHint("Shows the full answer and its translation")
        }
    }
}

/// The block bound to the app model.
struct ReplyOptionsBlockHost: View {
    @Bindable var model: AppModel

    var body: some View {
        if let anchor = model.replyAnchor {
            let state = model.replyBlocks[anchor.id] ?? AppModel.ReplyBlockState()
            let svc = model.services
            ReplyOptionsBlock(options: model.replyOptionList(for: anchor), revealed: state.revealed, starred: model.starred,
                              collapsed: model.replyCollapsed, refreshing: state.refreshing,
                              canRefresh: svc?.canRefreshReplies ?? false, error: state.error,
                              canPlay: ![.speaking, .recording, .thinking].contains(model.voiceState),
                              canInsert: model.disabledReason.isEmpty, lang: model.studyLanguage,
                              onReveal: { svc?.revealReply($0) }, onRevealAll: { svc?.revealAllReplies() },
                              onPlay: { svc?.playReply($0) }, onStar: { svc?.starReply($0) }, onInsert: { svc?.insertReply($0) },
                              onRefresh: { svc?.refreshReplies() }, onToggleCollapsed: { svc?.toggleReplyCollapsed() })
        }
    }
}
