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
        /// LINGO-08: the per-session switch (missing = on) and the "My words" focus.
        public var use_vocabulary: Bool?
        public var vocabulary_focus: Bool?
        /// LINGO-09 M-1b: the tone of the session (missing = no tone).
        public var tone: ToneSpec?

        public var settings: SessionSettings {
            SessionSettings(lang: lang, mode: mode, topic: topic ?? "", role: role ?? "", level: level ?? "",
                            customPrompt: custom_prompt ?? "", corrections: Set(corrections), starter: starter ?? .assistant,
                            useVocabulary: use_vocabulary, vocabularyFocus: vocabulary_focus,
                            tone: tone.map { Tone(harshness: $0.harshness, hostility: $0.hostility, profanity: $0.profanity ?? false) })
        }
    }

    public struct ToneSpec: Decodable, Sendable {
        public var harshness: Int
        public var hostility: Int
        public var profanity: Bool?
    }

    /// A target item (LINGO-08 PR-10): `status` new | practising | needs work, turned into statistics for the block.
    public struct VocabSpec: Decodable, Sendable {
        public var text: String
        public var translation: String?
        public var status: String?
    }

    public struct ProfileSpec: Decodable, Sendable {
        public struct Mistake: Decodable, Sendable { public var rule: String; public var example: String? }
        public var goals: String?
        public var interests: String?
        public var mistakes: [Mistake]?
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
        /// LINGO-08 PR-10: a target appears in the reply (VR-07b matching).
        public var uses_target: Bool?
        /// No request to repeat (the learner's last turn already repeated the corrected phrase).
        public var no_repeat_request: Bool?
        /// The opening has one question and none of the generic greetings (README).
        public var concrete_opening: Bool?
        /// No filler phrases (README).
        public var no_filler: Bool?
        /// LINGO-09 M-1b (MR-10, MR-15): without a valid @fix the reply's tutor speech holds no blame marker (measured before the filter).
        public var no_blame_without_fix: Bool?
        /// The reply carries an `@help` line (MR-12).
        public var has_help: Bool?
        /// Judge first (MR-10): the first @fix line comes before the first spoken line.
        public var judge_first: Bool?
    }

    public var id: String
    public var category: String
    public var session: SessionSpec
    public var summary: String?
    public var history: [Turn]?
    /// The learner's last utterance; missing = the transcript ends with `history` (empty: the assistant opens).
    public var user: String?
    public var vocabulary: [VocabSpec]?
    public var profile: ProfileSpec?
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
        if let u = user {
            out.append(ChatMessage(id: "u", session: id, role: .user, text: u, lang: user_lang ?? studyLang, createdAt: t.addingTimeInterval(10)))
        }
        return out
    }

    /// Targets in case order; the status becomes statistics (new 0/0, practising used 1, needs work mistakes 1).
    public func targets() -> [VocabItem] {
        (vocabulary ?? []).enumerated().map { i, v in
            let st = (v.status ?? "new").lowercased()
            return VocabItem(id: "v\(i)", lang: studyLang, text: v.text, translation: v.translation ?? "", createdAt: Date(timeIntervalSince1970: 0),
                             used: st == "practising" ? 1 : 0, mistakes: st == "needs work" ? 1 : 0)
        }
    }

    public func promptProfile() -> PromptProfile {
        guard let p = profile else { return PromptProfile() }
        return PromptProfile(goals: p.goals ?? "", interests: p.interests ?? "",
                             mistakes: (p.mistakes ?? []).map { .init(rule: $0.rule, example: $0.example ?? "") })
    }

    public func request() -> LLMRequest {
        PromptBuilder.dialogRequest(settings: session.settings, summary: summary ?? "", messages: messages(),
                                    command: command ?? user.flatMap { CommandDetector.detect($0)?.kind },
                                    profile: promptProfile(), vocabulary: targets())
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
