import Foundation

/// Кто говорит.
public enum Role: String, Codable, Sendable, Hashable {
    case user, assistant
}

/// Исправление `@fix` (R-20, R-24): «было → правильно | правило».
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

/// Раздел панели «Подсказки» (R-27).
public enum PhraseSource: String, Codable, Sendable, Hashable, CaseIterable {
    case topic, correction, howToSay = "how_to_say", hint

    public var title: String {
        switch self {
        case .topic: "Фразы темы"
        case .correction: "Исправления"
        case .howToSay: "Как сказать"
        case .hint: "Подсказки"
        }
    }
}

/// Фраза подсказки или словаря: текст на изучаемом языке и перевод (R-27, R-28).
public struct Phrase: Codable, Sendable, Hashable, Identifiable {
    public var lang: Lang
    public var text: String
    public var translation: String
    public var source: PhraseSource

    /// Стабильный ключ фразы — для ★ и дедупликации (R-28): язык + нормализованный текст.
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

/// Сегмент ответа помощника по протоколу R-24.
public enum ReplySegment: Codable, Sendable, Hashable {
    case say(Lang, String)
    case fix(Fix)
    case hint(Phrase)

    public var sayText: String? {
        if case .say(_, let t) = self { return t }
        return nil
    }
}

/// Сообщение ленты (R-41). Строится из событий журнала (R-35).
public struct ChatMessage: Sendable, Hashable, Identifiable {
    public var id: String
    public var session: String
    public var role: Role
    /// Текст пользователя (с учётом правки `message.edited`) или сырой ответ помощника.
    public var text: String
    /// Язык реплики пользователя (R-08) или изучаемый язык ответа.
    public var lang: Lang
    /// Разобранные сегменты ответа помощника (R-24). Для пользователя пусто.
    public var segments: [ReplySegment]
    public var createdAt: Date
    /// Метка «провайдер · модель» (R-29).
    public var source: String?
    /// Позиция (в символах текста `@say`), где озвучка прервана (R-12). `nil` — не прерывалось.
    public var interruptedAt: Int?
    /// Записано в папку синхронизации (✓✓, R-38).
    public var synced: Bool
    /// Служебное: итог сессии (R-23) или сообщение об ошибке цепочки (S-18).
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

    /// Текст для показа и озвучивания: строки `@say` через пробел; для пользователя — сам текст.
    public var spokenText: String {
        guard role == .assistant, !segments.isEmpty else { return text }
        return segments.compactMap(\.sayText).joined(separator: " ")
    }
}
