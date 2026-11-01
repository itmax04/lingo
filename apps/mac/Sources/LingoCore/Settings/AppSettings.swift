import Foundation

/// App settings (R-44). No secrets here: keys live only in the Keychain (R-48).
/// Decoding tolerates missing fields: old settings are read by a newer app version.
public struct AppSettings: Codable, Sendable, Hashable {
    public var llm = LLMSettings()
    public var context = ContextPolicy()
    /// The previous choice of correction modes — prefilled in a new session (A-3).
    public var lastCorrections: Set<CorrectionMode> = []
    public var lastLang: Lang = .en
    /// Sync folder — a security-scoped bookmark (R-36).
    public var syncBookmark: Data?
    /// Daily backup folder — a security-scoped bookmark (MR-04, P-04b); nil = the daily backup is off.
    public var backupBookmark: Data?
    public var onboardingDone = false
    public var voice = VoiceSettings()

    public init() {}

    enum CodingKeys: String, CodingKey { case llm, context, lastCorrections, lastLang, syncBookmark, backupBookmark, onboardingDone, voice }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llm = (try? c.decodeIfPresent(LLMSettings.self, forKey: .llm)) ?? LLMSettings()
        context = (try? c.decodeIfPresent(ContextPolicy.self, forKey: .context)) ?? ContextPolicy()
        lastCorrections = (try? c.decodeIfPresent(Set<CorrectionMode>.self, forKey: .lastCorrections)) ?? []
        lastLang = (try? c.decodeIfPresent(Lang.self, forKey: .lastLang)) ?? .en
        syncBookmark = try? c.decodeIfPresent(Data.self, forKey: .syncBookmark)
        backupBookmark = try? c.decodeIfPresent(Data.self, forKey: .backupBookmark)
        onboardingDone = (try? c.decodeIfPresent(Bool.self, forKey: .onboardingDone)) ?? false
        voice = (try? c.decodeIfPresent(VoiceSettings.self, forKey: .voice)) ?? VoiceSettings()
    }
}

/// Settings stored in UserDefaults (available on iOS too).
public struct SettingsStore: @unchecked Sendable {
    public let defaults: UserDefaults
    public static let key = "lingo.settings.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> AppSettings {
        guard let d = defaults.data(forKey: Self.key), let s = try? JSONDecoder().decode(AppSettings.self, from: d) else { return AppSettings() }
        return s
    }

    public func save(_ s: AppSettings) {
        if let d = try? JSONEncoder().encode(s) { defaults.set(d, forKey: Self.key) }
    }
}
