import Foundation
import LingoCore
import Yams

/// Кейс eval `dialog` (evals/README.md). Только синтетика.
public struct DialogCase: Decodable, Sendable {
    public struct SessionSpec: Decodable, Sendable {
        public var lang: Lang
        public var mode: SessionMode
        public var level: String?
        public var topic: String?
        public var role: String?
        public var corrections: [CorrectionMode]
        public var custom_prompt: String?
        public var starter: Starter?

        public var settings: SessionSettings {
            SessionSettings(lang: lang, mode: mode, topic: topic ?? "", role: role ?? "", level: level ?? "",
                            customPrompt: custom_prompt ?? "", corrections: Set(corrections), starter: starter ?? .assistant)
        }
    }

    public struct Turn: Decodable, Sendable {
        public var role: Role
        public var text: String
        public var lang: Lang?
    }

    public struct Expect: Decodable, Sendable {
        /// Нужен ли `@say ru` (явная просьба R-17). nil → русского быть не должно.
        public var russian: Bool?
        public var contains_correction: [String]?
        /// В обычном ответе нет исправлений (режим без «по ходу»).
        public var no_inline_correction: Bool?
        public var asks_repeat: Bool?
        public var one_question: Bool?
        public var max_words: Int?
        public var returns_to_practice: Bool?
        /// Повтор последнего ответа помощника (R-14): общая доля слов ≥ 60%.
        public var repeats_previous: Bool?
        /// Должна быть хотя бы одна строка @fix (режим «после» и «по запросу»).
        public var fix_recorded: Bool?
        public var min_fixes: Int?
        /// R-51: @heard совпадает с одним из выражений.
        public var heard: [String]?
        /// Слова, которые нельзя «исправлять» (ошибка распознавания, R-51): их нет в @fix.
        public var not_corrected: [String]?
        /// Ответ содержит одно из выражений (свободная проверка).
        public var says: [String]?
        /// Есть @hint (R-16).
        public var hint: Bool?
    }

    public var id: String
    public var category: String
    public var session: SessionSpec
    public var summary: String?
    public var history: [Turn]?
    public var user: String
    public var user_lang: Lang?
    public var command: CommandKind?
    public var expect: Expect

    public var studyLang: Lang { session.lang }

    /// Сообщения для PromptBuilder.
    public func messages() -> [ChatMessage] {
        var out: [ChatMessage] = []
        var t = Date(timeIntervalSince1970: 1_792_900_000)
        for (i, h) in (history ?? []).enumerated() {
            t = t.addingTimeInterval(10)
            if h.role == .assistant {
                let parsed = ReplyProtocol.parse(h.text.contains("@say") ? h.text : "@say \(studyLang.rawValue): \(h.text)", studyLang: studyLang)
                out.append(ChatMessage(id: "h\(i)", session: id, role: .assistant, text: h.text, lang: studyLang, segments: parsed.segments, createdAt: t))
            } else {
                out.append(ChatMessage(id: "h\(i)", session: id, role: .user, text: h.text, lang: h.lang ?? studyLang, createdAt: t))
            }
        }
        out.append(ChatMessage(id: "u", session: id, role: .user, text: user, lang: user_lang ?? studyLang, createdAt: t.addingTimeInterval(10)))
        return out
    }

    public func request() -> LLMRequest {
        PromptBuilder.dialogRequest(settings: session.settings, summary: summary ?? "", messages: messages(),
                                    command: command ?? CommandDetector.detect(user)?.kind)
    }

    public static func load(dir: URL) throws -> [DialogCase] {
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { ["yaml", "yml"].contains($0.pathExtension) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var all: [DialogCase] = []
        for f in files {
            do {
                all += try YAMLDecoder().decode([DialogCase].self, from: String(contentsOf: f, encoding: .utf8))
            } catch {
                throw NSError(domain: "dialog", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(f.lastPathComponent): \(error)"])
            }
        }
        return all
    }
}
