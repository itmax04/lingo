// Ported from Interview Copilot (`Sources/CopilotCore/LLM/ProviderChain.swift`, commit cf0e764) and adapted per R-29:
// a step is a "provider + model + key" triple with any number of keys; an invalid key disables that key, not the provider;
// a failed step pauses for `retry-after` or 300 s, per "key + model" pair; parallel hedging was not ported (D-10).
import Foundation

/// A chain step without the key value — for labels, events and logs.
public struct StepInfo: Sendable, Hashable {
    public var provider: ProviderID
    public var model: String
    public var keyID: String
    /// Index of the key within its provider (1, 2, …) — used in labels and logs instead of the value.
    public var keyIndex: Int

    public init(provider: ProviderID, model: String, keyID: String, keyIndex: Int = 1) {
        self.provider = provider
        self.model = model
        self.keyID = keyID
        self.keyIndex = keyIndex
    }

    /// "provider · model" label (R-29) — without the family prefix ("openai/").
    public var label: String { "\(provider.displayName) · \(Self.shortModel(model))" }

    public static func shortModel(_ m: String) -> String {
        let s = m.split(separator: "/").last.map(String.init) ?? m
        return s.hasSuffix(":free") ? String(s.dropLast(5)) : s
    }
}

/// Chain events.
public enum ChainEvent: Sendable, Equatable {
    case attempt(StepInfo)
    case firstToken(StepInfo, afterMs: Double)
    case text(String)
    /// The previous partial text is discarded: the reply starts again on another step.
    case restart(StepInfo)
    case stepFailed(StepInfo, LLMError)
    /// The key is invalid (400/401/403) — disable it in settings (R-29).
    case keyInvalid(keyID: String, LLMError)
    case usage(StepInfo, TokenUsage)
    /// Remaining quota of a step from the response headers (R-52).
    case rateLimits(StepInfo, RateLimitSnapshot)
    /// `model` — the actual model from the response.
    case finished(StepInfo, model: String)
    /// No step replied (S-18). `retryAfter` — seconds until the nearest step becomes free.
    case exhausted(reason: String, retryAfter: TimeInterval?)
}

/// Pauses of failed steps per "key + model" pair (R-29).
public final class ProviderHealth: @unchecked Sendable {
    public static let shared = ProviderHealth()
    private let lock = NSLock()
    private var until: [String: (Date, LLMError)] = [:]
    public var defaultPause: TimeInterval = 300

    public init() {}

    static func key(_ s: StepInfo) -> String { "\(s.keyID)|\(s.model)" }

    public func pause(for s: StepInfo, now: Date = Date()) -> (until: Date, error: LLMError)? {
        lock.withLock {
            guard let (d, e) = until[Self.key(s)], d > now else { return nil }
            return (d, e)
        }
    }

    public func reportFailure(_ s: StepInfo, _ error: LLMError, now: Date = Date()) {
        if error == .cancelled || error.isInvalidKey { return }
        var seconds = defaultPause
        if let ra = error.retryAfterSeconds { seconds = ra }
        lock.withLock { until[Self.key(s)] = (now.addingTimeInterval(seconds), error) }
    }

    public func reportSuccess(_ s: StepInfo) {
        lock.withLock { until[Self.key(s)] = nil }
    }

    private var snapshots: [String: RateLimitSnapshot] = [:]

    public func report(_ s: StepInfo, snapshot: RateLimitSnapshot) {
        lock.withLock { snapshots[Self.key(s)] = snapshot }
    }

    public func snapshot(for s: StepInfo) -> RateLimitSnapshot? { lock.withLock { snapshots[Self.key(s)] } }

    /// Whether the remaining tokens for this minute are enough for the request (unknown — assume yes).
    public func hasRoom(_ s: StepInfo, needed: Int, now: Date = Date()) -> Bool {
        guard let a = snapshot(for: s)?.tokensAvailable(now: now) else { return true }
        return a >= needed
    }

    public func reset() { lock.withLock { until.removeAll(); snapshots.removeAll() } }
}

/// Chain of steps with automatic fallback (R-29). Fallback on: 429, 5xx, network error, model refusal, no first token within the timeout.
public struct ProviderChain: Sendable {
    public struct Step: Sendable {
        public var info: StepInfo
        public var provider: LLMProvider
        public var key: String

        public init(info: StepInfo, provider: LLMProvider, key: String) {
            self.info = info
            self.provider = provider
            self.key = key
        }
    }

    public var steps: [Step]
    public var firstTokenTimeout: Double
    public var health: ProviderHealth
    /// If every step hit a rate limit and the nearest one frees up within this many seconds —
    /// wait and run the chain once more (free Groq per-minute limits, P-05; fits Q3's "up to 8–10 s").
    public var autoRetryWithin: TimeInterval
    /// Usage log (R-52): one record per attempt.
    public var usage: UsageRecorder?

    public init(steps: [Step], firstTokenTimeout: Double = 6, health: ProviderHealth = ProviderHealth(), autoRetryWithin: TimeInterval = 12,
                usage: UsageRecorder? = nil) {
        self.steps = steps
        self.firstTokenTimeout = firstTokenTimeout
        self.health = health
        self.autoRetryWithin = autoRetryWithin
        self.usage = usage
    }

    /// Steps without a pause; if all are paused after a timeout or network error (not 429), they are tried last — the network may be back.
    /// `needed` — estimated request tokens: a step whose headers show less left for this minute goes to the end (R-52).
    /// `soonest` — the nearest end of a pause whose length the provider reported (`retry-after` or "try again in");
    /// default pauses (300 s) are never promised to the user (R-52).
    func plan(now: Date = Date(), needed: Int = 0) -> (run: [Step], soonest: Date?) {
        var fresh: [Step] = [], tight: [Step] = [], retryable: [Step] = []
        var soonest: Date?
        for s in steps {
            if let p = health.pause(for: s.info, now: now) {
                if p.error.retryAfterSeconds != nil { soonest = min(soonest ?? p.until, p.until) }
                if p.error.status != 429 { retryable.append(s) }
            } else if !health.hasRoom(s.info, needed: needed, now: now) {
                tight.append(s)
            } else {
                fresh.append(s)
            }
        }
        let run = fresh + tight
        return (run.isEmpty ? retryable : run, soonest)
    }

    /// Start. Cancelling the consumer task (utterance merging R-11, barge-in R-12) aborts the current request.
    public func run(_ request: LLMRequest) -> AsyncStream<ChainEvent> {
        AsyncStream { continuation in
            let task = Task {
                let start = DispatchTime.now().uptimeNanoseconds
                var reasons: [String] = []
                if steps.isEmpty {
                    continuation.yield(.exhausted(reason: String(localized: "no keys"), retryAfter: nil))
                    continuation.finish()
                    return
                }
                let needed = TokenEstimate.input(request) + request.maxTokens / 2
                var (usable, soonest) = plan(needed: needed)
                // All steps are on a short pause (429) — wait for the nearest one instead of giving up at once.
                if usable.isEmpty, let s = soonest, s.timeIntervalSinceNow <= autoRetryWithin {
                    try? await Task.sleep(for: .seconds(max(0.2, s.timeIntervalSinceNow + 0.2)))
                    (usable, soonest) = plan(needed: needed)
                }
                var attempted = 0
                var invalidKeys = Set<String>()
                // All failures are rate limits (429): then a second pass after a short wait is possible.
                var allRateLimited = true
                for step in usable {
                    if Task.isCancelled { break }
                    if invalidKeys.contains(step.info.keyID) { continue }
                    continuation.yield(.attempt(step.info))
                    if attempted > 0 { continuation.yield(.restart(step.info)) }
                    attempted += 1
                    let stats = StepStats()
                    let t0 = Date()
                    do {
                        try await Self.runStep(step, request: request, timeout: firstTokenTimeout, start: start, continuation: continuation,
                                               health: health, stats: stats)
                        health.reportSuccess(step.info)
                        record(step, request, status: "ok", error: nil, stats: stats, since: t0)
                        continuation.finish()
                        return
                    } catch {
                        let e = (error as? LLMError) ?? .network(error.localizedDescription)
                        record(step, request, status: Task.isCancelled ? "cancelled" : e.usageStatus, error: e, stats: stats, since: t0)
                        if Task.isCancelled { break }
                        if e == .cancelled { break }
                        if e.status != 429 { allRateLimited = false }
                        Log.llm.error("step \(step.info.provider.rawValue, privacy: .public) model=\(step.info.model, privacy: .public) key#\(step.info.keyIndex, privacy: .public) failed: \(e.description, privacy: .public)")
                        continuation.yield(.stepFailed(step.info, e))
                        if e.isInvalidKey {
                            invalidKeys.insert(step.info.keyID)
                            continuation.yield(.keyInvalid(keyID: step.info.keyID, e))
                        } else {
                            health.reportFailure(step.info, e)
                        }
                        reasons.append("\(step.info.label) (" + String(localized: "key \(step.info.keyIndex)") + "): \(e.description)")
                    }
                }
                // Every step failed on a rate limit and the nearest frees up soon — a second pass (once).
                if !Task.isCancelled, let s = plan(needed: needed).soonest, s.timeIntervalSinceNow <= autoRetryWithin, attempted > 0,
                   allRateLimited {
                    try? await Task.sleep(for: .seconds(max(0.2, s.timeIntervalSinceNow + 0.2)))
                    for step in plan(needed: needed).run where !invalidKeys.contains(step.info.keyID) {
                        if Task.isCancelled { break }
                        continuation.yield(.attempt(step.info))
                        continuation.yield(.restart(step.info))
                        let stats = StepStats()
                        let t0 = Date()
                        do {
                            try await Self.runStep(step, request: request, timeout: firstTokenTimeout, start: start, continuation: continuation,
                                                   health: health, stats: stats)
                            health.reportSuccess(step.info)
                            record(step, request, status: "ok", error: nil, stats: stats, since: t0)
                            continuation.finish()
                            return
                        } catch {
                            let e = (error as? LLMError) ?? .network(error.localizedDescription)
                            record(step, request, status: e.usageStatus, error: e, stats: stats, since: t0)
                            if e == .cancelled { break }
                            continuation.yield(.stepFailed(step.info, e))
                            health.reportFailure(step.info, e)
                            reasons.append("\(step.info.label) (" + String(localized: "key \(step.info.keyIndex)") + "): \(e.description)")
                        }
                    }
                }
                if !Task.isCancelled {
                    let now = Date()
                    let next = plan(now: now, needed: needed).soonest ?? soonest
                    let wait = next.map { max(0, $0.timeIntervalSince(now)) }
                    let reason = reasons.isEmpty ? String(localized: "all steps are paused after errors") : reasons.joined(separator: "; ")
                    continuation.yield(.exhausted(reason: reason, retryAfter: wait))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func record(_ step: Step, _ request: LLMRequest, status: String, error: LLMError?, stats: StepStats, since t0: Date) {
        guard let usage else { return }
        let snap = stats.snapshot
        usage.record(UsageRecord(ts: Date(), purpose: request.purpose.rawValue, provider: step.info.provider.rawValue, model: step.info.model,
                                 keyIndex: step.info.keyIndex, status: status, limitKind: error?.rateLimitKind, retryAfter: error?.retryAfterSeconds,
                                 inputTokens: stats.usage?.input, outputTokens: stats.usage?.output, cachedTokens: stats.usage?.cached,
                                 estimatedInput: TokenEstimate.input(request), remainingTokens: snap?.remainingTokens,
                                 remainingRequests: snap?.remainingRequests, ms: Int(Date().timeIntervalSince(t0) * 1000),
                                 finishReason: stats.stopReason))
    }

    /// One step; throws if a fallback is needed. The first-token timeout is a race against the clock.
    static func runStep(_ step: Step, request: LLMRequest, timeout: Double, start: UInt64,
                        continuation: AsyncStream<ChainEvent>.Continuation, health: ProviderHealth? = nil, stats: StepStats = StepStats()) async throws {
        let stream = step.provider.stream(request, model: step.info.model, key: step.key)
        let gotFirst = FirstTokenFlag()
        let stepStart = DispatchTime.now().uptimeNanoseconds
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var model = step.info.model
                var usage: TokenUsage?
                for try await event in stream {
                    switch event {
                    case .model(let m): model = m
                    case .text(let t):
                        if gotFirst.set() {
                            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
                            continuation.yield(.firstToken(step.info, afterMs: ms))
                        }
                        continuation.yield(.text(t))
                    case .usage(let u):
                        usage = u
                        stats.usage = u
                    case .rateLimits(let snap):
                        stats.snapshot = snap
                        health?.report(step.info, snapshot: snap)
                        continuation.yield(.rateLimits(step.info, snap))
                    case .done(let reason): stats.stopReason = reason
                    }
                }
                if let usage { continuation.yield(.usage(step.info, usage)) }
                if !gotFirst.isSet { throw LLMError.badResponse(String(localized: "empty reply")) }
                continuation.yield(.finished(step.info, model: model))
            }
            group.addTask {
                while true {
                    try await Task.sleep(for: .milliseconds(50))
                    if gotFirst.isSet { return }
                    if Double(DispatchTime.now().uptimeNanoseconds - stepStart) / 1e9 >= timeout {
                        throw LLMError.firstTokenTimeout
                    }
                }
            }
            do {
                for try await _ in group {}
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

/// Usage and remaining quota of one attempt — for the log (R-52).
final class StepStats: @unchecked Sendable {
    private let lock = NSLock()
    private var _usage: TokenUsage?
    private var _snapshot: RateLimitSnapshot?
    private var _stopReason: String?
    var usage: TokenUsage? { get { lock.withLock { _usage } } set { lock.withLock { _usage = newValue } } }
    var snapshot: RateLimitSnapshot? { get { lock.withLock { _snapshot } } set { lock.withLock { _snapshot = newValue } } }
    /// `finish_reason` of the last completed stream (`length` means the output reserve was too small).
    var stopReason: String? { get { lock.withLock { _stopReason } } set { lock.withLock { _stopReason = newValue } } }
}

final class FirstTokenFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var isSet: Bool { lock.withLock { value } }
    func set() -> Bool {
        lock.withLock {
            if value { return false }
            value = true
            return true
        }
    }
}

/// Building the chain from settings: the "provider + model" order, and for each item all working keys of the provider (R-29).
public enum ChainFactory {
    public static func provider(_ p: ProviderID, settings: LLMSettings, transport: StreamingTransport) -> LLMProvider {
        OpenAICompatibleProvider(p, transport: transport, customBase: settings.customBase)
    }

    /// Keys are read from the store — do not call on the main thread (the Keychain may wait for a system prompt).
    public static func chain(settings: LLMSettings, secrets: SecretStore, health: ProviderHealth = .shared,
                             transport: StreamingTransport = URLSessionTransport(),
                             providers: [ProviderID: LLMProvider]? = nil, usage: UsageRecorder? = nil) -> ProviderChain {
        var steps: [ProviderChain.Step] = []
        var values: [String: String] = [:]
        let entries = settings.pinnedEntryID.flatMap { pin in settings.chain.filter { $0.id == pin } }.flatMap { $0.isEmpty ? nil : $0 }
            ?? settings.chain.filter(\.enabled)
        for entry in entries {
            if entry.provider == .custom, settings.customBase == nil { continue }
            let model = entry.model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty else { continue }
            let prov = providers?[entry.provider] ?? provider(entry.provider, settings: settings, transport: transport)
            let keys = settings.keys(for: entry.provider)
            for (i, k) in keys.enumerated() where !k.invalid {
                if values[k.id] == nil { values[k.id] = (try? secrets.get(k.id)) ?? "" }
                guard let v = values[k.id], !v.isEmpty else { continue }
                steps.append(.init(info: StepInfo(provider: entry.provider, model: model, keyID: k.id, keyIndex: i + 1),
                                   provider: prov, key: v))
            }
        }
        return ProviderChain(steps: steps, firstTokenTimeout: settings.firstTokenTimeout.clamped(to: LLMSettings.timeoutRange),
                             health: health, usage: usage)
    }
}

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}
