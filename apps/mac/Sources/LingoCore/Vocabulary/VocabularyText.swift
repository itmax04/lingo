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

    /// A pasted list (VR-03, A-01): one item per line; text and translation split by the first ` — `, ` – `, ` - `, tab or `: `.
    public static func parseList(_ pasted: String) -> [(text: String, translation: String)] {
        let separators = [" — ", " – ", " - ", "\t", ": "]
        var out: [(String, String)] = []
        for raw in pasted.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            var text = line, translation = ""
            if let sep = separators.compactMap({ s in line.range(of: s).map { (s, $0) } }).min(by: { $0.1.lowerBound < $1.1.lowerBound }) {
                text = String(line[..<sep.1.lowerBound]).trimmingCharacters(in: .whitespaces)
                translation = String(line[sep.1.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            guard !normalize(text).isEmpty else { continue }
            out.append((String(text.prefix(120)), String(translation.prefix(160))))
        }
        return out
    }
}

/// Finds the learner's items in an utterance (VR-07): tokens in the same order, at most 2 other tokens between neighbours;
/// a token matches equal text, or for tokens of at least 5 letters a common prefix of at least max(5, length − 2) letters.
public enum VocabularyMatcher {
    public static let maxGap = 2

    static func tokenMatches(_ item: String, _ word: String) -> Bool {
        if item == word { return true }
        guard item.count >= 5, word.count >= 5 else { return false }
        let need = max(5, item.count - 2)
        return word.count >= need && item.commonPrefix(with: word).count >= need
    }

    public static func contains(_ itemText: String, in utterance: String) -> Bool {
        let a = VocabularyText.tokens(itemText), b = VocabularyText.tokens(utterance)
        guard !a.isEmpty, a.count <= b.count else { return false }
        // Try every start position; greedy in-order search with bounded gaps.
        for start in b.indices where tokenMatches(a[0], b[start]) {
            var pos = start
            var ok = true
            for t in a.dropFirst() {
                var found: Int?
                var j = pos + 1
                while j < b.count, j - pos - 1 <= maxGap {
                    if tokenMatches(t, b[j]) { found = j; break }
                    j += 1
                }
                guard let f = found else { ok = false; break }
                pos = f
            }
            if ok { return true }
        }
        return false
    }

    public static func found(_ items: [VocabItem], in utterance: String) -> [VocabItem] {
        items.filter { contains($0.text, in: utterance) }
    }
}

/// Which items the model practises in the next turn (VR-06). Deterministic so that the web gives the same result.
public enum VocabularySelection {
    public static let ordinaryCount = 3
    public static let wordsModeCount = 6

    public static func select(_ items: [VocabItem], lang: Lang, usedInSession: Set<String>, count: Int) -> [VocabItem] {
        let candidates = items.filter { $0.lang == lang && !usedInSession.contains($0.id) }
        return Array(candidates.sorted(by: before).prefix(max(0, count)))
    }

    static func before(_ a: VocabItem, _ b: VocabItem) -> Bool {
        if a.used != b.used { return a.used < b.used }
        if a.offered != b.offered { return a.offered < b.offered }
        switch (a.lastPractised, b.lastPractised) {
        case (nil, .some): return true
        case (.some, nil): return false
        case let (.some(x), .some(y)) where x != y: return x < y
        default: break
        }
        if a.createdAt != b.createdAt { return a.createdAt > b.createdAt }
        return a.id < b.id
    }
}
