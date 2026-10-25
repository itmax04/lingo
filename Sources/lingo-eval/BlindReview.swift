import Foundation
import LingoCore
import LingoEvalKit

/// Лист слепой оценки (evals/README.md, `blind`): N случайных ответов цепочки без меток модели и провайдера.
/// Ключ (какой кейс, модель) — evals/out/blind-key.json (в .gitignore).
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
        # Слепая оценка ответов (H-4)

        \(picked.count) случайных ответов цепочки на синтетические кейсы eval `dialog`, без меток модели и провайдера.
        Для каждого ответа отметьте в чате номер и «приемлемо» / «неприемлемо» (и при желании — почему).
        «Приемлемо» — так мог бы ответить хороший собеседник-преподаватель при этих настройках сессии.
        Порог: «приемлемо» ≥ 80% (evals/README.md). Строки @fix, @hint, @heard не озвучиваются — показаны для полноты.

        """
        var key: [KeyItem] = []
        for (i, r) in picked.enumerated() {
            guard let c = cases[r.id] else { continue }
            let s = c.session
            let last = c.history?.last(where: { $0.role == .assistant })?.text.replacingOccurrences(of: "\n", with: " ") ?? "—"
            md += """

            ## \(i + 1). \(s.lang.nativeName) · \(s.mode.title) · уровень \(s.level ?? "не указан") · исправления: \(s.corrections.map(\.title).joined(separator: ", "))
            \(s.custom_prompt.map { "Свой промпт: «\($0)»\n" } ?? "")Помощник перед этим: «\(last)»
            Пользователь: «\(c.user)»

            Ответ:
            ```
            \(r.response.trimmingCharacters(in: .whitespacesAndNewlines))
            ```

            """
            key.append(KeyItem(n: i + 1, caseID: r.id, model: r.model))
        }
        try md.write(toFile: "evals/blind-review.md", atomically: true, encoding: .utf8)
        _ = try EvalIO.writeOut("blind-key.json", key)
        print("blind: evals/blind-review.md (\(key.count) ответов), ключ evals/out/blind-key.json")
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
