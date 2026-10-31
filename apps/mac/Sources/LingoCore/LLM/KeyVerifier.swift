// Ported from Interview Copilot (`Sources/CopilotCore/LLM/KeyVerifier.swift`, commit cf0e764) and adapted:
// R-30 providers, the model list from `GET /models` (R-30) — chat models only.
import Foundation

/// Result of "Check" (R-30, R-44). The key value never gets into the result.
public enum KeyCheckResult: Equatable, Sendable {
    case ok(models: [String])
    /// The custom endpoint has no `GET /models` (404/405), but a one-token chat request with `model` was accepted (MR-06).
    case okWithoutModelList(model: String)
    /// 400/401/403 — "invalid" (R-29).
    case invalidKey(status: Int, message: String)
    case failed(message: String)

    public var summary: String {
        switch self {
        case .ok(let models): String(localized: "Key works · models: \(models.count)")
        case .okWithoutModelList(let model): String(localized: "Key works · no model list at this endpoint (checked with a one-token request to \(model))")
        case .invalidKey(let status, let message): String(localized: "Invalid key (HTTP \(status))") + (message.isEmpty ? "" : ": \(message)")
        case .failed(let message): String(localized: "Error: \(message)")
        }
    }
}

public struct KeyVerifier: Sendable {
    let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// `probeModel` is the model of the custom endpoint's chain step; it is used only when `GET /models` answers 404/405.
    public func verify(_ provider: ProviderID, key: String, customBase: URL? = nil, probeModel: String? = nil) async -> KeyCheckResult {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return .failed(message: String(localized: "no key")) }
        guard let request = ProviderEndpoints.listModels(provider, key: key, customBase: customBase) else {
            return .failed(message: String(localized: "API address is not set (https://…/v1)"))
        }
        do {
            let (data, response) = try await transport.data(for: request)
            switch response.statusCode {
            case 200..<300:
                return .ok(models: Self.chatModels(provider, Self.parseModelIDs(data, json: true)))
            case 400, 401, 403:
                return .invalidKey(status: response.statusCode, message: Self.errorMessage(data, redacting: key))
            case 404 where provider == .custom, 405 where provider == .custom:
                // Only the custom endpoint ever receives the probe; another provider's key must never be sent to the custom address.
                return await probe(key: key, customBase: customBase, model: probeModel)
            case 429:
                return .failed(message: String(localized: "rate limit (HTTP 429), try again later"))
            default:
                let detail = Self.errorMessage(data, redacting: key)
                return .failed(message: "HTTP \(response.statusCode)" + (detail.isEmpty ? "" : ": \(detail)"))
            }
        } catch let error as URLError {
            return .failed(message: String(localized: "network: \(error.code == .timedOut ? String(localized: "timeout") : error.localizedDescription)"))
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    /// One-token chat request for endpoints without a model list. Only the status is used; the reply text is never read or stored.
    func probe(key: String, customBase: URL?, model: String?, provider: ProviderID = .custom) async -> KeyCheckResult {
        guard provider == .custom else { return .failed(message: "internal: probe is for the custom endpoint only") }
        guard let model = model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty else {
            return .failed(message: String(localized: "this endpoint has no model list; add a model to the custom chain step to check the key"))
        }
        guard let base = ProviderEndpoints.base(.custom, customBase: customBase) else {
            return .failed(message: String(localized: "API address is not set (https://…/v1)"))
        }
        var r = URLRequest(url: base.appendingPathComponent("chat/completions"))
        r.httpMethod = "POST"
        r.timeoutInterval = 20
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        ProviderEndpoints.authorize(&r, key: key)
        let body: [String: Any] = ["model": model, "messages": [["role": "user", "content": "ping"]], "max_tokens": 1, "stream": false]
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await transport.data(for: r)
            switch response.statusCode {
            case 200..<300:
                // A catch-all page that answers 200 is not a chat endpoint: require a chat-completion shaped body.
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["choices"] is [Any] else {
                    return .failed(message: String(localized: "the endpoint answered, but not with a chat completion"))
                }
                return .okWithoutModelList(model: model)
            case 401, 403: return .invalidKey(status: response.statusCode, message: Self.errorMessage(data, redacting: key))
            case 400, 404, 422:
                // Most likely a wrong model name or path: say so, but do not mark the key invalid.
                let detail = Self.errorMessage(data, redacting: key)
                return .failed(message: "HTTP \(response.statusCode)" + (detail.isEmpty ? "" : ": \(detail)") + " — " + String(localized: "check the model name of the custom chain step"))
            case 429: return .failed(message: String(localized: "rate limit (HTTP 429), try again later"))
            default:
                let detail = Self.errorMessage(data, redacting: key)
                return .failed(message: "HTTP \(response.statusCode)" + (detail.isEmpty ? "" : ": \(detail)"))
            }
        } catch let error as URLError {
            return .failed(message: String(localized: "network: \(error.code == .timedOut ? String(localized: "timeout") : error.localizedDescription)"))
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    /// `data[].id`; inactive Groq models (`active: false`) are skipped.
    static func parseModelIDs(_ data: Data, json: Bool) -> [(id: String, meta: [String: Any])] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let models = obj["data"] as? [[String: Any]] ?? []
        return models.compactMap { m in
            guard let id = m["id"] as? String else { return nil }
            if let active = m["active"] as? Bool, !active { return nil }
            return (id, m)
        }
    }

    /// Dialogue models only: no speech recognition, synthesis, moderation or embeddings.
    static func chatModels(_ p: ProviderID, _ list: [(id: String, meta: [String: Any])]) -> [String] {
        let excluded = ["whisper", "tts", "orpheus", "guard", "safeguard", "embed", "moderation", "distil", "playai", "ocr", "transcribe"]
        return list.filter { m in
            let id = m.id.lowercased()
            if excluded.contains(where: { id.contains($0) }) { return false }
            if p == .openrouter { return id.hasSuffix(":free") }
            if p == .mistral, let caps = m.meta["capabilities"] as? [String: Any], let chat = caps["completion_chat"] as? Bool { return chat }
            return true
        }.map(\.id).sorted()
    }

    /// Provider error text without the key value, at most 160 characters.
    static func errorMessage(_ data: Data, redacting key: String) -> String {
        var message = ""
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let m = error["message"] as? String { message = m }
            else if let m = json["message"] as? String { message = m }
        }
        return String(SSE.redact(message, key: key).prefix(160))
    }
}
