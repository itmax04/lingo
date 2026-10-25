// Перенесено из Interview Copilot (`Sources/CopilotCore/LLM/KeyVerifier.swift`, коммит cf0e764) с адаптацией:
// провайдеры R-30, список моделей `GET /models` (R-30) — только чат-модели.
import Foundation

/// Результат «Проверить» (R-30, R-44). Значение ключа в результат не попадает.
public enum KeyCheckResult: Equatable, Sendable {
    case ok(models: [String])
    /// 400/401/403 — «недействителен» (R-29).
    case invalidKey(status: Int, message: String)
    case failed(message: String)

    public var summary: String {
        switch self {
        case .ok(let models): "Ключ работает · моделей: \(models.count)"
        case .invalidKey(let status, let message): "Ключ недействителен (HTTP \(status))" + (message.isEmpty ? "" : ": \(message)")
        case .failed(let message): "Ошибка: \(message)"
        }
    }
}

public struct KeyVerifier: Sendable {
    let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func verify(_ provider: ProviderID, key: String, customBase: URL? = nil) async -> KeyCheckResult {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return .failed(message: "нет ключа") }
        guard let request = ProviderEndpoints.listModels(provider, key: key, customBase: customBase) else {
            return .failed(message: "не задан адрес API (https://…/v1)")
        }
        do {
            let (data, response) = try await transport.data(for: request)
            switch response.statusCode {
            case 200..<300:
                return .ok(models: Self.chatModels(provider, Self.parseModelIDs(data, json: true)))
            case 400, 401, 403:
                return .invalidKey(status: response.statusCode, message: Self.errorMessage(data, redacting: key))
            case 429:
                return .failed(message: "лимит запросов (HTTP 429), повторите позже")
            default:
                let detail = Self.errorMessage(data, redacting: key)
                return .failed(message: "HTTP \(response.statusCode)" + (detail.isEmpty ? "" : ": \(detail)"))
            }
        } catch let error as URLError {
            return .failed(message: "сеть: \(error.code == .timedOut ? "таймаут" : error.localizedDescription)")
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    /// `data[].id`; у Groq неактивные модели (`active: false`) пропускаются.
    static func parseModelIDs(_ data: Data, json: Bool) -> [(id: String, meta: [String: Any])] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        let models = obj["data"] as? [[String: Any]] ?? []
        return models.compactMap { m in
            guard let id = m["id"] as? String else { return nil }
            if let active = m["active"] as? Bool, !active { return nil }
            return (id, m)
        }
    }

    /// Только модели для диалога: без распознавания речи, синтеза, модерации и эмбеддингов.
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

    /// Текст ошибки провайдера без значения ключа, не длиннее 160 символов.
    static func errorMessage(_ data: Data, redacting key: String) -> String {
        var message = ""
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any], let m = error["message"] as? String { message = m }
            else if let m = json["message"] as? String { message = m }
        }
        return String(SSE.redact(message, key: key).prefix(160))
    }
}
