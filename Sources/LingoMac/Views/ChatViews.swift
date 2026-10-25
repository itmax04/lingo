import LingoCore
import SwiftUI

/// Шапка центральной колонки (R-40): название, подзаголовок, плашка источника (R-32), шестерёнка.
struct ChatHeader: View {
    let title: String
    let subtitle: String
    let sourceLabel: String
    let online: Bool
    var memoryNote: String?
    var onSettings: () -> Void = {}
    var sourceMenu: AnyView = AnyView(EmptyView())

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
            SourceChip(label: sourceLabel, ok: online)
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.C.textSecondary)
            }
            .buttonStyle(LingoButtonStyle())
            .accessibilityLabel("Настройки сессии")
        }
        .padding(.horizontal, Theme.S.s24)
        .frame(height: Theme.S.headerHeight)
        .overlay(alignment: .bottom) { ColumnDivider(vertical: false) }
    }
}

/// Плашка источника (DESIGN.md §5): точка статуса, текст, шеврон.
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
        .accessibilityLabel("Источник ответа: \(label)")
    }
}

/// Пузырь сообщения (R-41, DESIGN.md §5).
struct MessageBubble: View {
    let message: ChatMessage
    let maxWidth: CGFloat
    var onTap: () -> Void = {}

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.S.avatarGap) {
            if isUser { Spacer(minLength: 0) } else { Avatar(role: .bot) }
            MaxWidthLayout(max: maxWidth) { bubble }
                .contentShape(RoundedRectangle(cornerRadius: Theme.R.bubble))
                .onTapGesture(perform: onTap)
            if isUser { Avatar(role: .user) } else { Spacer(minLength: 0) }
        }
    }

    private var bubbleFill: Color { isUser ? Theme.C.bubbleUser : Theme.C.surfaceBubbleAssistant }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            content
            meta
        }
        .padding(.horizontal, Theme.S.bubblePaddingH)
        .padding(.vertical, Theme.S.bubblePaddingV)
        .background(bubbleFill, in: RoundedRectangle(cornerRadius: Theme.R.bubble))
    }

    @ViewBuilder private var content: some View {
        if isUser || message.segments.isEmpty {
            Text(message.text)
                .font(Theme.F.bubble)
                .foregroundStyle(Theme.C.textPrimary)
                .textSelection(.enabled)
        } else {
            VStack(alignment: .leading, spacing: Theme.S.s8) {
                ForEach(Array(message.segments.enumerated()), id: \.offset) { _, seg in
                    SegmentView(segment: seg, studyLang: message.lang)
                }
            }
        }
    }

    private var meta: some View {
        HStack(spacing: Theme.S.s8) {
            if isUser {
                if let h = message.heard {
                    // «Понято как» (R-51): мелко, в цвете метаданных, как время.
                    Text("понято как: \(h)").lineLimit(2).textSelection(.enabled)
                }
                Spacer(minLength: 0)
                Text(message.lang.tag)
                Text(SessionDateFormat.time(message.createdAt))
                DeliveryTicks(synced: message.synced)
            } else {
                Text(SessionDateFormat.time(message.createdAt))
                if let s = message.source { Text("· \(s)") }
            }
        }
        .font(Theme.F.meta)
        .foregroundStyle(isUser ? Theme.C.textMetaOnAccent : Theme.C.textSecondary)
    }
}

/// Сегмент ответа: `@say` (русский — на фоне `surface.card`), `@fix` (блок с обводкой).
struct SegmentView: View {
    let segment: ReplySegment
    let studyLang: Lang

    var body: some View {
        switch segment {
        case .say(let lang, let text):
            if lang == .ru {
                Text(text)
                    .font(Theme.F.bubble)
                    .foregroundStyle(Theme.C.textPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, Theme.S.s12)
                    .padding(.vertical, Theme.S.s8)
                    .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
            } else {
                Text(text)
                    .font(Theme.F.bubble)
                    .foregroundStyle(Theme.C.textPrimary)
                    .textSelection(.enabled)
            }
        case .fix(let fix):
            VStack(alignment: .leading, spacing: Theme.S.s4) {
                Text(fix.original).strikethrough().foregroundStyle(Theme.C.textSecondary)
                Text(fix.corrected).foregroundStyle(Theme.C.textPrimary)
                if !fix.rule.isEmpty {
                    Text(fix.rule).font(Theme.F.hintTranslation).foregroundStyle(Theme.C.textSecondary)
                }
            }
            .font(Theme.F.bubble)
            .padding(.horizontal, Theme.S.s12)
            .padding(.vertical, Theme.S.s8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Исправление: \(fix.original) — правильно: \(fix.corrected)")
        case .hint, .heard:
            EmptyView()
        }
    }
}

/// Лента сообщений (R-41).
struct MessageList: View {
    let messages: [ChatMessage]
    var onTap: (ChatMessage) -> Void = { _ in }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.S.messageGap) {
                        ForEach(messages) { m in
                            MessageBubble(message: m, maxWidth: geo.size.width * Theme.S.bubbleMaxFraction) { onTap(m) }
                                .id(m.id)
                        }
                    }
                    .padding(.horizontal, Theme.S.s24)
                    .padding(.vertical, Theme.S.columnPadding)
                }
                .onChange(of: messages.last?.id) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }
}

/// Пузырь по ширине содержимого, но не шире `max` (70% колонки, DESIGN.md §3).
struct MaxWidthLayout: Layout {
    let max: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let v = subviews.first else { return .zero }
        let w = min(max, proposal.width ?? max)
        let ideal = v.sizeThatFits(.unspecified)
        let width = min(ideal.width, w)
        return v.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}
