import Foundation

/// Who is speaking.
public enum Role: String, Codable, Sendable, Hashable {
    case user, assistant
}

/// A `@fix` correction (R-20, R-24): "wrong → right | rule".
public struct Fix: Codable, Sendable, Hashable {
    public var original: String
    public var corrected: String
    public var rule: String

    public init(original: String, corrected: String, rule: String = "") {
        self.original = original
        self.corrected = corrected
        self.rule = rule
    }
}

/// A section of the "Hints" panel (R-27).
public enum PhraseSource: String, Codable, Sendable, Hashable, CaseIterable {
    case topic, correction, howToSay = "how_to_say", hint

    public var title: String {
        switch self {
        case .topic: String(localized: "Topic phrases")
        case .correction: String(localized: "Corrections")
        case .howToSay: String(localized: "How to say")
        case .hint: String(localized: "Hints")
        }
    }
}

/// A hint or vocabulary phrase: text in the target language plus a translation (R-27, R-28).
public struct Phrase: Codable, Sendable, Hashable, Identifiable {
    public var lang: Lang
    public var text: String
    public var translation: String
    public var source: PhraseSource

    /// Stable phrase key — for ★ and deduplication (R-28): language + normalized text.
    public var id: String { Phrase.key(lang: lang, text: text) }

    public init(lang: Lang, text: String, translation: String, source: PhraseSource) {
        self.lang = lang
        self.text = text
        self.translation = translation
        self.source = source
    }

    public static func key(lang: Lang, text: String) -> String {
        let norm = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?…,;:«»\"“”„' "))
        return "\(lang.rawValue):\(norm)"
    }
}

/// A segment of the assistant's reply per the R-24 protocol.
public enum ReplySegment: Codable, Sendable, Hashable {
    case say(Lang, String)
    case fix(Fix)
    case hint(Phrase)
    /// How the assistant understood the user's utterance given the context (R-24 `@heard`, R-51). Not spoken.
    case heard(String)

    public var sayText: String? {
        if case .say(_, let t) = self { return t }
        return nil
    }
}

/// A feed message (R-41). Built from journal events (R-35).
public struct ChatMessage: Sendable, Hashable, Identifiable {
    public var id: String
    public var session: String
    public var role: Role
    /// The user's text (including a `message.edited` change) or the assistant's raw reply.
    public var text: String
    /// Language of the user's utterance (R-08) or the target language of the reply.
    public var lang: Lang
    /// "Understood as" (R-51) — from the `@heard` of the reply to this utterance; filled in when the feed is built.
    public var heard: String?
    /// Parsed segments of the assistant's reply (R-24). Empty for the user.
    public var segments: [ReplySegment]
    public var createdAt: Date
    /// "provider · model" label (R-29).
    public var source: String?
    /// Position (in characters of the `@say` text) where speech was interrupted (R-12). `nil` — not interrupted.
    public var interruptedAt: Int?
    /// Written to the sync folder (✓✓, R-38).
    public var synced: Bool
    /// Service message: a session recap (R-23) or a chain error message (S-18).
    public var kind: Kind

    public enum Kind: String, Codable, Sendable, Hashable {
        case normal, summary, error
    }

    public init(id: String, session: String, role: Role, text: String, lang: Lang, segments: [ReplySegment] = [],
                createdAt: Date, source: String? = nil, interruptedAt: Int? = nil, synced: Bool = false, kind: Kind = .normal) {
        self.id = id
        self.session = session
        self.role = role
        self.text = text
        self.lang = lang
        self.segments = segments
        self.createdAt = createdAt
        self.source = source
        self.interruptedAt = interruptedAt
        self.synced = synced
        self.kind = kind
    }

    /// Text for display and speech: `@say` lines joined with spaces; for the user — the text itself. A reply without segments falls back to
    /// its raw text without silent-tag lines (PX-01).
    public var spokenText: String {
        guard role == .assistant else { return text }
        guard !segments.isEmpty else { return ReplyProtocol.removingSilentLines(text) }
        return segments.compactMap(\.sayText).joined(separator: " ")
    }
}
