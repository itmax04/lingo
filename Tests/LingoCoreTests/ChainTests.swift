import Foundation
import Testing
@testable import LingoCore

/// Mock provider: behaviour per "model + key" pair.
struct MockProvider: LLMProvider {
    enum Behavior: Sendable { case text([String]), fail(LLMError), hang, failAfterText(String, LLMError), delayed(Double, [String]), stats([String], TokenUsage, RateLimitSnapshot) }
    let id: ProviderID
    let behavior: @Sendable (_ model: String, _ key: String) -> Behavior
    let calls: CallLog

    func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error> {
        calls.add("\(id.rawValue)/\(model)/\(key)")
        let b = behavior(model, key)
        return AsyncThrowingStream { c in
            let t = Task {
                switch b {
                case .text(let parts):
                    c.yield(.model(model))
                    for p in parts { c.yield(.text(p)) }
                    c.yield(.done(stopReason: "stop"))
                    c.finish()
                case .fail(let e):
                    c.finish(throwing: e)
                case .hang:
                    try? await Task.sleep(for: .seconds(30))
                    c.finish()
                case .stats(let parts, let u, let snap):
                    c.yield(.rateLimits(snap))
                    c.yield(.model(model))
                    for p in parts { c.yield(.text(p)) }
                    c.yield(.usage(u))
                    c.yield(.done(stopReason: "stop"))
                    c.finish()
                case .delayed(let d, let parts):
                    try? await Task.sleep(for: .seconds(d))
                    if Task.isCancelled { c.finish(throwing: LLMError.cancelled); return }
                    c.yield(.model(model))
                    for p in parts { c.yield(.text(p)) }
                    c.finish()
                case .failAfterText(let t, let e):
                    c.yield(.text(t))
                    c.finish(throwing: e)
                }
            }
            c.onTermination = { _ in t.cancel() }
        }
    }
}

final class CallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func add(_ s: String) { lock.withLock { items.append(s) } }
    var all: [String] { lock.withLock { items } }
}

func collect(_ s: AsyncStream<ChainEvent>) async -> [ChainEvent] {
    var out: [ChainEvent] = []
    for await e in s { out.append(e) }
    return out
}

func text(_ events: [ChainEvent]) -> String {
    var t = ""
    for e in events {
        if case .text(let x) = e { t += x }
        if case .restart = e { t = "" }
    }
    return t
}

let req = LLMRequest(system: "s", messages: [LLMMessage(role: .user, text: "u")], maxTokens: 10, purpose: .dialog)

@Suite struct ChainTests {
    func settings(keys: [KeyRecord], chain: [ChainEntry]) -> LLMSettings {
        LLMSettings(keys: keys, chain: chain, firstTokenTimeout: 2)
    }

    @Test func stepsAreProviderModelKeyAndUnlimitedKeys() {
        let keys = (1...50).map { KeyRecord(id: "g\($0)", provider: .groq, last4: "000\($0 % 10)") } + [KeyRecord(id: "m1", provider: .mistral, last4: "1111")]
        let secrets = InMemorySecretStore(Dictionary(uniqueKeysWithValues: keys.map { ($0.id, "secret-\($0.id)") }))
        let s = settings(keys: keys, chain: [ChainEntry(provider: .groq, model: "A"), ChainEntry(provider: .groq, model: "B"),
                                             ChainEntry(provider: .mistral, model: "M")])
        let chain = ChainFactory.chain(settings: s, secrets: secrets, health: ProviderHealth())
        #expect(chain.steps.count == 101)
        #expect(chain.steps[0].info.model == "A" && chain.steps[0].info.keyID == "g1")
        #expect(chain.steps[49].info.model == "A" && chain.steps[49].info.keyID == "g50")
        #expect(chain.steps[50].info.model == "B" && chain.steps[50].info.keyID == "g1")
        #expect(chain.steps[100].info.provider == .mistral)
    }

    func chain(_ behavior: @escaping @Sendable (String, String) -> MockProvider.Behavior, keys: [String] = ["k1", "k2"],
               models: [String] = ["A", "B"], health: ProviderHealth = ProviderHealth(), log: CallLog = CallLog()) -> ProviderChain {
        let recs = keys.map { KeyRecord(id: $0, provider: .groq, last4: "xxxx") }
        let secrets = InMemorySecretStore(Dictionary(uniqueKeysWithValues: keys.map { ($0, "v-\($0)") }))
        let p = MockProvider(id: .groq, behavior: behavior, calls: log)
        return ChainFactory.chain(settings: settings(keys: recs, chain: models.map { ChainEntry(provider: .groq, model: $0) }),
                                  secrets: secrets, health: health, providers: [.groq: p])
    }

    @Test func rateLimitGoesToNextKey() async {
        let log = CallLog()
        let c = chain({ m, k in k == "v-k1" ? .fail(.http(status: 429, message: "rate", retryAfter: 2)) : .text(["Hallo", "!"]) }, log: log)
        let ev = await collect(c.run(req))
        #expect(text(ev) == "Hallo!")
        #expect(log.all == ["groq/A/v-k1", "groq/A/v-k2"])
        #expect(ev.contains { if case .finished(let s, _) = $0 { return s.keyID == "k2" && s.label == "Groq · A" }; return false })
    }

    @Test func invalidKeyDisablesOnlyThatKey() async {
        let log = CallLog()
        let c = chain({ m, k in k == "v-k1" ? .fail(.http(status: 401, message: "Invalid API Key")) : (m == "A" ? .fail(.http(status: 503, message: "")) : .text(["ok"])) }, log: log)
        let ev = await collect(c.run(req))
        #expect(text(ev) == "ok")
        // After a 401, k1 is never tried again (including with model B); k2 works.
        #expect(log.all == ["groq/A/v-k1", "groq/A/v-k2", "groq/B/v-k2"])
        #expect(ev.contains(.keyInvalid(keyID: "k1", .http(status: 401, message: "Invalid API Key"))))
    }

    @Test func firstTokenTimeoutGoesNext() async {
        let c = chain({ m, _ in m == "A" ? .hang : .text(["B ok"]) }, keys: ["k1"])
        let t0 = Date()
        let ev = await collect(c.run(req))
        #expect(text(ev) == "B ok")
        #expect(ev.contains { if case .stepFailed(_, .firstTokenTimeout) = $0 { return true }; return false })
        #expect(Date().timeIntervalSince(t0) < 4)
    }

    @Test func midStreamFailureRestarts() async {
        let c = chain({ m, _ in m == "A" ? .failAfterText("Hal", .network("reset")) : .text(["Hallo"]) }, keys: ["k1"])
        let ev = await collect(c.run(req))
        #expect(text(ev) == "Hallo")
        #expect(ev.contains { if case .restart = $0 { return true }; return false })
    }

    @Test func exhaustedReportsRetryAfterAndPauseIsRespected() async {
        let health = ProviderHealth()
        let log = CallLog()
        let c = chain({ _, _ in .fail(.http(status: 429, message: "", retryAfter: 120)) }, health: health, log: log)
        let ev = await collect(c.run(req))
        guard case .exhausted(let reason, let wait)? = ev.last else { Issue.record("no exhausted"); return }
        #expect(reason.contains("429"))
        #expect((wait ?? 0) > 100 && (wait ?? 0) <= 120)
        #expect(log.all.count == 4)
        // All steps are paused after 429: a second run sends nothing and reports right away when to retry (S-18).
        let ev2 = await collect(c.run(req))
        #expect(log.all.count == 4)
        if case .exhausted(_, let w)? = ev2.last { #expect((w ?? 0) > 100) } else { Issue.record("no exhausted") }
    }

    @Test func shortRateLimitWaitsAndRetries() async {
        let calls = CallLog()
        let c = chain({ _, _ in
            calls.add("x")
            return calls.all.count <= 2 ? .fail(.http(status: 429, message: "", retryAfter: 1)) : .text(["Hallo"])
        }, keys: ["k1"])
        let t0 = Date()
        let ev = await collect(c.run(req))
        #expect(text(ev) == "Hallo")
        #expect(Date().timeIntervalSince(t0) >= 0.9 && Date().timeIntervalSince(t0) < 5)
    }

    @Test func defaultPauseWithoutRetryAfter() {
        let h = ProviderHealth()
        let s = StepInfo(provider: .groq, model: "A", keyID: "k")
        let now = Date()
        h.reportFailure(s, .http(status: 500, message: ""), now: now)
        #expect(abs(h.pause(for: s, now: now)!.until.timeIntervalSince(now) - 300) < 0.01)
        #expect(h.pause(for: StepInfo(provider: .groq, model: "B", keyID: "k"), now: now) == nil) // per "key + model" pair
        h.reportFailure(s, .http(status: 401, message: ""), now: now.addingTimeInterval(400))
        #expect(h.pause(for: s, now: now.addingTimeInterval(400)) == nil)
    }

    @Test func noKeysIsExhausted() async {
        let s = LLMSettings(keys: [], chain: LLMSettings.defaultChain)
        let c = ChainFactory.chain(settings: s, secrets: InMemorySecretStore(), health: ProviderHealth())
        let ev = await collect(c.run(req))
        #expect(ev == [.exhausted(reason: "no keys", retryAfter: nil)])
        #expect(!s.hasUsableKey)
    }

    @Test func invalidKeyErrorClassification() {
        #expect(LLMError.http(status: 401, message: "").isInvalidKey)
        #expect(LLMError.http(status: 403, message: "").isInvalidKey)
        #expect(LLMError.http(status: 400, message: "Invalid API Key provided").isInvalidKey)
        #expect(!LLMError.http(status: 400, message: "max_tokens must be positive").isInvalidKey)
        #expect(!LLMError.http(status: 429, message: "").isInvalidKey)
    }

    @Test func labelsAreShort() {
        #expect(StepInfo(provider: .groq, model: "openai/gpt-oss-120b", keyID: "x").label == "Groq · gpt-oss-120b")
        #expect(StepInfo(provider: .openrouter, model: "google/gemma-4-31b-it:free", keyID: "x").label == "OpenRouter · gemma-4-31b-it")
    }
}

/// A transport with a canned response — for the provider and the key check.
struct FixedTransport: StreamingTransport, HTTPTransport {
    let status: Int
    let headers: [String: String]
    let body: [String]

    func lines(for request: URLRequest) async throws -> (HTTPURLResponse, AsyncThrowingStream<String, Error>) {
        let r = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
        let lines = body
        return (r, AsyncThrowingStream { c in lines.forEach { c.yield($0) }; c.finish() })
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (Data(body.joined().utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
    }
}

@Suite struct ProviderTests {
    @Test func retryAfterAndRedaction() async {
        let key = "secret-abcdefgh-1234"
        let t = FixedTransport(status: 429, headers: ["retry-after": "17"], body: [#"{"error":{"message":"Rate limit for secret-abcdefgh-1234"}}"#])
        let p = OpenAICompatibleProvider(.groq, transport: t)
        do {
            for try await _ in p.stream(req, model: "m", key: key) {}
            Issue.record("an error was expected")
        } catch let e as LLMError {
            guard case .http(429, let msg, let ra) = e else { Issue.record("\(e)"); return }
            #expect(ra == 17)
            #expect(!msg.contains(key) && msg.contains("[key]"))
        } catch { Issue.record("\(error)") }
    }

    @Test func streamsDeltas() async throws {
        let t = FixedTransport(status: 200, headers: [:], body: [
            #"data: {"model":"openai/gpt-oss-120b","choices":[{"delta":{"content":"@say de: Hal"}}]}"#,
            #"data: {"choices":[{"delta":{"content":"lo!"},"finish_reason":"stop"}],"x_groq":{"usage":{"prompt_tokens":5,"completion_tokens":3}}}"#,
            "data: [DONE]",
        ])
        var got = ""
        var usage: TokenUsage?
        for try await e in OpenAICompatibleProvider(.groq, transport: t).stream(req, model: "m", key: "k") {
            if case .text(let x) = e { got += x }
            if case .usage(let u) = e { usage = u }
        }
        #expect(got == "@say de: Hallo!")
        #expect(usage == TokenUsage(input: 5, output: 3))
    }

    @Test func requestBodyPerProvider() throws {
        let groq = try OpenAICompatibleProvider(.groq, transport: FixedTransport(status: 200, headers: [:], body: []))
            .makeRequest(req, model: "openai/gpt-oss-120b", key: "k")
        let body = try JSONSerialization.jsonObject(with: groq.httpBody!) as! [String: Any]
        #expect(groq.url?.absoluteString == "https://api.groq.com/openai/v1/chat/completions")
        #expect(groq.value(forHTTPHeaderField: "Authorization") == "Bearer k")
        #expect(body["include_reasoning"] as? Bool == false)
        let mistral = try OpenAICompatibleProvider(.mistral, transport: FixedTransport(status: 200, headers: [:], body: []))
            .makeRequest(req, model: "mistral-small-latest", key: "k")
        #expect(mistral.url?.absoluteString == "https://api.mistral.ai/v1/chat/completions")
        #expect(throws: LLMError.self) {
            try OpenAICompatibleProvider(.custom, transport: FixedTransport(status: 200, headers: [:], body: [])).makeRequest(req, model: "x", key: "k")
        }
        #expect(ProviderEndpoints.customBaseURL("http://example.com/v1") == nil)
        #expect(ProviderEndpoints.customBaseURL("http://localhost:11434/v1/chat/completions")?.absoluteString == "http://localhost:11434/v1")
    }

    @Test func keyVerifierListsChatModelsOnly() async {
        let body = #"{"data":[{"id":"openai/gpt-oss-120b","active":true},{"id":"whisper-large-v3"},{"id":"meta-llama/llama-prompt-guard-2-22m"},{"id":"qwen/qwen3.8-27b"},{"id":"old","active":false},{"id":"canopylabs/orpheus-v1-english"}]}"#
        let r = await KeyVerifier(transport: FixedTransport(status: 200, headers: [:], body: [body])).verify(.groq, key: "k")
        #expect(r == .ok(models: ["openai/gpt-oss-120b", "qwen/qwen3.8-27b"]))
        let bad = await KeyVerifier(transport: FixedTransport(status: 401, headers: [:], body: [#"{"error":{"message":"Invalid API Key"}}"#])).verify(.groq, key: "k")
        #expect(bad == .invalidKey(status: 401, message: "Invalid API Key"))
    }
}

@Suite struct PinnedStepTests {
    @Test func pinnedEntryUsesOnlyThatStep() {
        var s = LLMSettings(keys: [KeyRecord(id: "g", provider: .groq, last4: "0000")],
                            chain: [ChainEntry(id: "a", provider: .groq, model: "A"), ChainEntry(id: "b", provider: .groq, model: "B")])
        s.pinnedEntryID = "b"
        let c = ChainFactory.chain(settings: s, secrets: InMemorySecretStore(["g": "v"]), health: ProviderHealth())
        #expect(c.steps.map(\.info.model) == ["B"])
        #expect(s.primaryLabel == "Groq · B")
        s.pinnedEntryID = nil
        #expect(ChainFactory.chain(settings: s, secrets: InMemorySecretStore(["g": "v"]), health: ProviderHealth()).steps.count == 2)
    }
}
