// Перенесено из Interview Copilot (`Sources/CopilotCore/LLM/LLMProvider.swift`, коммит cf0e764) с адаптацией по R-29:
// без изображений и Anthropic/Gemini; в ошибке HTTP сохраняется `retry-after`.
import Foundation

/// Сообщение для модели.
public struct LLMMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case user, assistant }
    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// Назначение запроса — влияет на параметры.
public enum LLMPurpose: String, Sendable {
    /// Ход диалога (R-24): ответ по протоколу.
    case dialog
    /// Краткое содержание сессии (R-04).
    case summary
    /// Фразы темы для подсказок (R-27).
    case topicPhrases
    /// Итог сессии (R-23).
    case recap
    /// Судья evals (evals/README.md).
    case judge
}

public struct LLMRequest: Sendable, Equatable {
    public var system: String
    public var messages: [LLMMessage]
    public var maxTokens: Int
    public var purpose: LLMPurpose
    public var temperature: Double?

    public init(system: String, messages: [LLMMessage], maxTokens: Int, purpose: LLMPurpose, temperature: Double? = nil) {
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
        self.purpose = purpose
        self.temperature = temperature
    }
}

public struct TokenUsage: Sendable, Equatable {
    public var input: Int
    public var output: Int

    public init(input: Int = 0, output: Int = 0) {
        self.input = input
        self.output = output
    }
}

/// События потока от провайдера.
public enum LLMEvent: Sendable, Equatable {
    case model(String)
    case text(String)
    case usage(TokenUsage)
    case done(stopReason: String?)
}

public enum LLMError: Error, Equatable, CustomStringConvertible {
    /// `retryAfter` — секунды из заголовка `retry-after` (R-29).
    case http(status: Int, message: String, retryAfter: Double? = nil)
    case network(String)
    /// Первый токен не пришёл за отведённое время (R-29: 6 с, настраивается 2–15).
    case firstTokenTimeout
    /// Модель отказалась (`finish_reason = content_filter`).
    case refusal(String?)
    case noKey
    case cancelled
    case badResponse(String)

    public var status: Int? {
        if case .http(let s, _, _) = self { return s }
        return nil
    }

    /// Неверный ключ (R-29): 401/403 — всегда; 400 — если текст ошибки говорит о ключе (D-09).
    public var isInvalidKey: Bool {
        guard case .http(let s, let m, _) = self else { return false }
        if s == 401 || s == 403 { return true }
        if s == 400 {
            let t = m.lowercased()
            return t.contains("api key") || t.contains("api_key") || t.contains("apikey") || t.contains("authentication")
                || t.contains("unauthorized") || t.contains("invalid key")
        }
        return false
    }

    /// Переход к следующему шагу цепочки (R-29). Отмена — не ошибка цепочки.
    public var triggersFallback: Bool { self != .cancelled }

    public var description: String {
        switch self {
        case .http(429, _, _): "лимит запросов (429)"
        case .http(let s, let m, _) where s == 401 || s == 403: "ключ недействителен (HTTP \(s))" + (m.isEmpty ? "" : ": \(m)")
        case .http(400, let m, _): "неверный запрос или ключ (HTTP 400)" + (m.isEmpty ? "" : ": \(m)")
        case .http(402, _, _): "нужна оплата (402)"
        case .http(let s, let m, _): "HTTP \(s)" + (m.isEmpty ? "" : ": \(m)")
        case .network(let m): "сеть: \(m)"
        case .firstTokenTimeout: "нет ответа за отведённое время"
        case .refusal(let c): "модель отказалась отвечать" + (c.map { " (\($0))" } ?? "")
        case .noKey: "нет ключа"
        case .cancelled: "отменено"
        case .badResponse(let m): "неожиданный ответ: \(m)"
        }
    }
}

/// Провайдер языковой модели: свой HTTP-клиент с SSE, без SDK.
public protocol LLMProvider: Sendable {
    var id: ProviderID { get }
    func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error>
}
