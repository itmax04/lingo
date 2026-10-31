import Foundation
import LingoCore

/// Rules of the `dialog` eval (evals/README.md, "Rules" table). Each returns true/false, or nil (does not apply to the case).
public enum DialogRules {
    public static let all = ["protocol_ok", "lang_discipline", "no_pronunciation", "one_question", "contains_correction",
                             "returns_to_practice", "length_by_level", "asks_repeat", "repeats_previous", "fix_recorded",
                             "heard_ok", "no_false_correction", "says", "hint"]

    /// Per-rule thresholds (evals/README.md). `no_pronunciation` — 100%.
    public static let thresholds: [String: Double] = [
        "protocol_ok": 0.95, "lang_discipline": 0.90, "no_pronunciation": 1.0, "one_question": 0.90,
        "contains_correction": 0.85, "returns_to_practice": 0.90, "length_by_level": 0.85,
    ]

    /// Words about pronunciation, sounds, accent and "softer/harder/clearer" (ru, de, en) — whole-word regular expressions (language data).
    /// Everyday idioms "sounds like", "klingt wie", "звучит как" and "акцентировать (внимание)" are not about pronunciation (false positives in run1, D-20).
    static let pronunciation: [String] = [
        "произнош", "произнес", "произнёс", "произноси", "выговор", "\\bакцент(а|у|ом|е|ы|ов)?\\b", "интонац", "ударени",
        "мягче", "твёрже", "тверже", "чётче", "четче", "\\bзвук(а|и|ов|ом)?\\b",
        "aussprache", "aussprech", "ausgesproch", "\\bakzent(e|s)?\\b", "betonung", "weicher", "härter", "deutlicher aus",
        "pronunciation", "pronounc", "\\baccents?\\b", "intonation", "softer", "harder sound", "your sound",
    ]

    /// Signs of a correction in the spoken text (for modes without "as we go").
    static let correctionMarkers: [String] = [
        "natürlicher", "besser wäre", "besser:", "richtig wäre", "richtig ist", "korrekt wäre", "man sagt", "statt",
        "more natural", "better:", "it's better to say", "you should say", "the correct", "instead of", "correct form",
        "правильно", "лучше сказать", "вместо",
    ]

    static let repeatAsks: [String] = [
        "noch einmal", "nochmal", "wiederhol", "sag das", "sagen sie das", "sagen sie:", "bitte sagen", "sag mal", "versuch", "probier",
        "again", "repeat", "say it", "try it", "try saying", "can you say", "say that", "please say", "say one", "say this",
        "повтори", "скажи",
    ]

    public struct Result: Codable, Sendable {
        public var rules: [String: Bool]
        public var pass: Bool
        public var violations: Int
        public var studyWords: Int
    }

    static func lower(_ s: String) -> String { s.lowercased().replacingOccurrences(of: "ё", with: "е") }

    static func words(_ s: String) -> [String] { WER.words(s) }

    public static func check(_ c: DialogCase, response: String) -> Result {
        let parsed = ReplyProtocol.parse(response, studyLang: c.studyLang)
        let segs = parsed.segments
        let says: [(Lang, String)] = segs.compactMap { if case .say(let l, let t) = $0 { return (l, t) }; return nil }
        let fixes: [Fix] = segs.compactMap { if case .fix(let f) = $0 { return f }; return nil }
        let heard: [String] = segs.compactMap { if case .heard(let h) = $0 { return h }; return nil }
        let hints = segs.contains { if case .hint = $0 { return true }; return false }
        let study = says.filter { $0.0 == c.studyLang }.map(\.1)
        let ru = says.filter { $0.0 == .ru }.map(\.1)
        let allSay = says.map(\.1).joined(separator: " ")
        let e = c.expect
        var r: [String: Bool] = [:]

        r["protocol_ok"] = parsed.violations == 0 && !says.isEmpty
        if e.russian == true {
            r["lang_discipline"] = !ru.isEmpty
        } else {
            r["lang_discipline"] = ru.isEmpty
        }
        let low = lower(allSay)
        r["no_pronunciation"] = !pronunciation.contains { low.range(of: lower($0), options: .regularExpression) != nil }
        if c.session.mode == .questions || e.one_question == true {
            let q = study.joined(separator: " ").filter { $0 == "?" }.count
            r["one_question"] = q <= 1
        }
        if let pats = e.contains_correction {
            let hay = (allSay + " " + fixes.map { "\($0.original) → \($0.corrected)" }.joined(separator: " "))
            r["contains_correction"] = pats.contains { hay.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
        }
        if e.no_inline_correction == true {
            let studyLow = lower(study.joined(separator: " "))
            let marked = correctionMarkers.contains { studyLow.contains(lower($0)) }
            r["contains_correction"] = !marked
        }
        if e.returns_to_practice == true {
            r["returns_to_practice"] = says.last?.0 == c.studyLang
        }
        let limit = e.max_words ?? PromptBuilder.wordLimit(level: c.session.level ?? "")
        let studyWords = words(study.joined(separator: " ")).count
        if e.russian != true { r["length_by_level"] = studyWords <= limit }
        if e.asks_repeat == true {
            r["asks_repeat"] = repeatAsks.contains { low.contains($0) }
        }
        if e.repeats_previous == true, let prev = c.history?.last(where: { $0.role == .assistant }) {
            let pw = Set(words(ReplyProtocol.parse(prev.text.contains("@say") ? prev.text : "@say \(c.studyLang.rawValue): \(prev.text)", studyLang: c.studyLang)
                .segments.compactMap(\.sayText).joined(separator: " ")))
            let rw = Set(words(allSay))
            r["repeats_previous"] = !pw.isEmpty && Double(pw.intersection(rw).count) / Double(pw.count) >= 0.6
        }
        if e.fix_recorded == true || e.min_fixes != nil {
            r["fix_recorded"] = fixes.count >= (e.min_fixes ?? 1)
        }
        if let pats = e.heard {
            r["heard_ok"] = heard.contains { h in pats.contains { h.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil } }
        }
        if let bad = e.not_corrected {
            let fx = lower(fixes.map(\.original).joined(separator: " "))
            r["no_false_correction"] = !bad.contains { fx.contains(lower($0)) }
        }
        if let pats = e.says {
            r["says"] = pats.contains { allSay.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil }
        }
        if e.hint == true { r["hint"] = hints }
        return Result(rules: r, pass: r.values.allSatisfy { $0 }, violations: parsed.violations, studyWords: studyWords)
    }
}
