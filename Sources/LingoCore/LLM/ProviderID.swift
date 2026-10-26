// Endpoints from the primary sources as of 2026-10-25 (handoff.md, P-00): console.groq.com/docs, docs.mistral.ai, openrouter.ai/docs.
// Modelled on Interview Copilot (`ProviderEndpoints.swift`, commit cf0e764).
import Foundation

/// R-30 providers: free only, OpenAI-compatible Chat Completions. Gemini is not used (EU).
public enum ProviderID: String, Codable, CaseIterable, Sendable, Hashable {
    case groq
    case mistral
    case openrouter
    /// A custom OpenAI-compatible endpoint.
    case custom

    public var displayName: String {
        switch self {
        case .groq: "Groq"
        case .mistral: "Mistral"
        case .openrouter: "OpenRouter"
        case .custom: String(localized: "Custom endpoint")
        }
    }

    /// Where to get a free key (for the onboarding wizard and H-1).
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

    /// `customBase` — from settings; without it no requests are sent to the custom endpoint.
    public static func base(_ p: ProviderID, customBase: URL?) -> URL? {
        switch p {
        case .groq: groqBase
        case .mistral: mistralBase
        case .openrouter: openrouterBase
        case .custom: customBase
        }
    }

    /// Custom endpoint: HTTPS; HTTP only for this computer (Ollama, LM Studio), otherwise the key would travel in plain text (R-48).
    /// A trailing "/" and `/chat/completions` are stripped.
    public static func customBaseURL(_ text: String) -> URL? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in ["/chat/completions", "/"] where t.hasSuffix(suffix) { t = String(t.dropLast(suffix.count)) }
        guard let url = URL(string: t), let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), !host.isEmpty
        else { return nil }
        if scheme == "https" { return url }
        if scheme == "http", ["localhost", "127.0.0.1", "::1"].contains(host) { return url }
        return nil
    }

    /// The key goes only in a header over HTTPS (R-48).
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
