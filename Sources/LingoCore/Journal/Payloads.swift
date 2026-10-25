import Foundation

/// Полезная нагрузка событий (R-35). Все поля — синтетические или пользовательские тексты; ключи API сюда не попадают (R-48).
public enum Payload {
    public struct SessionCreated: Codable, Sendable, Hashable {
        public var title: String
        public var settings: SessionSettings
        public init(title: String, settings: SessionSettings) { self.title = title; self.settings = settings }
    }

    /// Изменение названия и/или настроек. `nil` — поле не меняется.
    public struct SessionUpdated: Codable, Sendable, Hashable {
        public var title: String?
        public var settings: SessionSettings?
        public init(title: String? = nil, settings: SessionSettings? = nil) { self.title = title; self.settings = settings }
    }

    public struct MessageCreated: Codable, Sendable, Hashable {
        public var role: Role
        public var text: String
        public var lang: Lang
        public var segments: [ReplySegment]?
        public var source: String?
        public var kind: ChatMessage.Kind?
        /// Сообщение пользователя, на которое это ответ, — для «Ответить заново» (R-09).
        public var replyTo: String?

        public init(role: Role, text: String, lang: Lang, segments: [ReplySegment]? = nil, source: String? = nil,
                    kind: ChatMessage.Kind? = nil, replyTo: String? = nil) {
            self.role = role
            self.text = text
            self.lang = lang
            self.segments = segments
            self.source = source
            self.kind = kind
            self.replyTo = replyTo
        }
    }

    public struct MessageEdited: Codable, Sendable, Hashable {
        public var message: String
        public var text: String
        public init(message: String, text: String) { self.message = message; self.text = text }
    }

    public struct MessageInterrupted: Codable, Sendable, Hashable {
        public var message: String
        public var at: Int
        public init(message: String, at: Int) { self.message = message; self.at = at }
    }

    public struct SummaryUpdated: Codable, Sendable, Hashable {
        public var text: String
        /// Последнее сообщение, которое учтено в кратком содержании (R-04).
        public var through: String?
        public init(text: String, through: String? = nil) { self.text = text; self.through = through }
    }

    public struct FixRecorded: Codable, Sendable, Hashable {
        public var message: String
        public var fix: Fix
        public init(message: String, fix: Fix) { self.message = message; self.fix = fix }
    }

    public struct HintAdded: Codable, Sendable, Hashable {
        public var phrase: Phrase
        public init(phrase: Phrase) { self.phrase = phrase }
    }

    public struct PhraseMark: Codable, Sendable, Hashable {
        public var phrase: Phrase
        public init(phrase: Phrase) { self.phrase = phrase }
    }
}
