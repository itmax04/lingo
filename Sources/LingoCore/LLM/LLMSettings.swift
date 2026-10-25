import Foundation

/// Описание ключа (R-44). Значение ключа здесь не хранится — только в Keychain под `id` (R-48).
public struct KeyRecord: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var provider: ProviderID
    /// Последние 4 символа — единственное, что показывается после сохранения (R-48).
    public var last4: String
    public var label: String
    /// Ключ выключен после 400/401/403 (R-29). Пользователь может включить снова кнопкой «Проверить».
    public var invalid: Bool
    public var invalidReason: String?
    public var addedAt: Date

    public init(id: String = UUID().uuidString, provider: ProviderID, last4: String, label: String = "",
                invalid: Bool = false, invalidReason: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.provider = provider
        self.last4 = last4
        self.label = label
        self.invalid = invalid
        self.invalidReason = invalidReason
        self.addedAt = addedAt
    }

    public static func last4(of key: String) -> String {
        String(key.trimmingCharacters(in: .whitespacesAndNewlines).suffix(4))
    }
}

/// Элемент порядка цепочки: провайдер + модель. Ключи подставляются при сборке (R-29: провайдер → модель → ключ).
public struct ChainEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var provider: ProviderID
    public var model: String
    public var enabled: Bool

    public init(id: String = UUID().uuidString, provider: ProviderID, model: String, enabled: Bool = true) {
        self.id = id
        self.provider = provider
        self.model = model
        self.enabled = enabled
    }
}

/// Настройки моделей (R-29, R-30, R-44).
public struct LLMSettings: Codable, Sendable, Hashable {
    public var keys: [KeyRecord]
    public var chain: [ChainEntry]
    /// Таймаут первого токена, с (R-29: 6, от 2 до 15).
    public var firstTokenTimeout: Double
    public var customBaseURL: String
    /// Модели, полученные `GET /models` (R-30), по провайдерам — для выбора в настройках.
    public var knownModels: [ProviderID: [String]]
    public var knownModelsAt: [ProviderID: Date]

    public static let timeoutRange: ClosedRange<Double> = 2...15

    /// Порядок по умолчанию (P-00: бесплатные чат-модели Groq по console.groq.com/docs/rate-limits, 2026-10-25;
    /// Mistral — `mistral-small-latest` из docs.mistral.ai quickstart; OpenRouter — `:free` из `GET /api/v1/models`).
    /// Уточняется по `GET /models` и eval `dialog` (P-03, P-05).
    public static let defaultChain: [ChainEntry] = [
        ChainEntry(provider: .groq, model: "openai/gpt-oss-120b"),
        ChainEntry(provider: .groq, model: "qwen/qwen3.8-27b"),
        ChainEntry(provider: .groq, model: "openai/gpt-oss-20b"),
        ChainEntry(provider: .mistral, model: "mistral-small-latest"),
        ChainEntry(provider: .openrouter, model: "google/gemma-4-31b-it:free"),
    ]

    public init(keys: [KeyRecord] = [], chain: [ChainEntry] = LLMSettings.defaultChain, firstTokenTimeout: Double = 6,
                customBaseURL: String = "", knownModels: [ProviderID: [String]] = [:], knownModelsAt: [ProviderID: Date] = [:]) {
        self.keys = keys
        self.chain = chain
        self.firstTokenTimeout = firstTokenTimeout
        self.customBaseURL = customBaseURL
        self.knownModels = knownModels
        self.knownModelsAt = knownModelsAt
    }

    enum CodingKeys: String, CodingKey { case keys, chain, firstTokenTimeout, customBaseURL, knownModels, knownModelsAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keys = (try? c.decodeIfPresent([KeyRecord].self, forKey: .keys)) ?? []
        chain = (try? c.decodeIfPresent([ChainEntry].self, forKey: .chain)) ?? LLMSettings.defaultChain
        firstTokenTimeout = (try? c.decodeIfPresent(Double.self, forKey: .firstTokenTimeout)) ?? 6
        customBaseURL = (try? c.decodeIfPresent(String.self, forKey: .customBaseURL)) ?? ""
        knownModels = (try? c.decodeIfPresent([ProviderID: [String]].self, forKey: .knownModels)) ?? [:]
        knownModelsAt = (try? c.decodeIfPresent([ProviderID: Date].self, forKey: .knownModelsAt)) ?? [:]
    }

    public var customBase: URL? { ProviderEndpoints.customBaseURL(customBaseURL) }

    /// Метка первого доступного шага для плашки источника (R-32).
    public var primaryLabel: String? {
        for e in chain where e.enabled && keys.contains(where: { $0.provider == e.provider && !$0.invalid }) {
            return StepInfo(provider: e.provider, model: e.model, keyID: "").label
        }
        return nil
    }

    public func keys(for p: ProviderID) -> [KeyRecord] { keys.filter { $0.provider == p } }

    /// Есть ли хоть один действующий ключ — иначе голос неактивен (R-45).
    public var hasUsableKey: Bool {
        chain.contains { e in e.enabled && keys.contains { $0.provider == e.provider && !$0.invalid } }
    }

    public mutating func markInvalid(keyID: String, reason: String) {
        guard let i = keys.firstIndex(where: { $0.id == keyID }) else { return }
        keys[i].invalid = true
        keys[i].invalidReason = reason
    }
}
