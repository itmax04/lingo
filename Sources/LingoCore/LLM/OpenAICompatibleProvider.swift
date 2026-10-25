// Перенесено из Interview Copilot (`Sources/CopilotCore/LLM/Providers.swift`, `OpenAICompatibleProvider`, коммит cf0e764)
// с адаптацией: провайдеры R-30 (Groq, Mistral, OpenRouter, свой адрес), без изображений.
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

    /// Рассуждающие модели семейства GPT-OSS: рассуждение коротко и не в ответе.
    static func isReasoning(_ model: String) -> Bool { model.contains("gpt-oss") }

    public func makeRequest(_ request: LLMRequest, model: String, key: String) throws -> URLRequest {
        guard let base = ProviderEndpoints.base(id, customBase: customBase) else {
            throw LLMError.badResponse("Свой адрес: не задан (Настройки → Ключи и модели)")
        }
        var r = URLRequest(url: base.appendingPathComponent("chat/completions"))
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        ProviderEndpoints.authorize(&r, key: key)
        if id == .openrouter {
            // Необязательные заголовки атрибуции OpenRouter; без личных данных.
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
                body["max_completion_tokens"] = request.maxTokens + 1024
            } else {
                if model.lowercased().contains("qwen") { body["reasoning_effort"] = "none" }
                body["max_completion_tokens"] = request.maxTokens
            }
        case .mistral, .openrouter, .custom:
            // Общие параметры Chat Completions.
            body["max_tokens"] = request.maxTokens + (reasoning ? 1024 : 0)
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
                    let events = try await SSE.open(try makeRequest(request, model: model, key: key), transport: transport, key: key)
                    var usage = TokenUsage()
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
                            usage.input = u["prompt_tokens"] as? Int ?? usage.input
                            usage.output = u["completion_tokens"] as? Int ?? usage.output
                        }
                    }
                    continuation.yield(.usage(usage))
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
