import Foundation

/// Text rules shared by duplicate checks, pasted lists and usage detection (VR-03, VR-07). Must match the TypeScript port
/// (golden cases in `packages/contracts/fixtures/vocab/`).
public enum VocabularyText {
    /// Lower case, punctuation removed (apostrophes dropped: "let's" → "lets"), whitespace collapsed; umlauts and ß kept.
    public static func normalize(_ s: String) -> String {
        var out = ""
        for ch in s.lowercased() {
            if ch == "'" || ch == "’" || ch == "`" { continue }
            if ch.isLetter || ch.isNumber { out.append(ch) } else { out.append(" ") }
        }
        return out.split(separator: " ").joined(separator: " ")
    }

    public static func tokens(_ s: String) -> [String] { normalize(s).split(separator: " ").map(String.init) }

    /// Duplicate key: language + normalised text.
    public static func key(lang: Lang, text: String) -> String { "\(lang.rawValue):\(normalize(text))" }

    public static let maxListLines = 200

    /// Result of parsing a pasted list (VR-03).
    public struct ParsedList: Sendable {
        public var entries: [(text: String, translation: String)] = []
        /// Lines whose text is longer than 120 characters, and lines beyond the 200-line limit.
        public var rejected = 0
    }

    /// A pasted list (VR-03): leading bullets and numbering removed; split at the first ` — `, ` – `, ` - `, tab or `: ` by position;
    /// a Cyrillic left side with a non-Cyrillic right side is swapped; empty lines skipped; texts over 120 characters rejected.
    public static func parseList(_ pasted: String) -> ParsedList {
        let separators = [" — ", " – ", " - ", "\t", ": "]
        var out = ParsedList()
        var lines = 0
        for raw in pasted.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            lines += 1
            if lines > maxListLines { out.rejected += 1; continue }
            line = stripBullet(line)
            var text = line, translation = ""
            if let sep = separators.compactMap({ s in line.range(of: s).map { (s, $0) } }).min(by: { $0.1.lowerBound < $1.1.lowerBound }) {
                text = String(line[..<sep.1.lowerBound]).trimmingCharacters(in: .whitespaces)
                translation = String(line[sep.1.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            if isCyrillic(text), !translation.isEmpty, !isCyrillic(translation) { swap(&text, &translation) }
            guard !normalize(text).isEmpty else { continue }
            guard text.count <= 120 else { out.rejected += 1; continue }
            out.entries.append((text, String(translation.prefix(160))))
        }
        return out
    }

    /// A bullet or a number is removed only when a space follows it, so "-5 Grad" and "1.5 kg" stay as they are.
    static func stripBullet(_ line: String) -> String {
        var s = Substring(line)
        if let f = s.first, "-•*–—".contains(f), s.dropFirst().first?.isWhitespace == true { s = s.dropFirst() }
        else {
            let digits = s.prefix { $0.isNumber }
            let rest = s.dropFirst(digits.count)
            if !digits.isEmpty, let next = rest.first, next == "." || next == ")", rest.dropFirst().first?.isWhitespace == true {
                s = s.dropFirst(digits.count + 1)
            }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    /// Mostly Cyrillic letters.
    static func isCyrillic(_ s: String) -> Bool {
        let letters = s.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let cyr = letters.filter { (0x0400...0x04FF).contains($0.value) }.count
        return cyr * 2 > letters.count
    }
}

/// Finds an item in an utterance (VR-07b). Golden cases: `packages/contracts/fixtures/vocab/matching.json`.
public enum VocabularyMatcher {
    public static let maxGap = 3
    static let placeholders: [Lang: Set<String>] = [
        .de: ["sich", "jdm", "jdn", "jemandem", "jemanden", "etw", "etwas"],
        .en: ["sb", "sth", "someone", "something", "somebody", "ones", "oneself"],
    ]
    static let endings: [Lang: Set<String>] = [
        .de: ["", "e", "en", "n", "st", "t", "et", "est", "te", "ten", "tet", "er", "es", "em", "s", "ens"],
        .en: ["", "s", "es", "ed", "ing", "er"],
    ]
    static let droppedEEndings: Set<String> = ["e", "es", "ed", "er", "ing"]
    /// Longest first, so that `vorbei` is tried before `vor`.
    static let separablePrefixes = ["zusammen", "zurück", "vorbei", "weiter", "durch", "fest", "nach", "auf", "aus", "bei", "ein", "her",
                                    "hin", "los", "mit", "vor", "weg", "ab", "an", "um", "zu"]

    /// Item tokens without placeholders (and without a leading English "to").
    public static func itemTokens(_ text: String, lang: Lang) -> [String] {
        var t = VocabularyText.tokens(text).filter { !(placeholders[lang]?.contains($0) ?? false) }
        if lang == .en, t.first == "to", t.count > 1 { t.removeFirst() }
        return t
    }

    static func stem(_ t: String, lang: Lang) -> String {
        switch lang {
        case .de:
            // At least 5 letters, so that short nouns keep their ending ("Rose" does not become "Ros" + "t").
            if t.count >= 5, t.hasSuffix("en") { return String(t.dropLast(2)) }
            if t.count >= 5, t.hasSuffix("n") || t.hasSuffix("e") { return String(t.dropLast()) }
            return t
        default:
            if t.count > 3, t.hasSuffix("e") { return String(t.dropLast()) }
            return t
        }
    }

    /// One item token against one word: equal, or stem + allowed ending; short tokens must be equal; German participles may drop `ge`.
    public static func wordMatches(_ token: String, _ word: String, lang: Lang) -> Bool {
        if token == word { return true }
        guard token.count > 3 else { return false }
        let s = stem(token, lang: lang)
        var candidates = [word]
        if lang == .de, word.hasPrefix("ge"), word.count >= 6 { candidates.append(String(word.dropFirst(2))) }
        // An English item that lost its `e` takes only vowel endings (`care` → `cares`, `caring`, but not `cars`, VR-07b).
        let allowed = lang == .en && s != token ? droppedEEndings : (endings[lang] ?? [])
        for w in candidates where w.hasPrefix(s) {
            if allowed.contains(String(w.dropFirst(s.count))) { return true }
        }
        return false
    }

    /// Indices of the utterance words that realise one item token at `i` (two indices for a separated German verb), or nil.
    static func tokenAt(_ token: String, _ words: [String], _ i: Int, lang: Lang) -> [Int]? {
        let word = words[i]
        if wordMatches(token, word, lang: lang) { return [i] }
        guard lang == .de else { return nil }
        for p in separablePrefixes where token.hasPrefix(p) && token.count > p.count + 3 {
            let verb = String(token.dropFirst(p.count))
            // Participle `angerufen` and zu-infinitive `anzurufen`: the prefix stays in front of the verb form.
            if word.hasPrefix(p), word.count > p.count + 3 {
                var rest = String(word.dropFirst(p.count))
                if rest.hasPrefix("zu"), rest.count > 4, wordMatches(verb, String(rest.dropFirst(2)), lang: lang) { return [i] }
                if rest.hasPrefix("ge") { rest = String(rest.dropFirst(2)) }
                if wordMatches(verb, rest, lang: lang) { return [i] }
            }
            // Split form: `ich rufe dich morgen an`.
            if wordMatches(verb, word, lang: lang), i + 1 < words.count, let j = words[(i + 1)...].firstIndex(of: p), j - i <= 10 { return [i, j] }
        }
        return nil
    }

    /// The utterance word indices that realise the item, or nil when the item does not occur. Backtracking search, so repeated
    /// words never hide a valid placement.
    static let maxSteps = 20_000

    public static func match(_ itemText: String, in utterance: String, lang: Lang) -> [Int]? {
        let a = itemTokens(itemText, lang: lang), b = VocabularyText.tokens(utterance)
        guard !a.isEmpty, !b.isEmpty else { return nil }
        // Every item token's possible placements, computed once; an item with a token that occurs nowhere is not searched.
        let hits: [[Int: [Int]]] = a.map { t in
            var m: [Int: [Int]] = [:]
            for i in b.indices { if let h = tokenAt(t, b, i, lang: lang) { m[i] = h } }
            return m
        }
        if hits.contains(where: \.isEmpty) { return nil }
        if lang == .de {
            // Any order within a window (word order changes in German clauses). The step budget bounds an item that repeats a word
            // against a long reply; running out counts as "not found" (an accepted miss, VR-07b).
            let width = a.count + maxGap * (a.count - 1)
            var steps = 0
            func assign(_ k: Int, _ range: Range<Int>, _ used: Set<Int>) -> [Int]? {
                if k == a.count { return [] }
                for i in range where !used.contains(i) {
                    steps += 1
                    if steps > maxSteps { return nil }
                    guard let hit = hits[k][i], used.isDisjoint(with: hit) else { continue }
                    if let rest = assign(k + 1, range, used.union(hit)) { return hit + rest }
                }
                return nil
            }
            for start in b.indices {
                if let span = assign(0, start..<min(b.count, start + width), []) { return span.sorted() }
            }
            return nil
        }
        // In order: memoised on (token, previous word), so the search is polynomial.
        var failed: Set<Int> = []
        func place(_ k: Int, after prev: Int) -> [Int]? {
            if k == a.count { return [] }
            let memo = k * (b.count + 1) + prev + 1
            if failed.contains(memo) { return nil }
            let range = k == 0 ? 0..<b.count : (prev + 1)..<min(b.count, prev + 2 + maxGap)
            for j in range {
                guard let hit = hits[k][j], let rest = place(k + 1, after: hit[0]) else { continue }
                return hit + rest
            }
            failed.insert(memo)
            return nil
        }
        return place(0, after: -1)
    }

    public static func contains(_ itemText: String, in utterance: String, lang: Lang) -> Bool { match(itemText, in: utterance, lang: lang) != nil }

    /// VR-07 outcome: a mistake when an `@fix` of the turn has an original that contains the item and a corrected text whose matched
    /// words differ (or that does not contain the item).
    public static func outcome(_ item: VocabItem, fixes: [Fix]) -> VocabOutcome {
        for f in fixes {
            guard let o = match(item.text, in: f.original, lang: item.lang) else { continue }
            let ow = VocabularyText.tokens(f.original), cw = VocabularyText.tokens(f.corrected)
            guard let c = match(item.text, in: f.corrected, lang: item.lang) else { return .mistake }
            if o.map({ ow[$0] }) != c.map({ cw[$0] }) { return .mistake }
        }
        return .ok
    }
}

/// Which items the model practises in the next turn (VR-06). Deterministic so that the web gives the same result.
public enum VocabularySelection {
    public static let ordinaryCount = 3
    public static let wordsModeCount = 6

    /// `pinned` (the "Practise" button) comes first while it is a candidate.
    public static func select(_ items: [VocabItem], lang: Lang, usedInSession: Set<String>, count: Int, pinned: String? = nil) -> [VocabItem] {
        var candidates = items.filter { $0.lang == lang && !usedInSession.contains($0.id) }.sorted(by: before)
        if let p = pinned, let i = candidates.firstIndex(where: { $0.id == p }) { candidates.insert(candidates.remove(at: i), at: 0) }
        return Array(candidates.prefix(max(0, count)))
    }

    static func before(_ a: VocabItem, _ b: VocabItem) -> Bool {
        if a.used != b.used { return a.used < b.used }
        if a.mistakes != b.mistakes { return a.mistakes > b.mistakes }
        if a.offered != b.offered { return a.offered < b.offered }
        switch (a.lastPractised, b.lastPractised) {
        case (nil, .some): return true
        case (.some, nil): return false
        case let (.some(x), .some(y)) where x != y: return x < y
        default: break
        }
        if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
        return Array(a.id.utf8).lexicographicallyPrecedes(Array(b.id.utf8))
    }
}
