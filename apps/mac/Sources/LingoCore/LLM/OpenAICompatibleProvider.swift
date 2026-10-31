// Ported from Interview Copilot (`Sources/CopilotCore/LLM/Providers.swift`, `OpenAICompatibleProvider`, commit cf0e764)
// and adapted: R-30 providers (Groq, Mistral, OpenRouter, custom endpoint), no images.
import Foundation

public struct OpenAICompatibleProvider: LLMProvider {
    public let id: ProviderID
    let transport: StreamingTransport
    let customBase: URL?

    public init(_ id: ProviderID, transport: StreamingTransport = URLSessionTransport(), customBase: URL? = nil) {
        self.id = id
        self.transport = transport
        self.customBase = customBase
    }

    /// Reasoning models of the GPT-OSS family: reasoning is short and not part of the reply.
    static func isReasoning(_ model: String) -> Bool { model.contains("gpt-oss") }

    public func makeRequest(_ request: LLMRequest, model: String, key: String) throws -> URLRequest {
        guard let base = ProviderEndpoints.base(id, customBase: customBase) else {
            throw LLMError.badResponse(String(localized: "Custom endpoint: not set (Settings → Keys and models)"))
        }
        var r = URLRequest(url: base.appendingPathComponent("chat/completions"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        ProviderEndpoints.authorize(&r, key: key)
        if id == .openrouter {
            // Optional OpenRouter attribution headers; no personal data.
            r.setValue("Lingo", forHTTPHeaderField: "X-Title")
        }
        var messages: [[String: Any]] = [["role": "system", "content": request.system]]
        for m in request.messages { messages.append(["role": m.role.rawValue, "content": m.text]) }
        var body: [String: Any] = ["model": model, "messages": messages, "stream": true]
        let reasoning = Self.isReasoning(model)
        switch id {
        case .groq:
            if reasoning {
                body["reasoning_effort"] = "low"
                body["include_reasoning"] = false
                // Headroom for short reasoning: Groq counts max_completion_tokens against the tokens-per-minute limit (P-05).
                body["max_completion_tokens"] = request.maxTokens + 512
            } else {
                if model.lowercased().contains("qwen") { body["reasoning_effort"] = "none" }
                body["max_completion_tokens"] = request.maxTokens
            }
        case .mistral, .openrouter, .custom:
            // Common Chat Completions parameters.
            body["max_tokens"] = request.maxTokens + (reasoning ? 512 : 0)
            if reasoning { body["reasoning_effort"] = "low" }
        }
        if let t = request.temperature { body["temperature"] = t }
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return r
    }

    public func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (limits, events) = try await SSE.openWithHeaders(try makeRequest(request, model: model, key: key), transport: transport, key: key)
                    if !limits.isEmpty { continuation.yield(.rateLimits(limits)) }
                    var usage: TokenUsage?
                    var stop: String?
                    var announced = false
                    for try await e in events {
                        if e.data == "[DONE]" { break }
                        guard let json = SSE.json(e.data) else { continue }
                        if let error = json["error"] as? [String: Any] {
                            throw LLMError.http(status: (error["code"] as? Int) ?? 503,
                                                message: SSE.redact(error["message"] as? String ?? "stream error", key: key))
                        }
                        if !announced { continuation.yield(.model(json["model"] as? String ?? model)); announced = true }
                        for choice in json["choices"] as? [[String: Any]] ?? [] {
                            if let t = (choice["delta"] as? [String: Any])?["content"] as? String, !t.isEmpty {
                                continuation.yield(.text(t))
                            }
                            if let reason = choice["finish_reason"] as? String {
                                stop = reason
                                if reason == "content_filter" { throw LLMError.refusal(reason) }
                            }
                        }
                        let u = json["usage"] as? [String: Any] ?? (json["x_groq"] as? [String: Any])?["usage"] as? [String: Any]
                        if let u {
                            var x = usage ?? TokenUsage()
                            x.input = u["prompt_tokens"] as? Int ?? x.input
                            x.output = u["completion_tokens"] as? Int ?? x.output
                            if let d = u["prompt_tokens_details"] as? [String: Any], let c = d["cached_tokens"] as? Int { x.cached = c }
                            usage = x
                        }
                    }
                    // No usage — no usage record (an unknown value never becomes zero, R-52).
                    if let usage { continuation.yield(.usage(usage)) }
                    continuation.yield(.done(stopReason: stop))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
