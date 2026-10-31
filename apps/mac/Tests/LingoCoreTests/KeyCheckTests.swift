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

    @Test func customEndpointWithoutModelListIsVerifiedByAOneTokenRequest() async throws {
        let t = ScriptedTransport(models: 404, chat: 200)
        let r = await KeyVerifier(transport: t).verify(.custom, key: "k-secret", customBase: base, probeModel: "my-model")
        #expect(r == .okWithoutModelList(model: "my-model"))
        let probe = try #require(t.requests.last)
        #expect(probe.httpMethod == "POST" && probe.url?.path == "/v1/chat/completions")
        let body = try JSONSerialization.jsonObject(with: probe.httpBody!) as! [String: Any]
        #expect(body["max_tokens"] as? Int == 1 && body["stream"] as? Bool == false && body["model"] as? String == "my-model")
        #expect(t.requests.count == 2)
    }

    @Test func status405IsTreatedLike404AndBadKeyIsInvalid() async {
        #expect(await KeyVerifier(transport: ScriptedTransport(models: 405, chat: 200)).verify(.custom, key: "k", customBase: base, probeModel: "m") == .okWithoutModelList(model: "m"))
        let bad = await KeyVerifier(transport: ScriptedTransport(models: 404, chat: 401, chatBody: #"{"error":{"message":"bad key k-secret"}}"#))
            .verify(.custom, key: "k-secret", customBase: base, probeModel: "m")
        #expect(bad == .invalidKey(status: 401, message: "bad key [key]"))
    }

    @Test func withoutAModelThereIsNothingToProbeAndOtherProvidersAreNotProbed() async {
        let t = ScriptedTransport(models: 404, chat: 200)
        if case .failed = await KeyVerifier(transport: t).verify(.custom, key: "k", customBase: base, probeModel: nil) {} else { Issue.record("expected failed") }
        #expect(t.requests.count == 1)  // only GET /models, no chat request without a model
        let groq = ScriptedTransport(models: 404, chat: 200)
        if case .failed = await KeyVerifier(transport: groq).verify(.groq, key: "k", probeModel: "m") {} else { Issue.record("expected failed") }
        #expect(groq.requests.count == 1)
    }

    @Test func modelListStillWinsWhenTheEndpointHasOne() async {
        let t = ScriptedTransport(models: 200, chat: 500)
        let r = await KeyVerifier(transport: t).verify(.custom, key: "k", customBase: base, probeModel: "m")
        if case .ok = r {} else { Issue.record("expected ok") }
        #expect(t.requests.count == 1)
    }
}
