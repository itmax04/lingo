import Foundation
import LingoCore

/// Runs the `dialog` eval for one model: requests one at a time, waits on 429 (`retry-after`), records replies and rules.
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
        /// Why the run stopped early (budget, long limit, cancellation); nil — the whole set ran.
        public var stopped: String?
        public var requestsUsed: Int?
    }

    public var provider: LLMProvider
    public var model: String
    public var key: String
    public var log: @Sendable (String) -> Void
    /// Request budget for this model's run, including retries (R-52, Q29). When exhausted the run stops.
    public var maxRequests: Int
    /// Do not wait longer than this: a long `retry-after` (usually the daily limit) stops the run with a partial report.
    public var maxWait: Double
    public var usage: UsageRecorder?
    /// After each case — a partial report (survives the process being stopped).
    public var onProgress: (@Sendable (Report) -> Void)?
    private let counter = Counter()

    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        func next() -> Int { lock.withLock { n += 1; return n } }
        var value: Int { lock.withLock { n } }
    }

    public enum Stop: Error, CustomStringConvertible {
        case budget(Int), longWait(Double, RateLimitKind?), cancelled
        public var description: String {
            switch self {
            case .budget(let n): "request budget exhausted (\(n))"
            case .longWait(let w, let k): "the provider asks to wait \(LLMError.human(w))" + (k.map { " (\($0.title))" } ?? "")
            case .cancelled: "cancelled"
            }
        }
    }

    public init(provider: LLMProvider, model: String, key: String, maxRequests: Int = 15, maxWait: Double = 60,
                usage: UsageRecorder? = nil, log: @escaping @Sendable (String) -> Void = { print($0) }) {
        self.provider = provider
        self.model = model
        self.key = key
        self.maxRequests = maxRequests
        self.maxWait = maxWait
        self.usage = usage
        self.log = log
    }

    /// One request with retries on a short limit. A long wait, the budget and cancellation are `Stop`.
    public func ask(_ req: LLMRequest) async throws -> (String, Double, String?) {
        var attempt = 0
        while true {
            if Task.isCancelled { throw Stop.cancelled }
            guard counter.value < maxRequests else { throw Stop.budget(maxRequests) }
            _ = counter.next()
            attempt += 1
            let t0 = Date()
            var text = ""
            var u: TokenUsage?
            var snap: RateLimitSnapshot?
            func record(_ status: String, _ e: LLMError?) {
                usage?.record(UsageRecord(ts: Date(), purpose: "eval", provider: provider.id.rawValue, model: model, keyIndex: 1, status: status,
                                          limitKind: e?.rateLimitKind, retryAfter: e?.retryAfterSeconds, inputTokens: u?.input, outputTokens: u?.output,
                                          cachedTokens: u?.cached, estimatedInput: TokenEstimate.input(req), remainingTokens: snap?.remainingTokens,
                                          remainingRequests: snap?.remainingRequests, ms: Int(Date().timeIntervalSince(t0) * 1000)))
            }
            do {
                for try await e in provider.stream(req, model: model, key: key) {
                    switch e {
                    case .text(let t): text += t
                    case .usage(let x): u = x
                    case .rateLimits(let x): snap = x
                    default: break
                    }
                }
                record("ok", nil)
                return (text, Date().timeIntervalSince(t0) * 1000, nil)
            } catch let e as LLMError {
                record(e.usageStatus, e)
                if case .http(429, _, _) = e {
                    let wait = max(3, e.retryAfterSeconds ?? 20)
                    // The full retry-after is honoured; if it is long — stop rather than cap it at 90 s (review F-02).
                    if wait > maxWait { throw Stop.longWait(wait, e.rateLimitKind) }
                    log("  429 \(model): \(e.rateLimitKind?.title ?? "limit") — waiting \(Int(wait)) s")
                    try await Self.sleep(wait)
                    continue
                }
                if case .network = e, attempt <= 3 { try await Self.sleep(3); continue }
                if case .http(let s, _, _) = e, s >= 500 || s == 408, attempt <= 3 { try await Self.sleep(5); continue }
                return (text, Date().timeIntervalSince(t0) * 1000, e.description)
            } catch let s as Stop {
                throw s
            } catch {
                if Task.isCancelled { throw Stop.cancelled }
                return (text, Date().timeIntervalSince(t0) * 1000, error.localizedDescription)
            }
        }
    }

    /// A cancellable wait (review F-02: `try?` swallowed cancellation).
    static func sleep(_ s: Double) async throws {
        do { try await Task.sleep(for: .seconds(s)) } catch { throw Stop.cancelled }
    }

    public func run(_ cases: [DialogCase]) async -> Report {
        var rows: [Row] = []
        var stopped: String?
        for (i, c) in cases.enumerated() {
            let text: String, ms: Double, err: String?
            do {
                (text, ms, err) = try await ask(c.request())
            } catch {
                stopped = "\(error)"
                log("  [\(model)] stopped at \(i + 1)/\(cases.count): \(error)")
                break
            }
            let res = err == nil ? DialogRules.check(c, response: text) : nil
            rows.append(Row(id: c.id, category: c.category, lang: c.studyLang.rawValue, model: model, response: text, ms: ms, result: res, error: err))
            log(String(format: "  [%@] %d/%d %@ %@ %.0f ms", model, i + 1, cases.count, c.id,
                       err != nil ? "ERROR \(err!)" : (res!.pass ? "ok" : "FAIL " + res!.rules.filter { !$0.value }.keys.sorted().joined(separator: ",")), ms))
            var partial = Self.summarize(rows, model: model, provider: provider.id.rawValue)
            partial.stopped = "in progress: \(rows.count)/\(cases.count)"
            onProgress?(partial)
        }
        var r = Self.summarize(rows, model: model, provider: provider.id.rawValue)
        r.stopped = stopped
        r.requestsUsed = counter.value
        return r
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
                      medianMs: ms.isEmpty ? 0 : ms[ms.count / 2], rows: rows, stopped: nil, requestsUsed: nil)
    }

    /// Verdict by the evals/README.md thresholds: all rules of a case ≥ 90%, `no_pronunciation` = 100%, other rules by their own thresholds.
    public static func verdict(_ r: Report) -> (pass: Bool, lines: [String]) {
        var lines: [String] = []
        let overall = Double(r.passed) / Double(max(1, r.cases))
        var ok = overall >= 0.90
        lines.append(String(format: "%@: all case rules %d/%d = %.1f%% (≥ 90%%)%@, request errors %d, median %.0f ms",
                            r.model, r.passed, r.cases, overall * 100, overall >= 0.90 ? "" : " ✗", r.errors, r.medianMs))
        if let s = r.stopped { lines.append("  stopped: \(s)"); ok = false }
        if let n = r.requestsUsed { lines.append("  provider requests: \(n)") }
        for k in DialogRules.all {
            guard let c = r.ruleCounts[k] else { continue }
            let rate = Double(c[0]) / Double(max(1, c[1]))
            var mark = ""
            if let t = DialogRules.thresholds[k] {
                let good = rate >= t - 1e-9
                ok = ok && good
                mark = String(format: " (threshold %.0f%%)%@", t * 100, good ? "" : " ✗")
            }
            lines.append(String(format: "  %-20@ %d/%d = %.1f%%%@", k, c[0], c[1], rate * 100, mark))
        }
        return (ok, lines)
    }
}
