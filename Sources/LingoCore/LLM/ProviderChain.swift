// Перенесено из Interview Copilot (`Sources/CopilotCore/LLM/ProviderChain.swift`, коммит cf0e764) с адаптацией по R-29:
// шаг — тройка «провайдер + модель + ключ», неограниченное число ключей; неверный ключ выключает этот ключ, а не провайдера;
// пауза отказавшего шага — по `retry-after` или 300 с, по паре «ключ + модель»; параллельный запуск (hedge) не переносился (D-10).
import Foundation

/// Шаг цепочки без значения ключа — для меток, событий и логов.
public struct StepInfo: Sendable, Hashable {
    public var provider: ProviderID
    public var model: String
    public var keyID: String
    /// Номер ключа у провайдера (1, 2, …) — для меток и логов вместо значения.
    public var keyIndex: Int

    public init(provider: ProviderID, model: String, keyID: String, keyIndex: Int = 1) {
        self.provider = provider
        self.model = model
        self.keyID = keyID
        self.keyIndex = keyIndex
    }

    /// Метка «провайдер · модель» (R-29) — без префикса семейства («openai/»).
    public var label: String { "\(provider.displayName) · \(Self.shortModel(model))" }

    public static func shortModel(_ m: String) -> String {
        let s = m.split(separator: "/").last.map(String.init) ?? m
        return s.hasSuffix(":free") ? String(s.dropLast(5)) : s
    }
}

/// События цепочки.
public enum ChainEvent: Sendable, Equatable {
    case attempt(StepInfo)
    case firstToken(StepInfo, afterMs: Double)
    case text(String)
    /// Предыдущий частичный текст отброшен: ответ начинается заново на другом шаге.
    case restart(StepInfo)
    case stepFailed(StepInfo, LLMError)
    /// Ключ недействителен (400/401/403) — выключить его в настройках (R-29).
    case keyInvalid(keyID: String, LLMError)
    case usage(StepInfo, TokenUsage)
    /// `model` — фактическая модель из ответа.
    case finished(StepInfo, model: String)
    /// Ни один шаг не ответил (S-18). `retryAfter` — через сколько секунд освободится ближайший шаг.
    case exhausted(reason: String, retryAfter: TimeInterval?)
}

/// Паузы отказавших шагов по паре «ключ + модель» (R-29).
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
        if case .http(_, _, let ra?) = error { seconds = ra }
        lock.withLock { until[Self.key(s)] = (now.addingTimeInterval(seconds), error) }
    }

    public func reportSuccess(_ s: StepInfo) {
        lock.withLock { until[Self.key(s)] = nil }
    }

    public func reset() { lock.withLock { until.removeAll() } }
}

/// Цепочка шагов с автопереходом (R-29). Переход: 429, 5xx, сетевая ошибка, отказ модели, нет первого токена за таймаут.
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
    /// Если все шаги упёрлись в лимит, а ближайший освободится не позже чем через столько секунд, —
    /// подождать и пройти цепочку ещё раз (бесплатные лимиты Groq в минуту, P-05; укладывается в Q3 «до 8–10 с»).
    public var autoRetryWithin: TimeInterval

    public init(steps: [Step], firstTokenTimeout: Double = 6, health: ProviderHealth = ProviderHealth(), autoRetryWithin: TimeInterval = 12) {
        self.steps = steps
        self.firstTokenTimeout = firstTokenTimeout
        self.health = health
        self.autoRetryWithin = autoRetryWithin
    }

    /// Шаги без паузы; если все на паузе по таймауту или сети (не 429), они пробуются последними — вдруг сеть вернулась.
    func plan(now: Date = Date()) -> (run: [Step], soonest: Date?) {
        var fresh: [Step] = [], retryable: [Step] = []
        var soonest: Date?
        for s in steps {
            if let p = health.pause(for: s.info, now: now) {
                soonest = min(soonest ?? p.until, p.until)
                if p.error.status != 429 { retryable.append(s) }
            } else {
                fresh.append(s)
            }
        }
        return (fresh.isEmpty ? retryable : fresh, soonest)
    }

    /// Запуск. Отмена задачи-потребителя (склейка реплик R-11, перебивание R-12) прерывает текущий запрос.
    public func run(_ request: LLMRequest) -> AsyncStream<ChainEvent> {
        AsyncStream { continuation in
            let task = Task {
                let start = DispatchTime.now().uptimeNanoseconds
                var reasons: [String] = []
                if steps.isEmpty {
                    continuation.yield(.exhausted(reason: "нет ключей", retryAfter: nil))
                    continuation.finish()
                    return
                }
                var (usable, soonest) = plan()
                // Все шаги на короткой паузе (429) — подождать ближайший, а не сдаваться сразу.
                if usable.isEmpty, let s = soonest, s.timeIntervalSinceNow <= autoRetryWithin {
                    try? await Task.sleep(for: .seconds(max(0.2, s.timeIntervalSinceNow + 0.2)))
                    (usable, soonest) = plan()
                }
                var attempted = 0
                var invalidKeys = Set<String>()
                for step in usable {
                    if Task.isCancelled { break }
                    if invalidKeys.contains(step.info.keyID) { continue }
                    continuation.yield(.attempt(step.info))
                    if attempted > 0 { continuation.yield(.restart(step.info)) }
                    attempted += 1
                    do {
                        try await Self.runStep(step, request: request, timeout: firstTokenTimeout, start: start, continuation: continuation)
                        health.reportSuccess(step.info)
                        continuation.finish()
                        return
                    } catch {
                        if Task.isCancelled { break }
                        let e = (error as? LLMError) ?? .network(error.localizedDescription)
                        if e == .cancelled { break }
                        Log.llm.error("step \(step.info.provider.rawValue, privacy: .public) model=\(step.info.model, privacy: .public) key#\(step.info.keyIndex, privacy: .public) failed: \(e.description, privacy: .public)")
                        continuation.yield(.stepFailed(step.info, e))
                        if e.isInvalidKey {
                            invalidKeys.insert(step.info.keyID)
                            continuation.yield(.keyInvalid(keyID: step.info.keyID, e))
                        } else {
                            health.reportFailure(step.info, e)
                        }
                        reasons.append("\(step.info.label) (ключ \(step.info.keyIndex)): \(e.description)")
                    }
                }
                // Все шаги отказали по лимиту, ближайший скоро освободится — второй проход (один раз).
                if !Task.isCancelled, let s = plan().soonest, s.timeIntervalSinceNow <= autoRetryWithin, attempted > 0,
                   reasons.allSatisfy({ $0.contains("429") }) {
                    try? await Task.sleep(for: .seconds(max(0.2, s.timeIntervalSinceNow + 0.2)))
                    for step in plan().run where !invalidKeys.contains(step.info.keyID) {
                        if Task.isCancelled { break }
                        continuation.yield(.attempt(step.info))
                        continuation.yield(.restart(step.info))
                        do {
                            try await Self.runStep(step, request: request, timeout: firstTokenTimeout, start: start, continuation: continuation)
                            health.reportSuccess(step.info)
                            continuation.finish()
                            return
                        } catch {
                            let e = (error as? LLMError) ?? .network(error.localizedDescription)
                            if e == .cancelled { break }
                            continuation.yield(.stepFailed(step.info, e))
                            health.reportFailure(step.info, e)
                            reasons.append("\(step.info.label) (ключ \(step.info.keyIndex)): \(e.description)")
                        }
                    }
                }
                if !Task.isCancelled {
                    let now = Date()
                    let next = plan(now: now).soonest ?? soonest
                    let wait = next.map { max(0, $0.timeIntervalSince(now)) }
                    let reason = reasons.isEmpty ? "все шаги на паузе после ошибок" : reasons.joined(separator: "; ")
                    continuation.yield(.exhausted(reason: reason, retryAfter: wait))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Один шаг; бросает ошибку, если нужен переход. Таймаут первого токена — гонка с часами.
    static func runStep(_ step: Step, request: LLMRequest, timeout: Double, start: UInt64,
                        continuation: AsyncStream<ChainEvent>.Continuation) async throws {
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
                    case .usage(let u): usage = u
                    case .done: break
                    }
                }
                if let usage { continuation.yield(.usage(step.info, usage)) }
                if !gotFirst.isSet { throw LLMError.badResponse("пустой ответ") }
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

/// Сборка цепочки из настроек: порядок «провайдер + модель», для каждого — все действующие ключи провайдера (R-29).
public enum ChainFactory {
    public static func provider(_ p: ProviderID, settings: LLMSettings, transport: StreamingTransport) -> LLMProvider {
        OpenAICompatibleProvider(p, transport: transport, customBase: settings.customBase)
    }

    /// Ключи читаются из хранилища — вызывать не на главном потоке (Keychain может ждать системного запроса).
    public static func chain(settings: LLMSettings, secrets: SecretStore, health: ProviderHealth = .shared,
                             transport: StreamingTransport = URLSessionTransport(),
                             providers: [ProviderID: LLMProvider]? = nil) -> ProviderChain {
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
                             health: health)
    }
}

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}
