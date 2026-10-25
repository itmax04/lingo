// Адреса — по первоисточникам на 2026-10-25 (handoff.md, P-00): console.groq.com/docs, docs.mistral.ai, openrouter.ai/docs.
// По образцу Interview Copilot (`ProviderEndpoints.swift`, коммит cf0e764).
import Foundation

/// Провайдеры R-30: только бесплатные, OpenAI-совместимый Chat Completions. Gemini не используется (ЕС).
public enum ProviderID: String, Codable, CaseIterable, Sendable, Hashable {
    case groq
    case mistral
    case openrouter
    /// Свой OpenAI-совместимый адрес.
    case custom

    public var displayName: String {
        switch self {
        case .groq: "Groq"
        case .mistral: "Mistral"
        case .openrouter: "OpenRouter"
        case .custom: "Свой адрес"
        }
    }

    /// Где получить бесплатный ключ (для мастера первого запуска и H-1).
    public var keysPage: String? {
        switch self {
        case .groq: "https://console.groq.com/keys"
        case .mistral: "https://console.mistral.ai/api-keys"
        case .openrouter: "https://openrouter.ai/settings/keys"
        case .custom: nil
        }
    }
}

public enum ProviderEndpoints {
    public static let groqBase = URL(string: "https://api.groq.com/openai/v1")!
    public static let mistralBase = URL(string: "https://api.mistral.ai/v1")!
    public static let openrouterBase = URL(string: "https://openrouter.ai/api/v1")!

    /// `customBase` — из настроек; без него запросы к «своему адресу» не отправляются.
    public static func base(_ p: ProviderID, customBase: URL?) -> URL? {
        switch p {
        case .groq: groqBase
        case .mistral: mistralBase
        case .openrouter: openrouterBase
        case .custom: customBase
        }
    }

    /// Свой адрес: HTTPS; HTTP — только для этого компьютера (Ollama, LM Studio), иначе ключ ушёл бы открытым текстом (R-48).
    /// Завершающий «/» и `/chat/completions` отрезаются.
    public static func customBaseURL(_ text: String) -> URL? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["/chat/completions", "/"] where t.hasSuffix(suffix) { t = String(t.dropLast(suffix.count)) }
        guard let url = URL(string: t), let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty
        else { return nil }
        if scheme == "https" { return url }
        if scheme == "http", ["localhost", "127.0.0.1", "::1"].contains(host) { return url }
        return nil
    }

    /// Ключ — только в заголовке по HTTPS (R-48).
    public static func authorize(_ r: inout URLRequest, key: String) {
        r.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    }

    public static func listModels(_ p: ProviderID, key: String, customBase: URL?) -> URLRequest? {
        guard let base = base(p, customBase: customBase) else { return nil }
        var r = URLRequest(url: base.appendingPathComponent("models"))
        r.httpMethod = "GET"
        r.timeoutInterval = 15
        authorize(&r, key: key)
        return r
    }
}
