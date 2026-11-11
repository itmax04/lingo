import Foundation
import Testing
@testable import LingoCore

/// LINGO-10 G-1: BR-28 (letters to points), BR-29 (parser), BR-40 (contract fixture), BAC-13.
@Suite struct GoetheScoringTests {
    struct Case: Codable, Equatable {
        var name: String
        var text: String
        var teile: [Int]
        var structured: Bool
        /// Per requested Teil, in order: points, or nil when the Teil shows its text without points.
        var points: [Int?]
        var zeroedByE: [Bool]
    }

    static let full = """
    [1E] A: Alle Punkte erfüllt.
    [1I] B: Gute Reaktion.
    [1W] C: Einfache Wörter.
    [1S] D: Einige Fehler.
    [T1]
    + Klare Vorschläge
    + Gute Höflichkeit
    > Mehr Verbindungswörter
    > Genauere Verben
    > Längere Sätze
    """

    static let cases: [Case] = [
        .init(name: "teil1 mixed letters", text: full, teile: [1], structured: true, points: [8 + 3 + 4 + 2], zeroedByE: [false]),
        .init(name: "all A over three Teile", text: """
              [1E] A: x
              [1I] A: x
              [1W] A: x
              [1S] A: x
              [2E] A: x
              [2K] A: x
              [2W] A: x
              [2S] A: x
              [3E] A: x
              [T1]
              + a
              [T2]
              + b
              [T3]
              + c
              """, teile: [1, 2, 3], structured: true, points: [28, 40, 16], zeroedByE: [false, false, false]),
        .init(name: "zero rule: 1E is E", text: full.replacingOccurrences(of: "[1E] A", with: "[1E] E"), teile: [1], structured: true,
              points: [0], zeroedByE: [true]),
        .init(name: "E elsewhere does not zero the Teil", text: """
              [2E] A: x
              [2K] E: x
              [2W] E: x
              [2S] B: x
              [T2]
              """, teile: [2], structured: true, points: [12 + 0 + 0 + 9], zeroedByE: [false]),
        .init(name: "missing code gives no points, other Teil still scored", text: """
              [1E] A: x
              [1I] A: x
              [1W] A: x
              [2E] C: x
              [2K] C: x
              [2W] C: x
              [2S] C: x
              [T1]
              [T2]
              """, teile: [1, 2], structured: true, points: [nil, 6 + 2 + 6 + 6], zeroedByE: [false, false]),
        .init(name: "repeated code gives no points", text: full + "\n[1W] A: again", teile: [1], structured: true, points: [nil], zeroedByE: [false]),
        .init(name: "letter followed by a letter is not a letter", text: full.replacingOccurrences(of: "[1I] B:", with: "[1I] Bitte"),
              teile: [1], structured: true, points: [nil], zeroedByE: [false]),
        .init(name: "lowercase letter and unknown letter", text: full.replacingOccurrences(of: "[1W] C", with: "[1W] c").replacingOccurrences(of: "[1S] D", with: "[1S] F"),
              teile: [1], structured: true, points: [nil], zeroedByE: [false]),
        .init(name: "code not at the line start", text: "Siehe [1E] A\n" + full.split(separator: "\n").dropFirst().joined(separator: "\n"),
              teile: [1], structured: true, points: [nil], zeroedByE: [false]),
        .init(name: "codes of an unrequested Teil are ignored", text: full + "\n[2E] A: x", teile: [1], structured: true, points: [17], zeroedByE: [false]),
        .init(name: "no headers: unstructured, points still from the codes", text: full.replacingOccurrences(of: "[T1]", with: ""),
              teile: [1], structured: false, points: [17], zeroedByE: [false]),
        .init(name: "nothing parsable", text: "Das war gut.", teile: [1, 3], structured: false, points: [nil, nil], zeroedByE: [false, false]),
    ]

    @Test func lettersMapToPointsPerMaximum() {
        let table: [Int: [Int]] = [4: [4, 3, 2, 1, 0], 8: [8, 6, 4, 2, 0], 12: [12, 9, 6, 3, 0], 16: [16, 12, 8, 4, 0]]
        for (maximum, points) in table {
            #expect(GoetheLetter.allCases.map { $0.points(maximum: maximum) } == points)
        }
        #expect(GoetheLetter.a.points(maximum: 5) == nil)
        #expect([1, 2, 3].map(GoetheScoring.teilMaximum) == [28, 40, 16])
        #expect(GoetheCriterion.allCases.map(\.rawValue) == ["1E", "1I", "1W", "1S", "2E", "2K", "2W", "2S", "3E"])
    }

    @Test func parserMatchesGoldenCases() {
        for c in Self.cases {
            let parsed = GoetheDebriefParser.parse(c.text, teile: c.teile)
            #expect(parsed.structured == c.structured, "\(c.name)")
            #expect(parsed.teile.map(\.points) == c.points, "\(c.name)")
            #expect(parsed.teile.map(\.zeroedByE) == c.zeroedByE, "\(c.name)")
        }
        let p = GoetheDebriefParser.parse(Self.full, teile: [1]).teile[0]
        #expect(p.strengths == ["Klare Vorschläge", "Gute Höflichkeit"] && p.improvements.count == 3)
        #expect(p.letters[.w1] == .c && p.sentences[.w1] == "Einfache Wörter.")
    }

    @Test func contractFixtureHoldsTableZeroRuleAndGoldenCases() throws {
        struct File: Codable, Equatable {
            var rule: String
            var maxima: [String: Int]
            var teilMaxima: [String: Int]
            var letterPoints: [String: [String: Int]]
            var zeroRule: String
            var parserCases: [Case]
            /// LINGO-10 BR-30a: lines the Goethe score filter drops (`dropped` true) and lines it keeps.
            var filterCases: [GoetheDebriefTests.FilterCase]
        }
        var letterPoints: [String: [String: Int]] = [:]
        for m in [4, 8, 12, 16] {
            letterPoints[String(m)] = Dictionary(uniqueKeysWithValues: GoetheLetter.allCases.map { ($0.rawValue, $0.points(maximum: m)!) })
        }
        let file = File(rule: "LINGO-10 BR-28, BR-29, BR-40: scoring contract. Written by Swift GoetheScoringTests (LINGO_RECORD_FIXTURES=1). Parser cases: text and requested Teile in, points per Teil (null = text without points) out. Filter cases: a debrief line in, whether the score filter drops it.",
                        maxima: Dictionary(uniqueKeysWithValues: GoetheCriterion.allCases.map { ($0.rawValue, $0.maximum) }),
                        teilMaxima: ["1": 28, "2": 40, "3": 16], letterPoints: letterPoints,
                        zeroRule: "1E = E scores Teil 1 as 0 in total; no other criterion zeroes a Teil.", parserCases: Self.cases, filterCases: GoetheDebriefTests.filterCases)
        let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        try ExamTests.fixture("fixtures/teacher/goethe-scoring.json", String(decoding: enc.encode(file), as: UTF8.self) + "\n")
    }
}
