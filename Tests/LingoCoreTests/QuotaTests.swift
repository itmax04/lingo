import Foundation
import Testing
@testable import LingoCore
@testable import LingoEvalKit

/// Q29 stage 1 / external review F-01…F-05: limits, usage, budget, dispatcher.
@Suite struct RateLimitParsingTests {
    let groqTPD = "Rate limit reached for model `openai/gpt-oss-120b` in organization `org_01abcDEF` service tier `on_demand` on tokens per day (TPD): Limit 200000, Used 199500, Requested 2400. Please try again in 1h2m3.5s."

    @Test func kindsAndWaits() {
        #expect(RateLimitKind.parse(groqTPD) == .tpd)
        #expect(RateLimitKind.parse("... on tokens per minute (TPM): Limit 8000 ...") == .tpm)
        #expect(RateLimitKind.parse("... on requests per day (RPD) ...") == .rpd)
        #expect(RateLimitKind.parse("Too many requests") == nil)
        #expect(abs((RateLimitKind.tryAgainSeconds(groqTPD) ?? 0) - 3723.5) < 0.01)
        #expect(RateLimitKind.tryAgainSeconds("Please try again in 6.6s.") == 6.6)
        #expect(RateLimitKind.tryAgainSeconds("try again in 450ms") == 0.45)
        #expect(RateLimitKind.duration("2m59.56s").map { abs($0 - 179.56) < 0.01 } == true)
    }

    @Test func errorDescriptionIsHonest() {
        let e = LLMError.http(status: 429, message: groqTPD)
        #expect(e.rateLimitKind == .tpd)
        #expect(e.description == "daily token limit — retry in 1 h 2 min")
        #expect(LLMError.http(status: 429, message: "slow down", retryAfter: nil).description == "provider limit (429, kind not specified)")
        #expect(LLMError.http(status: 429, message: "x", retryAfter: 7).description.contains("retry in 7 s"))
    }

    @Test func orgIdIsRedacted() {
        #expect(!SSE.redact(groqTPD, key: "").contains("org_01abcDEF"))
    }

    @Test func headersSnapshot() {
        let at = Date(timeIntervalSince1970: 1000)
        let s = RateLimitSnapshot(headers: ["x-ratelimit-remaining-tokens": "1200", "x-ratelimit-limit-tokens": "8000",
                                            "x-ratelimit-reset-tokens": "7.66s", "x-ratelimit-remaining-requests": "14370"], at: at)
        #expect(s.remainingTokens == 1200 && s.remainingRequests == 14370 && s.resetTokensSeconds == 7.66)
        #expect(s.tokensAvailable(now: at.addingTimeInterval(1)) == 1200)
        #expect(s.tokensAvailable(now: at.addingTimeInterval(8)) == 8000)
    }
}

@Suite struct QuotaChainTests {
    func chain(_ b: @escaping @Sendable (String, String) -> MockProvider.Behavior, models: [String] = ["A", "B"],
               health: ProviderHealth = ProviderHealth(), usage: UsageRecorder? = nil) -> ProviderChain {
        let p = MockProvider(id: .groq, behavior: b, calls: CallLog())
        let s = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")],
                            chain: models.map { ChainEntry(provider: .groq, model: $0) }, firstTokenTimeout: 2)
        return ChainFactory.chain(settings: s, secrets: InMemorySecretStore(["k": "v"]), health: health, providers: [.groq: p], usage: usage)
    }

    @Test func usageIsRecordedPerAttempt() async throws {
        let rec = UsageRecorder(dir: tempDir("usage"))
        let snap = RateLimitSnapshot(remainingTokens: 5000, limitTokens: 8000)
        let c = chain({ m, _ in m == "A" ? .fail(.http(status: 429, message: "on tokens per minute (TPM). Please try again in 2s")) : .stats(["ok"], TokenUsage(input: 1500, output: 80, cached: 1200), snap) }, usage: rec)
        _ = await collect(c.run(req))
        let r = rec.records()
        #expect(r.count == 2)
        #expect(r[0].status == "http_429" && r[0].limitKind == .tpm && r[0].retryAfter == 2)
        #expect(r[1].status == "ok" && r[1].inputTokens == 1500 && r[1].cachedTokens == 1200 && r[1].remainingTokens == 5000)
        #expect(rec.today().first { $0.model == "B" }?.cached == 1200)
    }

    @Test func stepWithoutRoomGoesLast() async {
        let health = ProviderHealth()
        let log = CallLog()
        let p = MockProvider(id: .groq, behavior: { _, _ in .text(["ok"]) }, calls: log)
        let s = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "A"), ChainEntry(provider: .groq, model: "B")])
        let c = ChainFactory.chain(settings: s, secrets: InMemorySecretStore(["k": "v"]), health: health, providers: [.groq: p])
        health.report(StepInfo(provider: .groq, model: "A", keyID: "k"), snapshot: RateLimitSnapshot(remainingTokens: 1, limitTokens: 8000, resetTokensSeconds: 30))
        _ = await collect(c.run(req))
        #expect(log.all == ["groq/B/v"], "A is skipped: 1 token left for this minute")
    }

    @Test func retryAfterFromMessageAndHonestExhaustion() async {
        // "try again in 1s" without a header → a short pause → a second pass and a reply.
        let calls = CallLog()
        let c = chain({ _, _ in
            calls.add("x")
            return calls.all.count <= 2 ? .fail(.http(status: 429, message: "on tokens per minute (TPM). Please try again in 1s")) : .text(["Hallo"])
        })
        #expect(text(await collect(c.run(req))) == "Hallo")
        // 429 without a time → exhausted without promising a time.
        let c2 = chain({ _, _ in .fail(.http(status: 429, message: "too many")) })
        let ev = await collect(c2.run(req))
        guard case .exhausted(_, let wait)? = ev.last else { Issue.record("\(ev)"); return }
        #expect(wait == nil)
    }

    @Test func engineMessageWithoutKnownTime() async throws {
        let store = try JournalStore(base: tempDir("q"), deviceName: "Mac", deviceID: "mac-q")
        let p = MockProvider(id: .groq, behavior: { _, _ in .fail(.http(status: 429, message: "on tokens per day (TPD)")) }, calls: CallLog())
        let s = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "A")])
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: s, secrets: InMemorySecretStore(["k": "v"]), health: ProviderHealth(), providers: [.groq: p]) }
        let sid = try await e.createSession(SessionSettings(lang: .en, mode: .free, corrections: [.inline]))
        for await _ in e.send(session: sid, text: "Hi", lang: .en) {}
        let msg = await store.state.messages[sid]!.last!
        #expect(msg.kind == .error && msg.text.contains("daily token limit") && msg.text.contains("The provider did not say when it will recover"))
    }
}

@Suite struct ContextBudgetTests {
    @Test func defaultEightAndCharBudget() {
        #expect(ContextPolicy().maxTurns == 8)
        let long = String(repeating: "Wort ", count: 300)
        let msgs = (0..<8).flatMap { i in
            [ChatMessage(id: "u\(i)", session: "s", role: .user, text: long, lang: .de, createdAt: Date(timeIntervalSince1970: Double(i * 2))),
             ChatMessage(id: "a\(i)", session: "s", role: .assistant, text: long, lang: .de, createdAt: Date(timeIntervalSince1970: Double(i * 2 + 1)))]
        }
        let w = ContextPolicy().window(msgs)
        #expect(w.count < msgs.count && w.first?.role == .user && w.last?.id == "a7")
        #expect(w.reduce(0) { $0 + $1.text.count } <= ContextPolicy.transcriptCharBudget + 1600)
    }

    @Test func migrateOldOrder() {
        var s = LLMSettings(chain: [ChainEntry(provider: .groq, model: "openai/gpt-oss-120b"), ChainEntry(provider: .groq, model: "qwen/qwen3.8-27b"),
                                    ChainEntry(provider: .groq, model: "openai/gpt-oss-20b")])
        #expect(LLMSettings.migrateOrder(&s))
        #expect(s.chain.map(\.model) == ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b"])
        #expect(!LLMSettings.migrateOrder(&s))
        #expect(LLMSettings.defaultChain.prefix(3).map(\.model) == ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b"])
    }
}

@Suite struct EvalGuardTests {
    func cases(_ n: Int) throws -> [DialogCase] { Array(try DialogCase.load(dir: DialogRulesTests.dir).prefix(n)) }

    @Test func longWaitStopsWithPartialReport() async throws {
        let calls = CallLog()
        let p = MockProvider(id: .groq, behavior: { _, _ in
            calls.add("x")
            return calls.all.count <= 2 ? .text(["@say de: Gut. Und Sie?"]) : .fail(.http(status: 429, message: "on tokens per day (TPD). Please try again in 3h"))
        }, calls: CallLog())
        let r = await DialogRunner(provider: p, model: "m", key: "k", maxRequests: 50, log: { _ in }).run(try cases(5))
        #expect(r.rows.count == 2)
        #expect(r.stopped?.contains("daily token limit") == true)
        #expect(!DialogRunner.verdict(r).pass)
    }

    @Test func budgetStops() async throws {
        let p = MockProvider(id: .groq, behavior: { _, _ in .text(["@say de: Gut."]) }, calls: CallLog())
        let r = await DialogRunner(provider: p, model: "m", key: "k", maxRequests: 3, log: { _ in }).run(try cases(6))
        #expect(r.rows.count == 3 && r.requestsUsed == 3 && r.stopped?.contains("budget") == true)
    }

    @Test func cancellationStopsNewRequests() async throws {
        let log = CallLog()
        let p = MockProvider(id: .groq, behavior: { _, _ in .fail(.http(status: 429, message: "x", retryAfter: 30)) }, calls: log)
        let runner = DialogRunner(provider: p, model: "m", key: "k", maxRequests: 50, log: { _ in })
        let cs = try cases(5)
        let t = Task { await runner.run(cs) }
        try await Task.sleep(for: .milliseconds(300))
        t.cancel()
        let r = await t.value
        #expect(log.all.count == 1, "no new requests after cancellation")
        #expect(r.stopped?.contains("cancelled") == true)
    }
}

@Suite struct DispatcherTests {
    @Test func topicPhrasesOnlyAfterFirstReply() async throws {
        let store = try JournalStore(base: tempDir("disp"), deviceName: "Mac", deviceID: "mac-d")
        let order = CallLog()
        let p = MockProvider(id: .groq, behavior: { _, _ in .text(["@hint de: Hallo. | Привет.\n@say de: Hallo!"]) }, calls: order)
        let s = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "A")])
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: s, secrets: InMemorySecretStore(["k": "v"]), health: ProviderHealth(), providers: [.groq: p]) }
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]))
        await e.requestTopicPhrases(sid)
        #expect(order.all.isEmpty, "topic phrases are not requested before the first turn")
        for await _ in e.respond(session: sid) {}
        try await Task.sleep(for: .milliseconds(300))
        #expect(order.all.count == 2, "the reply, then topic phrases")
    }
}
