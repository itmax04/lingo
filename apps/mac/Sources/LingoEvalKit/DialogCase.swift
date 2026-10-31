import Foundation
import LingoCore
import Yams

/// A case of the `dialog` eval (evals/README.md). Synthetic data only.
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
        /// Whether `@say ru` is required (an explicit request, R-17). nil → there must be no Russian.
        public var russian: Bool?
        public var contains_correction: [String]?
        /// A normal reply contains no corrections (mode without "as we go").
        public var no_inline_correction: Bool?
        public var asks_repeat: Bool?
        public var one_question: Bool?
        public var max_words: Int?
        public var returns_to_practice: Bool?
        /// Repeat of the assistant's last reply (R-14): shared word share ≥ 60%.
        public var repeats_previous: Bool?
        /// There must be at least one @fix line ("after" and "on request" modes).
        public var fix_recorded: Bool?
        public var min_fixes: Int?
        /// R-51: @heard matches one of the expressions.
        public var heard: [String]?
        /// Words that must not be "corrected" (a recognition error, R-51): they are absent from @fix.
        public var not_corrected: [String]?
        /// The reply contains one of the expressions (free check).
        public var says: [String]?
        /// There is a @hint (R-16).
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

    /// Messages for PromptBuilder.
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
