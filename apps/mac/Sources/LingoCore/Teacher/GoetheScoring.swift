import Foundation

/// LINGO-10 BR-27a, BR-28, BR-29: Goethe B1 Sprechen criteria, letter-to-points table and the debrief parser.
/// The model returns only letters; the app computes the points. There is no overall total, no level, and no pronunciation criterion.
public enum GoetheCriterion: String, Codable, Sendable, CaseIterable {
    case e1 = "1E", i1 = "1I", w1 = "1W", s1 = "1S"
    case e2 = "2E", k2 = "2K", w2 = "2W", s2 = "2S"
    case e3 = "3E"

    public var teil: Int { Int(rawValue.prefix(1))! }
    public var maximum: Int {
        switch self {
        case .i1, .k2: 4
        case .e1, .w1, .s1: 8
        case .e2, .w2, .s2: 12
        case .e3: 16
        }
    }
    public static func criteria(teil: Int) -> [GoetheCriterion] { allCases.filter { $0.teil == teil } }
}

public enum GoetheLetter: String, Codable, Sendable, CaseIterable {
    case a = "A", b = "B", c = "C", d = "D", e = "E"
    /// Index 0 (A) … 4 (E); the table of BR-28 is `maximum × (1, 3/4, 1/2, 1/4, 0)`.
    public func points(maximum: Int) -> Int? {
        let steps: [Int: [Int]] = [4: [4, 3, 2, 1, 0], 8: [8, 6, 4, 2, 0], 12: [12, 9, 6, 3, 0], 16: [16, 12, 8, 4, 0]]
        return steps[maximum].map { $0[Self.allCases.firstIndex(of: self)!] }
    }
}

public enum GoetheScoring {
    public static func teilMaximum(_ teil: Int) -> Int { GoetheCriterion.criteria(teil: teil).map(\.maximum).reduce(0, +) }

    /// Points of one Teil, nil unless every criterion has a letter. Zero rule (A-08): Erfüllung of Teil 1 = E scores the whole Teil 1 as 0.
    public static func teilPoints(_ teil: Int, letters: [GoetheCriterion: GoetheLetter]) -> (points: Int, zeroedByE: Bool)? {
        let criteria = GoetheCriterion.criteria(teil: teil)
        guard !criteria.isEmpty, criteria.allSatisfy({ letters[$0] != nil }) else { return nil }
        if teil == 1, letters[.e1] == .e { return (0, true) }
        return (criteria.reduce(0) { $0 + letters[$1]!.points(maximum: $1.maximum)! }, false)
    }
}

public struct GoetheTeilResult: Sendable, Equatable {
    public var teil: Int
    public var letters: [GoetheCriterion: GoetheLetter]
    public var sentences: [GoetheCriterion: String]
    public var strengths: [String]
    public var improvements: [String]
    /// nil when a code of this Teil was missing, malformed or repeated (BR-29): the card shows the text without points.
    public var points: Int?
    public var zeroedByE: Bool
}

public struct GoetheParsed: Sendable, Equatable {
    public var teile: [GoetheTeilResult]
    /// False when a `[T<n>]` header of a requested Teil is missing: the whole text is then shown unstructured.
    public var structured: Bool
}

public enum GoetheDebriefParser {
    /// Deterministic parse of the stored reply text. `teile` are the requested (finished) Teile.
    /// A line counts as a criterion when it starts with a requested code in brackets and a letter A–E that is not followed by another letter.
    /// A Teil gets points only if each of its codes was found exactly once. Lines after `[T<n>]` belong to Teil n until the next header.
    public static func parse(_ text: String, teile: [Int]) -> GoetheParsed {
        let requested = Set(teile)
        var found: [GoetheCriterion: [(GoetheLetter, String)]] = [:]
        var strengths: [Int: [String]] = [:], improvements: [Int: [String]] = [:]
        var headers = Set<Int>()
        var current: Int?
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let n = header(line) { current = requested.contains(n) ? n : nil; if requested.contains(n) { headers.insert(n) }; continue }
            if let (criterion, letter, sentence) = criterion(line), requested.contains(criterion.teil) {
                found[criterion, default: []].append((letter, sentence)); continue
            }
            guard let t = current else { continue }
            if line.hasPrefix("+ ") { strengths[t, default: []].append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)) }
            else if line.hasPrefix("> ") { improvements[t, default: []].append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)) }
        }
        let results = teile.sorted().map { teil -> GoetheTeilResult in
            var letters: [GoetheCriterion: GoetheLetter] = [:], sentences: [GoetheCriterion: String] = [:]
            for c in GoetheCriterion.criteria(teil: teil) {
                if let hits = found[c], hits.count == 1 { letters[c] = hits[0].0; sentences[c] = hits[0].1 }
            }
            let scored = GoetheScoring.teilPoints(teil, letters: letters)
            return GoetheTeilResult(teil: teil, letters: letters, sentences: sentences, strengths: strengths[teil] ?? [],
                                    improvements: improvements[teil] ?? [], points: scored?.points, zeroedByE: scored?.zeroedByE ?? false)
        }
        return GoetheParsed(teile: results, structured: requested.isSubset(of: headers))
    }

    /// `[T2]` → 2.
    private static func header(_ line: String) -> Int? {
        guard line.hasPrefix("[T"), let close = line.firstIndex(of: "]"), line.index(after: close) == line.endIndex else { return nil }
        let digits = line[line.index(line.startIndex, offsetBy: 2)..<close]
        return digits.allSatisfy({ $0.isASCII && $0.isNumber }) ? Int(digits) : nil
    }

    /// `[1E] B: one sentence` → (.e1, .b, "one sentence").
    private static func criterion(_ line: String) -> (GoetheCriterion, GoetheLetter, String)? {
        guard line.hasPrefix("["), let close = line.firstIndex(of: "]"),
              let c = GoetheCriterion(rawValue: String(line[line.index(after: line.startIndex)..<close])) else { return nil }
        var rest = line[line.index(after: close)...].drop { $0 == " " }
        guard let first = rest.first, let letter = GoetheLetter(rawValue: String(first)) else { return nil }
        rest = rest.dropFirst()
        if let next = rest.first, next.isLetter { return nil }
        let sentence = rest.drop { $0 == ":" || $0 == " " }
        return (c, letter, String(sentence))
    }
}
