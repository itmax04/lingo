import Foundation

/// Kind of provider limit (R-52): requests or tokens, per minute or per day.
public enum RateLimitKind: String, Codable, Sendable, Hashable {
    case rpm, rpd, tpm, tpd

    public var title: String {
        switch self {
        case .rpm: String(localized: "per-minute request limit")
        case .rpd: String(localized: "daily request limit")
        case .tpm: String(localized: "per-minute token limit")
        case .tpd: String(localized: "daily token limit")
        }
    }

    public var isDaily: Bool { self == .rpd || self == .tpd }

    /// From the provider's error text: "… on tokens per minute (TPM): Limit 8000, Used 6500 …" (Groq).
    public static func parse(_ message: String) -> RateLimitKind? {
        let m = message.lowercased()
        if m.contains("(tpd)") || m.contains("tokens per day") { return .tpd }
        if m.contains("(tpm)") || m.contains("tokens per minute") { return .tpm }
        if m.contains("(rpd)") || m.contains("requests per day") { return .rpd }
        if m.contains("(rpm)") || m.contains("requests per minute") { return .rpm }
        return nil
    }

    /// "Please try again in 1h2m3.5s" / "in 6.6s" / "in 450ms" → seconds.
    public static func tryAgainSeconds(_ message: String) -> Double? {
        guard let r = message.range(of: #"try again in ([0-9hms\.]+)"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return duration(String(message[r]).lowercased().replacingOccurrences(of: "try again in ", with: ""))
    }

    /// "2m59.56s", "7.66s", "450ms", "1h2m" → seconds.
    public static func duration(_ raw: String) -> Double? {
        let s = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        var total = 0.0
        var num = ""
        var i = s.startIndex
        var any = false
        while i < s.endIndex {
            let c = s[i]
            let next = s.index(after: i)
            if c.isNumber || c == "." {
                num.append(c)
            } else if c == "m", next < s.endIndex, s[next] == "s" {
                total += (Double(num) ?? 0) / 1000; num = ""; any = true; i = next
            } else if c == "h" {
                total += (Double(num) ?? 0) * 3600; num = ""; any = true
            } else if c == "m" {
                total += (Double(num) ?? 0) * 60; num = ""; any = true
            } else if c == "s" {
                total += Double(num) ?? 0; num = ""; any = true
            }
            i = s.index(after: i)
        }
        if !any, let n = Double(num) { return n }
        return any ? total : nil
    }
}

/// Remaining quota from the response headers (Groq: `x-ratelimit-*`). Empty fields — the provider did not send them.
public struct RateLimitSnapshot: Codable, Sendable, Hashable {
    public var remainingTokens: Int?
    public var limitTokens: Int?
    public var resetTokensSeconds: Double?
    public var remainingRequests: Int?
    public var limitRequests: Int?
    public var resetRequestsSeconds: Double?
    public var at: Date

    public init(remainingTokens: Int? = nil, limitTokens: Int? = nil, resetTokensSeconds: Double? = nil,
                remainingRequests: Int? = nil, limitRequests: Int? = nil, resetRequestsSeconds: Double? = nil, at: Date = Date()) {
        self.remainingTokens = remainingTokens
        self.limitTokens = limitTokens
        self.resetTokensSeconds = resetTokensSeconds
        self.remainingRequests = remainingRequests
        self.limitRequests = limitRequests
        self.resetRequestsSeconds = resetRequestsSeconds
        self.at = at
    }

    public init(headers: [AnyHashable: Any], at: Date = Date()) {
        func v(_ k: String) -> String? {
            for (key, value) in headers where (key as? String)?.lowercased() == k { return "\(value)" }
            return nil
        }
        self.init(remainingTokens: v("x-ratelimit-remaining-tokens").flatMap { Int($0) },
                  limitTokens: v("x-ratelimit-limit-tokens").flatMap { Int($0) },
                  resetTokensSeconds: v("x-ratelimit-reset-tokens").flatMap(RateLimitKind.duration),
                  remainingRequests: v("x-ratelimit-remaining-requests").flatMap { Int($0) },
                  limitRequests: v("x-ratelimit-limit-requests").flatMap { Int($0) },
                  resetRequestsSeconds: v("x-ratelimit-reset-requests").flatMap(RateLimitKind.duration), at: at)
    }

    public var isEmpty: Bool { remainingTokens == nil && remainingRequests == nil }

    /// Tokens left for the current minute: after the reset time — the full limit again (or unknown).
    public func tokensAvailable(now: Date = Date()) -> Int? {
        guard let r = remainingTokens else { return nil }
        if let reset = resetTokensSeconds, now.timeIntervalSince(at) >= reset { return limitTokens }
        return r
    }
}

/// A safe usage record of one request (R-52). Utterance texts and keys are never written.
public struct UsageRecord: Codable, Sendable, Hashable {
    public var ts: Date
    public var purpose: String
    public var provider: String
    public var model: String
    public var keyIndex: Int
    /// ok | http_<code> | timeout | network | cancelled | refusal | other
    public var status: String
    public var limitKind: RateLimitKind?
    public var retryAfter: Double?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var cachedTokens: Int?
    public var estimatedInput: Int
    public var remainingTokens: Int?
    public var remainingRequests: Int?
    public var ms: Int

    public init(ts: Date, purpose: String, provider: String, model: String, keyIndex: Int, status: String, limitKind: RateLimitKind?,
                retryAfter: Double?, inputTokens: Int?, outputTokens: Int?, cachedTokens: Int?, estimatedInput: Int,
                remainingTokens: Int?, remainingRequests: Int?, ms: Int) {
        self.ts = ts; self.purpose = purpose; self.provider = provider; self.model = model; self.keyIndex = keyIndex
        self.status = status; self.limitKind = limitKind; self.retryAfter = retryAfter; self.inputTokens = inputTokens
        self.outputTokens = outputTokens; self.cachedTokens = cachedTokens; self.estimatedInput = estimatedInput
        self.remainingTokens = remainingTokens; self.remainingRequests = remainingRequests; self.ms = ms
    }
}

/// Usage log: `<dir>/usage-<yyyy-mm-dd>.jsonl` + daily totals per model.
public final class UsageRecorder: @unchecked Sendable {
    public let dir: URL
    private let lock = NSLock()

    public init(dir: URL) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public func record(_ r: UsageRecord) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        guard let d = try? enc.encode(r) else { return }
        lock.withLock {
            let f = dir.appendingPathComponent("usage-\(MetricsRecorder.day()).jsonl")
            if !FileManager.default.fileExists(atPath: f.path) { FileManager.default.createFile(atPath: f.path, contents: nil) }
            guard let h = try? FileHandle(forWritingTo: f) else { return }
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: d + Data([0x0A]))
        }
        Log.metrics.notice("usage purpose=\(r.purpose, privacy: .public) model=\(r.model, privacy: .public) status=\(r.status, privacy: .public) in=\(r.inputTokens ?? -1, privacy: .public) out=\(r.outputTokens ?? -1, privacy: .public) cached=\(r.cachedTokens ?? -1, privacy: .public)")
    }

    public struct DaySummary: Sendable, Hashable {
        public var model: String
        public var requests = 0
        public var ok = 0
        public var limited = 0
        public var input = 0
        public var output = 0
        public var cached = 0
        public var lastRemainingTokens: Int?
        public var lastLimit: RateLimitKind?
        public var byPurpose: [String: Int] = [:]
    }

    public func records(day: String = MetricsRecorder.day()) -> [UsageRecord] {
        let f = dir.appendingPathComponent("usage-\(day).jsonl")
        guard let text = try? String(contentsOf: f, encoding: .utf8) else { return [] }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return text.split(separator: "\n").compactMap { try? dec.decode(UsageRecord.self, from: Data($0.utf8)) }
    }

    /// Today's totals per model (the "Quota" tab).
    public func today() -> [DaySummary] {
        var by: [String: DaySummary] = [:]
        for r in records() {
            var s = by[r.model] ?? DaySummary(model: r.model)
            s.requests += 1
            if r.status == "ok" { s.ok += 1 }
            if r.status == "http_429" { s.limited += 1; s.lastLimit = r.limitKind ?? s.lastLimit }
            s.input += r.inputTokens ?? 0
            s.output += r.outputTokens ?? 0
            s.cached += r.cachedTokens ?? 0
            if let rem = r.remainingTokens { s.lastRemainingTokens = rem }
            s.byPurpose[r.purpose, default: 0] += 1
            by[r.model] = s
        }
        return by.values.sorted { $0.model < $1.model }
    }
}

/// Rough token estimate of a request (≈ 3.5 characters per token for en/de/ru) — for choosing a step by remaining quota.
public enum TokenEstimate {
    public static func input(_ r: LLMRequest) -> Int {
        Int(Double(r.system.count + r.messages.reduce(0) { $0 + $1.text.count }) / 3.5)
    }
}
