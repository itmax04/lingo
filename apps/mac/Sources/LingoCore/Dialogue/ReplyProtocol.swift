import Foundation

/// The model reply protocol (R-24), line by line:
/// ```
/// @say de: Fast perfekt! Natürlicher wäre: „Ich heiße Alex. Freut mich.“
/// @fix: Mir gefällt in Rostock → Mir gefällt an Rostock | an + Ort
/// @hint de: Freut mich, Sie kennenzulernen. | Приятно познакомиться.
/// @heard: Mir gefällt an Rostock, dass es hier das Meer gibt   (R-51: how the user's utterance was understood)
/// ```
/// A line without a tag is `@say` in the target language. Parse errors never break the turn and are counted as the `protocol_violation` metric.
public enum ReplyProtocol {
    public struct Parsed: Sendable, Equatable {
        public var segments: [ReplySegment]
        public var violations: Int
    }

    public static func parse(_ text: String, studyLang: Lang) -> Parsed {
        var segs: [ReplySegment] = []
        var bad = 0
        for raw in stripThinking(text).split(whereSeparator: \.isNewline) {
            let (seg, violation) = parseLine(raw, studyLang: studyLang)
            if violation { bad += 1 }
            if let seg { segs.append(seg) }
        }
        return Parsed(segments: mergeAdjacentSay(segs), violations: bad)
    }

    /// Removes `<think>…</think>` reasoning blocks (some models send them in the text).
    public static func stripThinking(_ s: String) -> String {
        guard s.contains("<think>") else { return s }
        var out = s
        while let a = out.range(of: "<think>") {
            if let b = out.range(of: "</think>", range: a.upperBound..<out.endIndex) {
                out.removeSubrange(a.lowerBound..<b.upperBound)
            } else {
                out.removeSubrange(a.lowerBound..<out.endIndex)
            }
        }
        return out
    }

    /// Parses one line. `violation` — a line without a tag or with a wrong tag.
    public static func parseLine<S: StringProtocol>(_ raw: S, studyLang: Lang) -> (ReplySegment?, violation: Bool) {
        var line = Substring(raw).trimmingCharacters(in: .whitespaces)
        // Models sometimes format lines as a list or in bold: "- @say de: …", "**@say de:** …".
        while let f = line.first, "-*•>".contains(f) { line.removeFirst(); line = line.trimmingCharacters(in: .whitespaces) }
        line = line.replacingOccurrences(of: "**", with: "")
        guard !line.isEmpty else { return (nil, false) }
        guard line.hasPrefix("@") else { return (.say(studyLang, line), true) }
        guard let colon = line.firstIndex(of: ":") else { return (.say(studyLang, String(line.dropFirst())), true) }
        let head = line[line.index(after: line.startIndex)..<colon].lowercased().split(separator: " ")
        let body = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        let tag = head.first.map(String.init) ?? ""
        let lang = head.count > 1 ? Lang(rawValue: String(head[1])) : nil
        let langBad = head.count > 1 && lang == nil
        switch tag {
        case "say":
            guard !body.isEmpty else { return (nil, true) }
            return (.say(lang ?? studyLang, body), langBad)
        case "fix":
            guard let fix = parseFix(body) else { return (nil, true) }
            return (.fix(fix), false)
        case "heard":
            guard !body.isEmpty else { return (nil, true) }
            return (.heard(body), false)
        case "hint":
            let parts = body.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard let phrase = parts.first, !phrase.isEmpty else { return (nil, true) }
            return (.hint(Phrase(lang: lang ?? studyLang, text: phrase, translation: parts.count > 1 ? parts[1] : "", source: .hint)), langBad)
        default:
            return (.say(studyLang, body), true)
        }
    }

    /// "wrong → right | rule"; arrows "→", "->", "=>".
    static func parseFix(_ body: String) -> Fix? {
        let parts = body.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let pair = parts.first else { return nil }
        for arrow in ["→", "->", "=>"] {
            if let r = pair.range(of: arrow) {
                let a = pair[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                let b = pair[r.upperBound...].trimmingCharacters(in: .whitespaces)
                guard !a.isEmpty, !b.isEmpty else { return nil }
                return Fix(original: unquote(a), corrected: unquote(b), rule: parts.count > 1 ? parts[1] : "")
            }
        }
        return nil
    }

    static func unquote(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet(charactersIn: "\"'«»„“”‚‘’ "))
    }

    /// Adjacent `@say` lines of the same language are not merged: each line is a separate part for speech and display.
    static func mergeAdjacentSay(_ s: [ReplySegment]) -> [ReplySegment] { s }
}

/// Streaming parser: lines as they arrive and `@say` sentences ready to be spoken (R-13:
/// "speech starts with the first finished sentence").
public struct ReplyStreamParser: Sendable {
    public enum Item: Sendable, Equatable {
        /// A finished sentence of a `@say` line — ready to be spoken.
        case speak(Lang, String)
        /// A finished protocol line.
        case segment(ReplySegment)
    }

    public let studyLang: Lang
    private var line = ""
    /// How many characters of the current `@say` line body have already been sent to speech.
    private var spokenUpTo = 0
    private var inThink = false
    private var pending = ""
    public private(set) var text = ""
    public private(set) var violations = 0

    public init(studyLang: Lang) { self.studyLang = studyLang }

    public mutating func feed(_ chunk: String) -> [Item] {
        text += chunk
        var out: [Item] = []
        pending += chunk
        // Reasoning blocks are cut out before lines are parsed.
        while true {
            if inThink {
                guard let end = pending.range(of: "</think>") else { return out }
                pending.removeSubrange(pending.startIndex..<end.upperBound)
                inThink = false
            }
            if let start = pending.range(of: "<think>") {
                consume(String(pending[..<start.lowerBound]), into: &out)
                pending.removeSubrange(pending.startIndex..<start.upperBound)
                inThink = true
                continue
            }
            // A possible start of "<think>" at the end of a chunk — wait for the next chunk.
            if let lt = pending.lastIndex(of: "<"), "<think>".hasPrefix(pending[lt...]) {
                consume(String(pending[..<lt]), into: &out)
                pending = String(pending[lt...])
            } else {
                consume(pending, into: &out)
                pending = ""
            }
            return out
        }
    }

    public mutating func finish() -> [Item] {
        var out: [Item] = []
        if !inThink, !pending.isEmpty { consume(pending, into: &out) }
        pending = ""
        completeLine(into: &out)
        return out
    }

    private mutating func consume(_ s: String, into out: inout [Item]) {
        for ch in s {
            if ch == "\n" || ch == "\r" {
                completeLine(into: &out)
            } else {
                line.append(ch)
            }
        }
        emitSentences(into: &out)
    }

    /// Body of an unfinished `@say` line (or an untagged line) once its start is clear.
    private func sayBody() -> (Lang, String)? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        if !t.hasPrefix("@"), !t.hasPrefix("-"), !t.hasPrefix("*") { return (studyLang, line) }
        guard t.lowercased().hasPrefix("@say"), let colon = line.firstIndex(of: ":") else { return nil }
        let head = line[..<colon].lowercased().split(separator: " ")
        let lang = head.count > 1 ? Lang(rawValue: String(head[1])) ?? studyLang : studyLang
        return (lang, String(line[line.index(after: colon)...]))
    }

    private mutating func emitSentences(into out: inout [Item]) {
        guard let (lang, body) = sayBody() else { return }
        let chars = Array(body)
        var i = spokenUpTo
        var lastCut = spokenUpTo
        while i < chars.count - 1 {
            if ".!?…".contains(chars[i]) && chars[i + 1] == " " {
                let sentence = String(chars[lastCut...i]).trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty { out.append(.speak(lang, sentence)) }
                lastCut = i + 1
            }
            i += 1
        }
        spokenUpTo = lastCut
    }

    private mutating func completeLine(into out: inout [Item]) {
        defer { line = ""; spokenUpTo = 0 }
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let (seg, violation) = ReplyProtocol.parseLine(line, studyLang: studyLang)
        if violation { violations += 1 }
        guard let seg else { return }
        if case .say(let lang, _) = seg, let (_, body) = sayBody() {
            let rest = String(Array(body).dropFirst(spokenUpTo)).trimmingCharacters(in: .whitespaces)
            let cleaned = ReplyProtocol.parseLine("@say \(lang.rawValue): \(rest)", studyLang: studyLang).0?.sayText ?? rest
            if !cleaned.isEmpty { out.append(.speak(lang, cleaned)) }
        }
        out.append(.segment(seg))
    }
}
