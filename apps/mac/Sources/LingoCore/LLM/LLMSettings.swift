import Foundation

/// Key description (R-44). The key value is not stored here — only in the Keychain under `id` (R-48).
public struct KeyRecord: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var provider: ProviderID
    /// The last 4 characters — the only thing shown after saving (R-48).
    public var last4: String
    public var label: String
    /// The key is disabled after 400/401/403 (R-29). The user can enable it again with the "Check" button.
    public var invalid: Bool
    public var invalidReason: String?
    public var addedAt: Date
    /// Organization (account) the key belongs to; nil or empty means the main organization (MR-07, ADR-0005 §1). Keys of one organization share one limit.
    public var organization: String?

    public init(id: String = UUID().uuidString, provider: ProviderID, last4: String, label: String = "",
                invalid: Bool = false, invalidReason: String? = nil, addedAt: Date = Date(), organization: String? = nil) {
        self.id = id
        self.provider = provider
        self.last4 = last4
        self.label = label
        self.invalid = invalid
        self.invalidReason = invalidReason
        self.addedAt = addedAt
        self.organization = organization
    }

    /// Normalised organization name used to group keys into pools: trimmed, case-insensitive; empty = unlabeled.
    public var organizationName: String { (organization ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    public static func last4(of key: String) -> String {
        String(key.trimmingCharacters(in: .whitespacesAndNewlines).suffix(4))
    }
}

/// Chain order item: provider + model. Keys are filled in when the chain is built (R-29: provider → model → key).
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

/// Model settings (R-29, R-30, R-44).
public struct LLMSettings: Codable, Sendable, Hashable {
    public var keys: [KeyRecord]
    public var chain: [ChainEntry]
    /// First-token timeout, s (R-29: 6, from 2 to 15).
    public var firstTokenTimeout: Double
    public var customBaseURL: String
    /// Models returned by `GET /models` (R-30), per provider — for selection in settings.
    public var knownModels: [ProviderID: [String]]
    public var knownModelsAt: [ProviderID: Date]
    /// Source badge (R-32): nil — "Auto (chain)", otherwise only this step (with all of its keys).
    public var pinnedEntryID: String?

    public static let timeoutRange: ClosedRange<Double> = 2...15

    /// Default order (P-00: free Groq chat models per console.groq.com/docs/rate-limits, 2026-10-25;
    /// Mistral — `mistral-small-latest` from the docs.mistral.ai quickstart; OpenRouter — `:free` from `GET /api/v1/models`).
    /// Refined by `GET /models` and the `dialog` eval (P-03, P-05).
    /// Order (Q29): Groq models with prompt caching first (gpt-oss — the cached wrapper does not count toward limits), then qwen.
    public static let defaultChain: [ChainEntry] = [
        ChainEntry(provider: .groq, model: "openai/gpt-oss-120b"),
        ChainEntry(provider: .groq, model: "openai/gpt-oss-20b"),
        ChainEntry(provider: .groq, model: "qwen/qwen3.8-27b"),
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

    enum CodingKeys: String, CodingKey { case keys, chain, firstTokenTimeout, customBaseURL, knownModels, knownModelsAt, pinnedEntryID }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        keys = (try? c.decodeIfPresent([KeyRecord].self, forKey: .keys)) ?? []
        chain = (try? c.decodeIfPresent([ChainEntry].self, forKey: .chain)) ?? LLMSettings.defaultChain
        firstTokenTimeout = (try? c.decodeIfPresent(Double.self, forKey: .firstTokenTimeout)) ?? 6
        customBaseURL = (try? c.decodeIfPresent(String.self, forKey: .customBaseURL)) ?? ""
        knownModels = (try? c.decodeIfPresent([ProviderID: [String]].self, forKey: .knownModels)) ?? [:]
        knownModelsAt = (try? c.decodeIfPresent([ProviderID: Date].self, forKey: .knownModelsAt)) ?? [:]
        pinnedEntryID = try? c.decodeIfPresent(String.self, forKey: .pinnedEntryID)
    }

    public var customBase: URL? { ProviderEndpoints.customBaseURL(customBaseURL) }

    /// Migrates a saved old default order (120b → qwen → 20b) to the new one (120b → 20b → qwen). A user's own order is left alone.
    @discardableResult
    public static func migrateOrder(_ s: inout LLMSettings) -> Bool {
        let models = s.chain.filter { $0.provider == .groq }.map(\.model)
        guard models.prefix(3) == ["openai/gpt-oss-120b", "qwen/qwen3.8-27b", "openai/gpt-oss-20b"],
              let qi = s.chain.firstIndex(where: { $0.model == "qwen/qwen3.8-27b" }),
              let si = s.chain.firstIndex(where: { $0.model == "openai/gpt-oss-20b" }) else { return false }
        s.chain.swapAt(qi, si)
        return true
    }

    /// Label of the first available step for the source badge (R-32).
    public var primaryLabel: String? {
        if let pin = pinnedEntryID, let e = chain.first(where: { $0.id == pin }) {
            return StepInfo(provider: e.provider, model: e.model, keyID: "").label
        }
        for e in chain where e.enabled && keys.contains(where: { $0.provider == e.provider && !$0.invalid }) {
            return StepInfo(provider: e.provider, model: e.model, keyID: "").label
        }
        return nil
    }

    public func keys(for p: ProviderID) -> [KeyRecord] { keys.filter { $0.provider == p } }

    /// The main organization of a provider is the one of its first key; unlabeled keys all belong to it, so they never multiply a limit.
    public func mainOrganization(for p: ProviderID) -> String { keys(for: p).first?.organizationName ?? "" }

    /// Keys of one organization (per provider) are one pool = one rate-limit ceiling (ADR-0005 §1).
    public func poolID(of key: KeyRecord) -> String {
        let org = key.organizationName.isEmpty ? mainOrganization(for: key.provider) : key.organizationName
        return "\(key.provider.rawValue):\(org.isEmpty ? "main" : org)"
    }

    /// Additional organizations are an accepted owner risk (Groq's acceptable-use policy, ADR-0005 §3): flagged, and used after the main one.
    public func isOwnerRisk(_ key: KeyRecord) -> Bool {
        let org = key.organizationName
        return !org.isEmpty && org != mainOrganization(for: key.provider)
    }

    /// Usable keys of a provider, the main organization first, additional organizations after it (stable within each group).
    public func orderedKeys(for p: ProviderID) -> [KeyRecord] {
        let all = keys(for: p)
        return all.filter { !isOwnerRisk($0) } + all.filter { isOwnerRisk($0) }
    }

    /// Whether there is at least one working key — otherwise voice is inactive (R-45).
    public var hasUsableKey: Bool {
        chain.contains { e in e.enabled && keys.contains { $0.provider == e.provider && !$0.invalid } }
    }

    public mutating func markInvalid(keyID: String, reason: String) {
        guard let i = keys.firstIndex(where: { $0.id == keyID }) else { return }
        keys[i].invalid = true
        keys[i].invalidReason = reason
    }
}
