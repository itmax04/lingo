import Foundation
import LingoCore

/// Прогон eval `dialog` по одной модели: запросы по одному, ожидание при 429 (`retry-after`), запись ответов и правил.
public struct DialogRunner: Sendable {
    public struct Row: Codable, Sendable {
        public var id: String
        public var category: String
        public var lang: String
        public var model: String
        public var response: String
        public var ms: Double
        public var result: DialogRules.Result?
        public var error: String?
    }

    public struct Report: Codable, Sendable {
        public var model: String
        public var provider: String
        public var date: Date
        public var cases: Int
        public var passed: Int
        public var errors: Int
        public var ruleRates: [String: Double]
        public var ruleCounts: [String: [Int]]
        public var categoryRates: [String: Double]
        public var medianMs: Double
        public var rows: [Row]
    }

    public var provider: LLMProvider
    public var model: String
    public var key: String
    public var log: @Sendable (String) -> Void

    public init(provider: LLMProvider, model: String, key: String, log: @escaping @Sendable (String) -> Void = { print($0) }) {
        self.provider = provider
        self.model = model
        self.key = key
        self.log = log
    }

    /// Один запрос с повторами при лимите (не считается ошибкой модели — это ограничение бесплатного тарифа).
    public func ask(_ req: LLMRequest) async -> (String, Double, String?) {
        var attempt = 0
        while true {
            attempt += 1
            let t0 = Date()
            var text = ""
            do {
                for try await e in provider.stream(req, model: model, key: key) {
                    if case .text(let t) = e { text += t }
                }
                return (text, Date().timeIntervalSince(t0) * 1000, nil)
            } catch let e as LLMError {
                if case .http(429, _, let ra) = e, attempt <= 8 {
                    let wait = min(90, max(3, ra ?? 20))
                    log("  429 \(model): жду \(Int(wait)) с")
                    try? await Task.sleep(for: .seconds(wait))
                    continue
                }
                if case .http(let s, _, _) = e, s >= 500, attempt <= 3 {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
                return (text, Date().timeIntervalSince(t0) * 1000, e.description)
            } catch {
                return (text, Date().timeIntervalSince(t0) * 1000, error.localizedDescription)
            }
        }
    }

    public func run(_ cases: [DialogCase]) async -> Report {
        var rows: [Row] = []
        for (i, c) in cases.enumerated() {
            let (text, ms, err) = await ask(c.request())
            let res = err == nil ? DialogRules.check(c, response: text) : nil
            rows.append(Row(id: c.id, category: c.category, lang: c.studyLang.rawValue, model: model, response: text, ms: ms, result: res, error: err))
            log(String(format: "  [%@] %d/%d %@ %@ %.0f мс", model, i + 1, cases.count, c.id,
                       err != nil ? "ERROR \(err!)" : (res!.pass ? "ok" : "FAIL " + res!.rules.filter { !$0.value }.keys.sorted().joined(separator: ",")), ms))
        }
        return Self.summarize(rows, model: model, provider: provider.id.rawValue)
    }

    public static func summarize(_ rows: [Row], model: String, provider: String) -> Report {
        var counts: [String: [Int]] = [:]
        var cat: [String: [Int]] = [:]
        for r in rows {
            let ok = r.result?.pass ?? false
            cat[r.category, default: [0, 0]][0] += ok ? 1 : 0
            cat[r.category, default: [0, 0]][1] += 1
            for (k, v) in r.result?.rules ?? [:] {
                counts[k, default: [0, 0]][0] += v ? 1 : 0
                counts[k, default: [0, 0]][1] += 1
            }
        }
        let ms = rows.filter { $0.error == nil }.map(\.ms).sorted()
        return Report(model: model, provider: provider, date: Date(), cases: rows.count,
                      passed: rows.filter { $0.result?.pass == true }.count, errors: rows.filter { $0.error != nil }.count,
                      ruleRates: counts.mapValues { Double($0[0]) / Double(max(1, $0[1])) }, ruleCounts: counts,
                      categoryRates: cat.mapValues { Double($0[0]) / Double(max(1, $0[1])) },
                      medianMs: ms.isEmpty ? 0 : ms[ms.count / 2], rows: rows)
    }

    /// Итог по порогам evals/README.md: все правила кейса ≥ 90%, `no_pronunciation` = 100%, правила — по своим порогам.
    public static func verdict(_ r: Report) -> (pass: Bool, lines: [String]) {
        var lines: [String] = []
        let overall = Double(r.passed) / Double(max(1, r.cases))
        var ok = overall >= 0.90
        lines.append(String(format: "%@: все правила кейса %d/%d = %.1f%% (≥ 90%%)%@, ошибок запроса %d, медиана %.0f мс",
                            r.model, r.passed, r.cases, overall * 100, overall >= 0.90 ? "" : " ✗", r.errors, r.medianMs))
        for k in DialogRules.all {
            guard let c = r.ruleCounts[k] else { continue }
            let rate = Double(c[0]) / Double(max(1, c[1]))
            var mark = ""
            if let t = DialogRules.thresholds[k] {
                let good = rate >= t - 1e-9
                ok = ok && good
                mark = String(format: " (порог %.0f%%)%@", t * 100, good ? "" : " ✗")
            }
            lines.append(String(format: "  %-20@ %d/%d = %.1f%%%@", k, c[0], c[1], rate * 100, mark))
        }
        return (ok, lines)
    }
}
