import Foundation
import Testing
@testable import LingoCore

/// Answers by path: `/models` and `/chat/completions` each have their own status; remembers the requests.
final class ScriptedTransport: HTTPTransport, @unchecked Sendable {
    let modelsStatus: Int, chatStatus: Int, chatBody: String
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { _requests } }
    init(models: Int, chat: Int, chatBody: String = "{}") { modelsStatus = models; chatStatus = chat; self.chatBody = chatBody }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { _requests.append(request) }
        let isModels = request.url!.path.hasSuffix("/models")
        let status = isModels ? modelsStatus : chatStatus
        let body = isModels ? "{}" : chatBody
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: [:])!)
    }
}

@Suite struct KeyCheckTests {
    let base = URL(string: "https://example.test/v1")
    static let completion = #"{"choices":[{"message":{"content":"p"}}]}"#

    @Test func customEndpointWithoutModelListIsVerifiedByAOneTokenRequest() async throws {
        let t = ScriptedTransport(models: 404, chat: 200, chatBody: Self.completion)
        let r = await KeyVerifier(transport: t).verify(.custom, key: "k-secret", customBase: base, probeModel: "my-model")
        #expect(r == .okWithoutModelList(model: "my-model"))
        let probe = try #require(t.requests.last)
        #expect(probe.httpMethod == "POST" && probe.url?.path == "/v1/chat/completions")
        let body = try JSONSerialization.jsonObject(with: probe.httpBody!) as! [String: Any]
        #expect(body["max_tokens"] as? Int == 1 && body["stream"] as? Bool == false && body["model"] as? String == "my-model")
        #expect(t.requests.count == 2)
    }

    @Test func status405IsTreatedLike404AndBadKeyIsInvalid() async {
        #expect(await KeyVerifier(transport: ScriptedTransport(models: 405, chat: 200, chatBody: Self.completion)).verify(.custom, key: "k", customBase: base, probeModel: "m") == .okWithoutModelList(model: "m"))
        let bad = await KeyVerifier(transport: ScriptedTransport(models: 404, chat: 401, chatBody: #"{"error":{"message":"bad key k-secret"}}"#))
            .verify(.custom, key: "k-secret", customBase: base, probeModel: "m")
        #expect(bad == .invalidKey(status: 401, message: "bad key [key]"))
    }

    @Test func withoutAModelThereIsNothingToProbe() async {
        let t = ScriptedTransport(models: 404, chat: 200)
        if case .failed = await KeyVerifier(transport: t).verify(.custom, key: "k", customBase: base, probeModel: nil) {} else { Issue.record("expected failed") }
        #expect(t.requests.count == 1)  // only GET /models, no chat request without a model
    }

    /// A key of another provider must never be sent to the custom address, even when a custom address is configured.
    @Test(arguments: [404, 405], [ProviderID.groq, .mistral, .openrouter])
    func otherProvidersKeysAreNeverProbedAtTheCustomHost(status: Int, provider: ProviderID) async {
        let t = ScriptedTransport(models: status, chat: 200, chatBody: Self.completion)
        let r = await KeyVerifier(transport: t).verify(provider, key: "groq-secret", customBase: base, probeModel: "m")
        if case .failed(let m) = r { #expect(m.hasPrefix("HTTP \(status)")) } else { Issue.record("expected failed, got \(r)") }
        #expect(t.requests.count == 1)
        #expect(t.requests.allSatisfy { $0.url?.host != "example.test" })
    }

    @Test func probeNeedsAChatCompletionAndAWrongModelDoesNotInvalidateTheKey() async {
        let html = await KeyVerifier(transport: ScriptedTransport(models: 404, chat: 200, chatBody: "<html>ok</html>")).verify(.custom, key: "k", customBase: base, probeModel: "m")
        if case .failed = html {} else { Issue.record("a catch-all 200 must not validate the key") }
        let wrongModel = await KeyVerifier(transport: ScriptedTransport(models: 404, chat: 400, chatBody: #"{"error":{"message":"unknown model"}}"#)).verify(.custom, key: "k", customBase: base, probeModel: "m")
        if case .failed(let m) = wrongModel { #expect(m.contains("unknown model")) } else { Issue.record("a 400 on the probe is not an invalid key") }
    }

    @Test func modelListStillWinsWhenTheEndpointHasOne() async {
        let t = ScriptedTransport(models: 200, chat: 500)
        let r = await KeyVerifier(transport: t).verify(.custom, key: "k", customBase: base, probeModel: "m")
        if case .ok = r {} else { Issue.record("expected ok") }
        #expect(t.requests.count == 1)
    }
}

@Suite struct KeyPoolTests {
    private func key(_ id: String, org: String?, invalid: Bool = false) -> KeyRecord {
        KeyRecord(id: id, provider: .groq, last4: "0000", invalid: invalid, organization: org)
    }
    private func settings(_ keys: [KeyRecord]) -> LLMSettings {
        var s = LLMSettings()
        s.keys = keys
        return s
    }

    @Test func unlabeledKeysAndTheMainOrganizationAreOnePool() {
        let s = settings([key("a", org: nil), key("b", org: ""), key("c", org: "  ")])
        #expect(Set(s.keys.map { s.poolID(of: $0) }) == ["groq:main"])
        #expect(s.keys.allSatisfy { !s.isOwnerRisk($0) })
    }

    @Test func labelsGroupCaseInsensitivelyAndExtraOrganizationsAreOwnerRisk() {
        let s = settings([key("a", org: "Main"), key("b", org: "main "), key("c", org: "Second"), key("d", org: "second"), key("e", org: nil)])
        #expect(s.poolID(of: s.keys[0]) == s.poolID(of: s.keys[1]))
        #expect(s.poolID(of: s.keys[2]) == s.poolID(of: s.keys[3]) && s.poolID(of: s.keys[2]) != s.poolID(of: s.keys[0]))
        #expect(s.keys.map { s.isOwnerRisk($0) } == [false, false, true, true, false == (s.mainOrganization(for: .groq) == "") ? false : true])
        #expect(s.poolID(of: s.keys[4]) == s.poolID(of: s.keys[0]))  // unlabeled = main organization
    }

    @Test func chainOrdersMainFirstAndKeepsTheNumbersShownInSettings() throws {
        var s = settings([key("a", org: "main"), key("b", org: "second"), key("c", org: "main")])
        s.chain = [ChainEntry(provider: .groq, model: "m")]
        let store = InMemorySecretStore()
        for id in ["a", "b", "c"] { try store.set("v-\(id)", for: id, label: id) }
        let chain = ChainFactory.chain(settings: s, secrets: store, health: ProviderHealth())
        #expect(chain.steps.map(\.info.keyID) == ["a", "c", "b"])
        #expect(chain.steps.map(\.info.keyIndex) == [1, 3, 2])
        #expect(chain.steps[0].info.poolID == chain.steps[1].info.poolID && chain.steps[0].info.poolID != chain.steps[2].info.poolID)
    }

    @Test func aRateLimitPausesTheWholeOrganizationButNotAnotherOne() {
        let health = ProviderHealth()
        let a = StepInfo(provider: .groq, model: "m", keyID: "a", keyIndex: 1, poolID: "groq:main")
        let c = StepInfo(provider: .groq, model: "m", keyID: "c", keyIndex: 3, poolID: "groq:main")
        let b = StepInfo(provider: .groq, model: "m", keyID: "b", keyIndex: 2, poolID: "groq:second")
        health.reportFailure(a, .http(status: 429, message: "limit"))
        #expect(health.pause(for: c) != nil)   // same organization: no second key to multiply the limit
        #expect(health.pause(for: b) == nil)   // another organization has its own ceiling (owner risk)
    }

    @Test func oldSettingsWithoutOrganizationStillDecode() throws {
        let json = #"{"id":"a","provider":"groq","last4":"1234","label":"","invalid":false,"addedAt":0}"#
        let k = try JSONDecoder().decode(KeyRecord.self, from: Data(json.utf8))
        #expect(k.organization == nil && k.organizationName == "")
    }
}
