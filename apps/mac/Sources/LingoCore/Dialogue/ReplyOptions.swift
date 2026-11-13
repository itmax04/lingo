import Foundation

/// One answer the learner could give (LINGO-09 MR-50): a phrase in the study language and its Russian translation.
public struct ReplyOption: Sendable, Equatable, Hashable {
    public var lang: Lang
    public var text: String
    public var translation: String
    public init(lang: Lang, text: String, translation: String) { self.lang = lang; self.text = text; self.translation = translation }
}

/// Reply options (LINGO-09 MR-49, MR-50): the silent `@reply <lang>: <phrase> | <Russian>` lines of the last assistant message.
public enum ReplyOptions {
    /// More lines than this keep the first three (MR-50).
    public static let maxOptions = 3

    /// Whether a session offers the switch (MR-49): open ordinary and scenario sessions without a tone. Hidden, and without effect, in a tone
    /// session, a warm-up, an exam or Goethe training, and an ended session. (Trial and trial-test sessions, MR-39/MR-41, join this list with
    /// their activity kinds in X-2.)
    public static func isOffered(_ s: SessionSettings, ended: Bool = false) -> Bool {
        guard !ended, s.tone == nil else { return false }
        switch s.activity?.kind {
        case nil, .scenario?: return true
        case .warmup?, .exam?: return false
        }
    }

    /// The options of a raw reply, from the raw text like every silent tag. A line without the `|` separator or with an empty phrase is
    /// skipped; a missing language means the study language; at most `maxOptions` are kept.
    public static func parse(_ raw: String, studyLang: Lang) -> [ReplyOption] {
        var out: [ReplyOption] = []
        for line in ReplyProtocol.stripThinking(raw).split(whereSeparator: \.isNewline) {
            guard let t = ReplyProtocol.tagged(line), t.tag == "reply" else { continue }
            guard let bar = t.body.firstIndex(of: "|") else { continue }
            let text = t.body[..<bar].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            out.append(ReplyOption(lang: t.lang.flatMap(Lang.init(rawValue:)) ?? studyLang, text: text,
                                   translation: t.body[t.body.index(after: bar)...].trimmingCharacters(in: .whitespaces)))
            if out.count == maxOptions { break }
        }
        return out
    }
}
