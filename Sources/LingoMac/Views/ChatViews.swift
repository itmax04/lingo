import LingoCore
import SwiftUI

/// Center column header (R-40): title, subtitle, source badge (R-32), gear.
struct ChatHeader: View {
    let title: String
    let subtitle: String
    let sourceLabel: String
    let online: Bool
    var memoryNote: String?
    var onSettings: () -> Void = {}
    var sourceMenu: AnyView?
    var settingsMenu: AnyView?

    var body: some View {
        HStack(spacing: Theme.S.s16) {
            VStack(alignment: .leading, spacing: Theme.S.s4) {
                Text(title)
                    .font(Theme.F.title)
                    .foregroundStyle(Theme.C.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Theme.F.subtitle)
                    .foregroundStyle(Theme.C.textSecondary)
                    .lineLimit(1)
                    .help(memoryNote ?? "")
            }
            Spacer(minLength: Theme.S.s16)
            if let m = sourceMenu { m } else { SourceChip(label: sourceLabel, ok: online) }
            if let g = settingsMenu { g } else {
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.C.textSecondary)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Session settings")
            }
        }
        .padding(.horizontal, Theme.S.s24)
        .frame(height: Theme.S.headerHeight)
        .overlay(alignment: .bottom) { ColumnDivider(vertical: false) }
    }
}

/// Source badge (DESIGN.md §5): status dot, text, chevron.
struct SourceChip: View {
    let label: String
    let ok: Bool

    var body: some View {
        HStack(spacing: Theme.S.s8) {
            Circle()
                .fill(ok ? Theme.C.statusSuccess : Theme.C.statusDanger)
                .frame(width: Theme.R.statusDot, height: Theme.R.statusDot)
            Text(label)
                .font(Theme.F.chip)
                .foregroundStyle(Theme.C.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.C.textSecondary)
        }
        .padding(.horizontal, Theme.S.s16)
        .frame(height: Theme.R.chipHeight)
        .background(Theme.C.surfaceChip, in: Capsule())
        .subtleStroke(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reply source: \(label)")
    }
}

/// A presentation-only diff. It never edits the journal's original transcript.
struct InlineCorrection {
    let before: String
    let wrong: String
    let right: String
    let after: String
    init?(text: String, fix: Fix) {
        guard let range = text.range(of: fix.original, options: .caseInsensitive), fix.original != fix.corrected else { return nil }
        let a = fix.original.split(separator: " ").map(String.init)
        let b = fix.corrected.split(separator: " ").map(String.init)
        var first = 0
        while first < min(a.count, b.count), a[first] == b[first] { first += 1 }
        var last = 0
        while last < min(a.count - first, b.count - first), a[a.count - last - 1] == b[b.count - last - 1] { last += 1 }
        let prefix = a.prefix(first).joined(separator: " ")
        let suffix = a.suffix(last).joined(separator: " ")
        before = String(text[..<range.lowerBound]) + prefix + (prefix.isEmpty ? "" : " ")
        wrong = a[first..<(a.count - last)].joined(separator: " ")
        right = b[first..<(b.count - last)].joined(separator: " ")
        after = (suffix.isEmpty ? "" : " ") + suffix + String(text[range.upperBound...])
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let maxWidth: CGFloat
    var correction: Fix?
    var studyLanguage: Lang?
    var speaking = false
    var fallbackCorrections: [Fix] = []
    var onTap: () -> Void = {}
    var onStar: (Phrase) -> Void = { _ in }
    @State private var showCorrection = false
    private var isUser: Bool { message.role == .user }
    var body: some View {
        HStack(alignment: .top, spacing: Theme.S.avatarGap) {
            if isUser { Spacer(minLength: 32) }
            else { LingoMark(color: Theme.accent(studyLanguage ?? message.lang), speaking: speaking).frame(width: 32, height: 32).padding(.top, 8) }
            MaxWidthLayout(max: maxWidth) {
                VStack(alignment: .leading, spacing: 12) {
                    if message.kind == .summary {
                        Label("Session recap", systemImage: "checkmark.circle").font(Theme.F.panelTitle)
                    } else if message.kind == .error {
                        Label("Models unavailable", systemImage: "exclamationmark.triangle").font(Theme.F.hintPhrase)
                            .foregroundStyle(Theme.C.statusDanger)
                    }
                    content
                    ForEach(Array(fallbackCorrections.enumerated()), id: \.offset) { _, fix in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(fix.original).strikethrough().foregroundStyle(Theme.C.statusDanger)
                            Text(fix.corrected).foregroundStyle(Theme.accent(studyLanguage ?? message.lang))
                            Text(fix.rule).foregroundStyle(Theme.C.textSecondary)
                        }.font(Theme.F.hintPhrase)
                    }
                    if message.interruptedAt != nil {
                        Label("Interrupted", systemImage: "pause.circle").font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
                    }
                    meta
                }
                .padding(16)
                .background(isUser ? Theme.accentSurface(studyLanguage ?? message.lang) : Theme.C.surfaceBubbleAssistant,
                            in: RoundedRectangle(cornerRadius: Theme.R.bubble))
                .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.bubble))
                .contentShape(RoundedRectangle(cornerRadius: Theme.R.bubble))
                .onTapGesture { if correction == nil || !isUser { onTap() } }
            }
            if !isUser { Spacer(minLength: 16) }
        }
    }
    @ViewBuilder private var content: some View {
        if isUser, let fix = correction, let diff = InlineCorrection(text: message.text, fix: fix) {
            Button { showCorrection = true } label: {
                (Text(diff.before).foregroundColor(Theme.C.textPrimary)
                 + Text(diff.wrong).strikethrough().foregroundColor(Theme.C.statusDanger)
                 + Text(diff.wrong.isEmpty || diff.right.isEmpty ? "" : " ")
                 + Text(diff.right).foregroundColor(Theme.accent(studyLanguage ?? message.lang)).bold()
                 + Text(diff.after).foregroundColor(Theme.C.textPrimary))
                .font(Theme.F.bubble).multilineTextAlignment(.leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Correction: \(fix.original) — correct: \(fix.corrected)")
            .popover(isPresented: $showCorrection) {
                CorrectionDetailView(fix: fix, onEdit: onTap) {
                    onStar(Phrase(lang: message.lang, text: fix.corrected, translation: fix.rule, source: .correction))
                    showCorrection = false
                }
            }
        } else if isUser || message.segments.isEmpty {
            Text(message.text).font(Theme.F.bubble).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(message.segments.enumerated()), id: \.offset) { index, segment in
                    if case .say = segment {
                        SegmentView(segment: segment, studyLang: message.lang,
                                    spokenLimit: remainingSpokenCharacters(before: index))
                    }
                }
            }
        }
    }
    private func remainingSpokenCharacters(before index: Int) -> Int? {
        guard let limit = message.interruptedAt else { return nil }
        let prior = message.segments.prefix(index).compactMap(\.sayText)
        return max(0, limit - prior.reduce(0) { $0 + $1.count + 1 })
    }
    private var meta: some View {
        HStack(spacing: 8) {
            if isUser {
                if let heard = message.heard { Text("understood as: \(heard)").lineLimit(2).textSelection(.enabled) }
                Spacer(minLength: 0)
                Text(message.lang.tag)
                Text(SessionDateFormat.time(message.createdAt))
                DeliveryTicks(synced: message.synced)
            } else {
                Text(SessionDateFormat.time(message.createdAt))
                if let source = message.source { Text(source).lineLimit(1) }
            }
        }.font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
    }
}

struct SegmentView: View {
    let segment: ReplySegment
    let studyLang: Lang
    var spokenLimit: Int?
    @ViewBuilder var body: some View {
        switch segment {
        case .say(let language, let text):
            let count = spokenLimit.map { min(text.count, $0) } ?? text.count
            (Text(String(text.prefix(count))).foregroundColor(Theme.C.textPrimary)
             + Text(String(text.dropFirst(count))).foregroundColor(Theme.C.textTertiary))
                .font(Theme.F.bubble).textSelection(.enabled)
                .padding(language == .ru ? 12 : 0)
                .background(language == .ru ? Theme.C.surfaceCard : .clear,
                            in: RoundedRectangle(cornerRadius: Theme.R.card))
        case .fix, .hint, .heard: EmptyView()
        }
    }
}

struct MessageList: View {
    let messages: [ChatMessage]
    var showInlineCorrections = true
    var isSpeaking = false
    var studyLanguage: Lang?
    var onTap: (ChatMessage) -> Void = { _ in }
    var onStar: (Phrase) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private func correction(for message: ChatMessage) -> Fix? {
        guard showInlineCorrections, message.role == .user,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return nil }
        for following in messages.dropFirst(index + 1) {
            if following.role == .user { break }
            for segment in following.segments {
                if case .fix(let fix) = segment, InlineCorrection(text: message.text, fix: fix) != nil { return fix }
            }
        }
        return nil
    }
    private func fallbackCorrections(for message: ChatMessage) -> [Fix] {
        guard message.role == .assistant,
              let index = messages.firstIndex(where: { $0.id == message.id }) else { return [] }
        let previous = messages.prefix(index).last(where: { $0.role == .user })
        return message.segments.compactMap { segment in
            guard case .fix(let fix) = segment else { return nil }
            if let previous, correction(for: previous) == fix { return nil }
            return fix
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.S.messageGap) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, maxWidth: max(160, geometry.size.width * Theme.S.bubbleMaxFraction),
                                          correction: correction(for: message),
                                          studyLanguage: studyLanguage,
                                          speaking: isSpeaking && message.id == messages.last?.id,
                                          fallbackCorrections: fallbackCorrections(for: message),
                                          onTap: { onTap(message) }, onStar: onStar).id(message.id)
                        }
                    }.padding(24)
                }
                .onChange(of: messages.last?.id) { _, id in
                    guard let id else { return }
                    if reduceMotion { proxy.scrollTo(id, anchor: .bottom) }
                    else { withAnimation(.easeInOut(duration: Theme.transitionSeconds)) { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
        }
    }
}

struct MaxWidthLayout: Layout {
    let max: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let view = subviews.first else { return .zero }
        let width = min(max, proposal.width ?? max, view.sizeThatFits(.unspecified).width)
        return view.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}


/// Shared by the actual popover and fixture-only component evidence.
struct CorrectionDetailView: View {
    let fix: Fix
    var onEdit: () -> Void = {}
    var onSave: () -> Void = {}
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Correction").font(Theme.F.panelTitle)
            Text(fix.original + " → " + fix.corrected).font(Theme.F.bubble)
            Text(fix.rule).font(Theme.F.subtitle).foregroundStyle(Theme.C.textSecondary)
            HStack {
                Button("Edit transcript", action: onEdit)
                Button("Save to vocabulary", action: onSave)
            }
        }.padding(24).frame(width: 360).background(Theme.C.bgWindow)
    }
}
