import Foundation

/// LINGO-09 MR-15: the blame filter. A tutor sentence that blames a mistake (a marker word) is spoken, shown and stored as a segment only
/// when the same reply carries an `@fix` that records a mistake. Without one, the sentence is removed; if nothing of the tutor's speech
/// remains, a neutral local line replaces it. The raw reply text is stored as always.
///
/// Tutor speech is: all `@say` lines (and untagged lines) when hostility = 0, the `@tutor` lines in a combined session, nothing when
/// harshness = 0. Russian lines (an explanation on request) are never filtered.
public enum BlameFilter {
    /// The marker lists, per study language. Whole words (lower case); a trailing `*` is a stem (`falsch*` = falsch, falsche, falschen),
    /// a leading `*` the last part of a German compound (`*fehler` = Fehler, Grammatikfehler, Tippfehler; not Fehlerfrei).
    /// A marker may hold several words (`nicht richtig`). `packages/contracts/fixtures/teacher/blame-markers.json` is written from here by the tests.
    public static let markers: [Lang: [String]] = [
        .de: ["falsch*", "*fehler", "*fehlern", "fehlerhaft*", "verkehrt", "inkorrekt", "unkorrekt", "unrichtig",
              "nicht richtig", "nicht korrekt", "stimmt nicht", "stimmt so nicht", "schon wieder"],
        .en: ["wrong", "mistake*", "incorrect*", "error*", "blunder*", "not right", "not correct", "isn't right", "isn't correct",
              "that's not how", "not how you say"],
    ]

    /// Whether the filter acts in a session with this tone: only the tutor's speech, so only with harshness ≥ 1 (MR-15).
    public static func applies(_ tone: Tone?) -> Bool { (tone?.harshness ?? 0) >= 1 }

    // MARK: Matching

    /// Lower-case words of a text: letters, digits and apostrophes (the typographic one is folded).
    static func words(_ s: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in s.lowercased().replacingOccurrences(of: "’", with: "'") {
            if ch.isLetter || ch.isNumber || ch == "'" { cur.append(ch) } else if !cur.isEmpty { out.append(cur); cur = "" }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    /// Whether a sentence holds a marker of the language.
    public static func hasBlame(_ sentence: String, lang: Lang) -> Bool {
        let w = words(sentence)
        guard !w.isEmpty else { return false }
        for m in markers[lang] ?? [] {
            let mw = words(m.replacingOccurrences(of: "*", with: ""))
            guard !mw.isEmpty else { continue }
            let stem = m.hasSuffix("*"), compound = m.hasPrefix("*")
            guard w.count >= mw.count else { continue }
            for i in 0...(w.count - mw.count) {
                var ok = true
                for (j, token) in mw.enumerated() {
                    let word = w[i + j]
                    let match = j == mw.count - 1 && stem ? word.hasPrefix(token)
                        : j == 0 && compound ? word.hasSuffix(token)
                        : word == token
                    if !match { ok = false; break }
                }
                if ok { return true }
            }
        }
        return false
    }

    /// Sentences of a line: a boundary is `.`, `!`, `?` or `…` followed by a space or the end (as the streaming parser cuts them).
    static func sentences(_ body: String) -> [String] {
        let chars = Array(body)
        var out: [String] = [], start = 0, i = 0
        while i < chars.count {
            if ".!?…".contains(chars[i]), i == chars.count - 1 || chars[i + 1] == " " {
                let s = String(chars[start...i]).trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { out.append(s) }
                start = i + 1
            }
            i += 1
        }
        if start < chars.count {
            let s = String(chars[start...]).trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { out.append(s) }
        }
        return out
    }

    // MARK: Filtering

    public struct Result: Equatable, Sendable {
        /// The reply text to parse into segments and to speak; equal to the input when nothing was removed.
        public var text: String
        /// Sentences removed (the replacement line is not counted).
        public var removed: Int
    }

    /// Whether the raw reply carries at least one `@fix` that the protocol parser reads as a mistake: the same test as the stream's
    /// gate (a `.fix` segment), so a line the parser does not take (no colon, in `<think>`) never backs blame.
    public static func hasFix(_ raw: String) -> Bool {
        ReplyProtocol.stripThinking(raw).components(separatedBy: "\n").contains { line in
            if case .fix? = ReplyProtocol.parseLine(line, studyLang: .en).0 { return true }
            return false
        }
    }

    static func isTutorLine(_ line: String, combined: Bool, lang: Lang) -> Bool {
        let t = ReplyProtocol.tagged(line)
        let lineLang = t?.lang.flatMap(Lang.init(rawValue:)) ?? lang
        return !line.trimmingCharacters(in: .whitespaces).isEmpty
            && (combined ? t?.tag == "tutor" : (t?.tag == nil || t?.tag == "say" || t?.tag == "tutor") && lineLang != .ru)
    }

    /// The text shown while the stream is still held (MR-15 "shown"): tutor speech is not shown until a fix releases it or the end decides.
    public static func heldPartial(raw: String, tone: Tone?, lang: Lang) -> String {
        guard applies(tone), let tone else { return raw }
        let combined = tone.hostility >= 1
        return raw.components(separatedBy: "\n").filter { !isTutorLine($0, combined: combined, lang: lang) }.joined(separator: "\n")
    }

    /// Filters the raw reply text. `replacement` is asked at most once, and only when nothing of the tutor's speech remains.
    public static func filter(raw: String, tone: Tone?, lang: Lang, replacement: () -> String) -> Result {
        guard applies(tone), let tone, !hasFix(raw) else { return Result(text: raw, removed: 0) }
        let combined = tone.hostility >= 1
        var removed = 0, tutorKept = 0, firstTutor: Int?
        var out: [String?] = []
        for (n, line) in ReplyProtocol.stripThinking(raw).components(separatedBy: "\n").enumerated() {
            let t = ReplyProtocol.tagged(line)
            let tag = t?.tag
            let lineLang = t?.lang.flatMap(Lang.init(rawValue:)) ?? lang
            let isTutor = isTutorLine(line, combined: combined, lang: lang)
            guard isTutor else { out.append(line); continue }
            if firstTutor == nil { firstTutor = n }
            let parts = sentences(t?.body ?? line.trimmingCharacters(in: .whitespaces))
            let kept = parts.filter { !hasBlame($0, lang: lineLang) }
            removed += parts.count - kept.count
            if !kept.isEmpty { tutorKept += 1 }
            if kept.count == parts.count { out.append(line) } else if kept.isEmpty { out.append(nil) } else {
                out.append("@\(tag ?? "say") \(lineLang.rawValue): " + kept.joined(separator: " "))
            }
        }
        guard removed > 0 else { return Result(text: raw, removed: 0) }
        // Nothing of the tutor's speech left: the neutral line takes the place of the first tutor line.
        if tutorKept == 0, let f = firstTutor { out[f] = "@\(combined ? "tutor" : "say") \(lang.rawValue): \(replacement())" }
        return Result(text: out.compactMap { $0 }.joined(separator: "\n"), removed: removed)
    }
}

/// The streaming side of the filter (MR-15): while a tone with harshness ≥ 1 is on, spoken sentences are held until the first `@fix`
/// segment (judge-first order, MR-10) or the end of the stream. A combined session holds the character's lines too, so the order of the
/// two voices never changes. With a fix, the held sentences are released at once; without one, the speech is rebuilt from the filtered
/// text, so what is spoken and what is stored as segments are the same by construction.
public struct BlameGate {
    private let tone: Tone?
    private let lang: Lang
    private var held: [(Lang, String)] = []
    private var released: Bool

    public init(tone: Tone?, lang: Lang) {
        self.tone = tone
        self.lang = lang
        released = !BlameFilter.applies(tone)
    }

    /// Whether sentences are being held (a tone with harshness ≥ 1 and no `@fix` yet).
    public var isHolding: Bool { !released }

    /// A parser item in; the sentences to speak now out.
    public mutating func offer(_ item: ReplyStreamParser.Item) -> [(Lang, String)] {
        switch item {
        case .speak(let l, let t):
            if released { return [(l, t)] }
            held.append((l, t))
            return []
        case .segment(let seg):
            guard case .fix = seg, !released else { return [] }
            released = true
            defer { held = [] }
            return held
        }
    }

    /// The end of the stream: the sentences still to speak (empty when a fix released them or the filter does not apply).
    public mutating func finish(raw: String, replacement: () -> String) -> [(Lang, String)] {
        guard !released else { return [] }
        released = true
        held = []
        let filtered = BlameFilter.filter(raw: raw, tone: tone, lang: lang, replacement: replacement)
        var p = ReplyStreamParser(studyLang: lang)
        var out: [(Lang, String)] = []
        for item in p.feed(filtered.text) + p.finish() { if case .speak(let l, let t) = item { out.append((l, t)) } }
        return out
    }
}
