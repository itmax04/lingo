import Foundation
import LingoCore
import LingoEvalKit

/// Blind review sheet (evals/README.md, `blind`): N random chain replies without model and provider labels.
/// The key (which case, which model) — evals/out/blind-key.json (in .gitignore).
enum BlindReview {
    struct KeyItem: Codable { var n: Int; var caseID: String; var model: String }

    static func run(from paths: [String], cases dir: String, n: Int, seed: UInt64) throws -> Int32 {
        let cases = Dictionary(uniqueKeysWithValues: try DialogCase.load(dir: URL(fileURLWithPath: dir)).map { ($0.id, $0) })
        var rows: [DialogRunner.Row] = []
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        for p in paths { rows += try dec.decode(DialogRunner.Report.self, from: Data(contentsOf: URL(fileURLWithPath: p))).rows.filter { $0.error == nil } }
        var rng = SeededRandom(seed: seed)
        let picked = Array(rows.shuffled(using: &rng).prefix(n))
        var md = """
        # Blind review of replies (H-4)

        \(picked.count) random chain replies to synthetic cases of the `dialog` eval, without model and provider labels.
        For each reply, write its number and "acceptable" / "not acceptable" in the chat (and, if you like, why).
        "Acceptable" — a good conversation partner and tutor could have answered like this with these session settings.
        Threshold: "acceptable" ≥ 80% (evals/README.md). @fix, @hint and @heard lines are not spoken — they are shown for completeness.

        """
        var key: [KeyItem] = []
        for (i, r) in picked.enumerated() {
            guard let c = cases[r.id] else { continue }
            let s = c.session
            let last = c.history?.last(where: { $0.role == .assistant })?.text.replacingOccurrences(of: "\n", with: " ") ?? "—"
            md += """

            ## \(i + 1). \(s.lang.nativeName) · \(s.mode.title) · level \(s.level ?? "not set") · corrections: \(s.corrections.map(\.title).joined(separator: ", "))
            \(s.custom_prompt.map { "Custom prompt: “\($0)”\n" } ?? "")Assistant before this: “\(last)”
            User: “\(c.user)”

            Reply:
            ```
            \(r.response.trimmingCharacters(in: .whitespacesAndNewlines))
            ```

            """
            key.append(KeyItem(n: i + 1, caseID: r.id, model: r.model))
        }
        try md.write(toFile: "evals/blind-review.md", atomically: true, encoding: .utf8)
        _ = try EvalIO.writeOut("blind-key.json", key)
        print("blind: evals/blind-review.md (\(key.count) replies), key evals/out/blind-key.json")
        return 0
    }
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
