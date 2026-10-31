// Ported from Interview Copilot (`Sources/CopilotCore/LLM/LLMProvider.swift`, commit cf0e764) and adapted per R-29:
// no images and no Anthropic/Gemini; the HTTP error keeps `retry-after`.
import Foundation

/// A message for the model.
public struct LLMMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case user, assistant }
    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// Request purpose — affects the parameters.
public enum LLMPurpose: String, Sendable {
    /// A dialogue turn (R-24): a reply in the protocol format.
    case dialog
    /// Session summary (R-04).
    case summary
    /// Topic phrases for hints (R-27).
    case topicPhrases
    /// Session recap (R-23).
    case recap
    /// Eval judge (evals/README.md).
    case judge
    /// "Translate to Russian" of one message, on the user's click.
    case translate
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
    /// Cached input tokens, if the provider reports them (on Groq they do not count toward limits).
    public var cached: Int?

    public init(input: Int = 0, output: Int = 0, cached: Int? = nil) {
        self.input = input
        self.output = output
        self.cached = cached
    }
}

/// Stream events from a provider.
public enum LLMEvent: Sendable, Equatable {
    case model(String)
    case text(String)
    case usage(TokenUsage)
    /// Remaining quota from the response headers (R-52).
    case rateLimits(RateLimitSnapshot)
    case done(stopReason: String?)
}

public enum LLMError: Error, Equatable, CustomStringConvertible {
    /// `retryAfter` — seconds from the `retry-after` header (R-29).
    case http(status: Int, message: String, retryAfter: Double? = nil)
    case network(String)
    /// The first token did not arrive in time (R-29: 6 s, configurable 2–15).
    case firstTokenTimeout
    /// The model refused (`finish_reason = content_filter`).
    case refusal(String?)
    case noKey
    case cancelled
    case badResponse(String)

    public var status: Int? {
        if case .http(let s, _, _) = self { return s }
        return nil
    }

    /// Kind of limit from the 429 text (R-52); nil — the provider did not say.
    public var rateLimitKind: RateLimitKind? {
        guard case .http(429, let m, _) = self else { return nil }
        return RateLimitKind.parse(m)
    }

    /// Time until retry: the `retry-after` header, otherwise "try again in …" from the text.
    public var retryAfterSeconds: Double? {
        guard case .http(_, let m, let ra) = self else { return nil }
        return ra ?? RateLimitKind.tryAgainSeconds(m)
    }

    /// Short status code for the usage log.
    public var usageStatus: String {
        switch self {
        case .http(let s, _, _): "http_\(s)"
        case .network: "network"
        case .firstTokenTimeout: "timeout"
        case .refusal: "refusal"
        case .cancelled: "cancelled"
        default: "other"
        }
    }

    /// Invalid key (R-29): 401/403 — always; 400 — if the error text mentions the key (D-09).
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

    /// Move on to the next chain step (R-29). Cancellation is not a chain error.
    public var triggersFallback: Bool { self != .cancelled }

    public var description: String {
        switch self {
        case .http(429, _, _):
            (rateLimitKind?.title ?? String(localized: "provider limit (429, kind not specified)"))
                + (retryAfterSeconds.map { " — " + String(localized: "retry in \(Self.human($0))") } ?? "")
        case .http(let s, let m, _) where s == 401 || s == 403: String(localized: "invalid key (HTTP \(s))") + (m.isEmpty ? "" : ": \(m)")
        case .http(400, let m, _): String(localized: "bad request or key (HTTP 400)") + (m.isEmpty ? "" : ": \(m)")
        case .http(402, _, _): String(localized: "payment required (402)")
        case .http(let s, let m, _): "HTTP \(s)" + (m.isEmpty ? "" : ": \(m)")
        case .network(let m): String(localized: "network: \(m)")
        case .firstTokenTimeout: String(localized: "no reply within the time limit")
        case .refusal(let c): String(localized: "the model refused to answer") + (c.map { " (\($0))" } ?? "")
        case .noKey: String(localized: "no key")
        case .cancelled: String(localized: "cancelled")
        case .badResponse(let m): String(localized: "unexpected response: \(m)")
        }
    }
}

/// A language model provider: its own HTTP client with SSE, no SDK.
extension LLMError {
    /// 7 s, 2 min, 1 h 5 min.
    public static func human(_ s: Double) -> String {
        if s < 90 { return String(localized: "\(max(1, Int(s.rounded()))) s") }
        if s < 3600 { return String(localized: "\(Int((s / 60).rounded())) min") }
        let h = Int(s / 3600), m = Int((s - Double(h) * 3600) / 60)
        return m > 0 ? String(localized: "\(h) h \(m) min") : String(localized: "\(h) h")
    }
}

public protocol LLMProvider: Sendable {
    var id: ProviderID { get }
    func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error>
}
