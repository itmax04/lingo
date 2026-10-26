import Foundation
import LingoCore

/// The `commands` eval (AC-04): accuracy ≥ 95%, false positives on negatives ≤ 3%.
enum CommandsEval {
    struct Case: Decodable { var text: String; var expect: String; var argument: String? }
    struct Row: Encodable { var file: String; var text: String; var expect: String; var got: String; var argument: String?; var ok: Bool }
    struct Report: Encodable { var total: Int; var correct: Int; var accuracy: Double; var negatives: Int; var falsePositives: Int; var fpRate: Double; var rows: [Row] }

    static func run(set: String) throws -> Int32 {
        var rows: [Row] = []
        for f in try EvalIO.yamlFiles(set) {
            for c in try EvalIO.load([Case].self, from: f) {
                let m = CommandDetector.detect(c.text)
                let got = m?.kind.rawValue ?? "none"
                var ok = got == c.expect
                if ok, let want = c.argument {
                    ok = m?.argument?.lowercased() == want.lowercased()
                }
                rows.append(Row(file: f.lastPathComponent, text: c.text, expect: c.expect, got: got, argument: m?.argument, ok: ok))
            }
        }
        let correct = rows.filter(\.ok).count
        let neg = rows.filter { $0.expect == "none" }
        let fp = neg.filter { $0.got != "none" }.count
        let rep = Report(total: rows.count, correct: correct, accuracy: Double(correct) / Double(max(1, rows.count)),
                         negatives: neg.count, falsePositives: fp, fpRate: Double(fp) / Double(max(1, neg.count)), rows: rows)
        for r in rows where !r.ok { print("MISS [\(r.file)] \"\(r.text)\": expect=\(r.expect) got=\(r.got)\(r.argument.map { " arg=\($0)" } ?? "")") }
        let path = try EvalIO.writeOut("commands.json", rep)
        let pass = rep.accuracy >= 0.95 && rep.fpRate <= 0.03
        print("commands: \(correct)/\(rows.count) = \(EvalIO.pct(correct, rows.count)) (threshold ≥ 95%); negatives \(neg.count) (\(EvalIO.pct(neg.count, rows.count))), false positives \(fp) = \(EvalIO.pct(fp, neg.count)) (threshold ≤ 3%) → \(pass ? "PASS" : "FAIL")")
        print("out: \(path)")
        return pass ? 0 : 1
    }
}
