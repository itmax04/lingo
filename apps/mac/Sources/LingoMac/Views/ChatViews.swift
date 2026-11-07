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
    let replacementPrefix: String
    let replacementSuffix: String
    init?(text: String, fix: Fix) {
        guard fix.original != fix.corrected else { return nil }
        let words = try! NSRegularExpression(pattern: #"\S+"#)
        func ranges(_ value: String) -> [Range<String.Index>] {
            words.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .compactMap { Range($0.range, in: value) }
        }
        let originalRanges = ranges(fix.original)
        let correctedRanges = ranges(fix.corrected)
        guard !originalRanges.isEmpty else { return nil }
        let a = originalRanges.map { String(fix.original[$0]) }
        let b = correctedRanges.map { String(fix.corrected[$0]) }
        // Match language-model quotes despite casing or whitespace differences, but display the actual transcript slice.
        let pattern = a.map(NSRegularExpression.escapedPattern(for:)).joined(separator: #"\s+"#)
        guard let match = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        let matched = String(text[range])
        let actualRanges = ranges(matched)
        guard actualRanges.count == a.count else { return nil }
        var first = 0
        while first < min(a.count, b.count), a[first] == b[first] { first += 1 }
        var last = 0
        while last < min(a.count - first, b.count - first), a[a.count - last - 1] == b[b.count - last - 1] { last += 1 }
        let start = first < actualRanges.count ? actualRanges[first].lowerBound : matched.endIndex
        let end = first < a.count - last ? actualRanges[a.count - last - 1].upperBound : start
        before = String(text[..<range.lowerBound]) + String(matched[..<start])
        wrong = String(matched[start..<end])
        if first < b.count - last {
            right = String(fix.corrected[correctedRanges[first].lowerBound..<correctedRanges[b.count - last - 1].upperBound])
        } else { right = "" }
        after = String(matched[end...]) + String(text[range.upperBound...])
        // Inserting a missing word needs a separator only when adjacent source text has none.
        replacementPrefix = wrong.isEmpty && before.last.map({ !$0.isWhitespace }) == true && !right.isEmpty ? " " : ""
        replacementSuffix = wrong.isEmpty && after.first.map({ !$0.isWhitespace }) == true && !right.isEmpty ? " " : ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let maxWidth: CGFloat
    var correction: Fix?
    var studyLanguage: Lang?
    var speaking = false
    var fallbackCorrections: [Fix] = []
    /// The `summary` message of an exam is its debrief (XR-03), not a session recap.
    var isExamDebrief = false
    var onTap: () -> Void = {}
    var onStar: (Phrase) -> Void = { _ in }
    /// State of "Translate to Russian" for this message and its actions.
    var translation: MessageTranslation?
    var onTranslate: () -> Void = {}
    var onHideTranslation: () -> Void = {}
    var onCopy: (String) -> Void = { _ in }
    @State private var showCorrection = false
    private var isUser: Bool { message.role == .user }
    /// Messages in Russian need no translation into Russian; recaps and errors are not dialogue lines.
    private var canTranslate: Bool { message.kind == .normal && message.lang != .ru && !message.spokenText.isEmpty }
    var body: some View {
        HStack(alignment: .top, spacing: Theme.S.avatarGap) {
            if isUser { Spacer(minLength: 32) }
            else { LingoMark(color: Theme.accent(studyLanguage ?? message.lang), speaking: speaking).frame(width: 32, height: 32).padding(.top, 8) }
            MaxWidthLayout(max: maxWidth) {
                VStack(alignment: .leading, spacing: 12) {
                    if message.kind == .summary {
                        Label(isExamDebrief ? "Exam debrief" : "Session recap", systemImage: "checkmark.circle").font(Theme.F.panelTitle)
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
                    if canTranslate { translationRow }
                    meta
                }
                .padding(16)
                .background(isUser ? Theme.accentSurface(studyLanguage ?? message.lang) : Theme.C.surfaceBubbleAssistant,
                            in: RoundedRectangle(cornerRadius: Theme.R.bubble))
                .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.bubble))
                .contentShape(RoundedRectangle(cornerRadius: Theme.R.bubble))
                .onTapGesture(perform: onTap)
            }
            if !isUser { Spacer(minLength: 16) }
        }
    }
    @ViewBuilder private var content: some View {
        if isUser, let fix = correction, let diff = InlineCorrection(text: message.text, fix: fix) {
            VStack(alignment: .leading, spacing: Theme.S.s8) {
                (Text(diff.before).foregroundColor(Theme.C.textPrimary)
                 + Text(diff.wrong).strikethrough().foregroundColor(Theme.C.statusDanger)
                 + Text(diff.wrong.isEmpty || diff.right.isEmpty ? diff.replacementPrefix : " ")
                 + Text(diff.right).foregroundColor(Theme.accent(studyLanguage ?? message.lang)).bold()
                 + Text(diff.replacementSuffix + diff.after).foregroundColor(Theme.C.textPrimary))
                .font(Theme.F.bubble).multilineTextAlignment(.leading)
                Button { showCorrection = true } label: {
                    Label("Correction", systemImage: "text.badge.checkmark").font(Theme.F.meta)
                }
                .buttonStyle(LingoButtonStyle())
                .accessibilityLabel("Correction: \(fix.original) — correct: \(fix.corrected)")
                .popover(isPresented: $showCorrection) {
                    CorrectionDetailView(fix: fix, onEdit: { showCorrection = false; onTap() }) {
                        onStar(Phrase(lang: message.lang, text: fix.corrected, translation: fix.rule, source: .correction))
                        showCorrection = false
                    }
                }
            }
        } else if isUser || message.segments.isEmpty {
            Text(message.spokenText).font(Theme.F.bubble).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
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
    /// "Copy | Translate to Russian", and the translation card under it (the same flow as selecting text in a chat app).
    @ViewBuilder private var translationRow: some View {
        VStack(alignment: .leading, spacing: Theme.S.s8) {
            HStack(spacing: Theme.S.s12) {
                Button { onCopy(message.spokenText) } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(LingoButtonStyle())
                Divider().frame(height: 14)
                Button {
                    if translation == nil { onTranslate() } else if translation != .loading { onHideTranslation() }
                } label: {
                    Label(translation == nil ? "Translate to Russian" : "Hide translation", systemImage: "translate")
                }
                .buttonStyle(LingoButtonStyle())
                .disabled(translation == .loading)
                .accessibilityLabel(translation == nil ? "Translate to Russian" : "Hide translation")
                if translation == .loading { ProgressView().controlSize(.mini).accessibilityLabel("Translating…") }
            }
            .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            switch translation {
            case .done(let text):
                HStack(alignment: .top, spacing: Theme.S.s8) {
                    Image(systemName: "translate").foregroundStyle(Theme.C.textSecondary).accessibilityHidden(true)
                    Text(text).font(Theme.F.bubble).foregroundStyle(Theme.C.textPrimary).textSelection(.enabled)
                    Spacer(minLength: 0)
                    Button { onCopy(text) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(LingoButtonStyle()).accessibilityLabel("Copy translation")
                }
                .padding(12)
                .background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
            case .failed(let reason):
                Text("Translation unavailable: \(reason)").font(Theme.F.meta).foregroundStyle(Theme.C.statusDanger).lineLimit(3)
            default: EmptyView()
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
    var isExam = false
    var onTap: (ChatMessage) -> Void = { _ in }
    var onStar: (Phrase) -> Void = { _ in }
    var translations: [String: MessageTranslation] = [:]
    var onTranslate: (ChatMessage) -> Void = { _ in }
    var onHideTranslation: (String) -> Void = { _ in }
    var onCopy: (String) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var corrections = MessageCorrections()
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.S.messageGap) {
                        ForEach(messages) { message in
                            MessageBubble(message: message, maxWidth: max(160, geometry.size.width * Theme.S.bubbleMaxFraction),
                                          correction: corrections.inline[message.id],
                                          studyLanguage: studyLanguage,
                                          speaking: isSpeaking && message.id == messages.last?.id,
                                          fallbackCorrections: corrections.fallback[message.id] ?? [],
                                          isExamDebrief: isExam && message.kind == .summary,
                                          onTap: { onTap(message) }, onStar: onStar,
                                          translation: translations[message.id],
                                          onTranslate: { onTranslate(message) },
                                          onHideTranslation: { onHideTranslation(message.id) },
                                          onCopy: onCopy).id(message.id)
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
        .onChange(of: messages, initial: true) { _, value in
            corrections = MessageCorrections(messages: value, showInline: showInlineCorrections)
        }
        .onChange(of: showInlineCorrections) { _, value in
            corrections = MessageCorrections(messages: messages, showInline: value)
        }
    }
}

/// One pass per feed change; bubble rendering performs dictionary lookups only.
struct MessageCorrections {
    private(set) var inline: [String: Fix] = [:]
    private(set) var fallback: [String: [Fix]] = [:]
    init(messages: [ChatMessage] = [], showInline: Bool = true) {
        var user: ChatMessage?
        for message in messages {
            if message.role == .user { user = message; continue }
            for segment in message.segments {
                guard case .fix(let fix) = segment else { continue }
                if showInline, let user, user.session == message.session {
                    if inline[user.id] == fix { continue }
                    if inline[user.id] == nil, InlineCorrection(text: user.text, fix: fix) != nil {
                        inline[user.id] = fix
                        continue
                    }
                }
                fallback[message.id, default: []].append(fix)
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
