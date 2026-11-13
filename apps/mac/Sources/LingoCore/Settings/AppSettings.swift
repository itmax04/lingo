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
    /// Daily reminder (GR-08): device-local by design, off by default. `reminderTime` is minutes after local midnight.
    public var reminderOn = false
    public var reminderTime = Reminder.defaultTime
    /// The learner's own scenarios, both study languages (device-local like the reminder; sessions keep their own copy).
    public var customScenarios: [CustomScenario] = []
    /// LINGO-09 MR-49: the "Reply options" switch. Device-local like the reminder, never journaled; off by default.
    /// Whether a session offers it is `ReplyOptions.isOffered`.
    public var replyOptions = false
    /// LINGO-09 MR-51: the reply options block is collapsed to its header. Device-local.
    public var replyOptionsCollapsed = false

    public init() {}

    enum CodingKeys: String, CodingKey { case llm, context, lastCorrections, lastLang, syncBookmark, backupBookmark, onboardingDone, voice, reminderOn, reminderTime, customScenarios, replyOptions, replyOptionsCollapsed }

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
        reminderOn = (try? c.decodeIfPresent(Bool.self, forKey: .reminderOn)) ?? false
        reminderTime = Reminder.clamp((try? c.decodeIfPresent(Int.self, forKey: .reminderTime)) ?? Reminder.defaultTime)
        customScenarios = ((try? c.decodeIfPresent([Lossy<CustomScenario>].self, forKey: .customScenarios)) ?? []).compactMap(\.value).filter(\.isValid)
        replyOptions = (try? c.decodeIfPresent(Bool.self, forKey: .replyOptions)) ?? false
        replyOptionsCollapsed = (try? c.decodeIfPresent(Bool.self, forKey: .replyOptionsCollapsed)) ?? false
    }
}

/// Decodes one array element or keeps nil, so one bad element (for example from a newer build) does not drop the whole list.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? decoder.singleValueContainer().decode(T.self) }
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
