import Foundation

/// Настройки приложения (R-44). Секретов здесь нет: ключи — только в Keychain (R-48).
/// Декодирование терпимо к отсутствующим полям: старые настройки читаются новой версией приложения.
public struct AppSettings: Codable, Sendable, Hashable {
    public var llm = LLMSettings()
    public var context = ContextPolicy()
    /// Прошлый выбор режимов исправления — подставляется в новую сессию (A-3).
    public var lastCorrections: Set<CorrectionMode> = []
    public var lastLang: Lang = .en
    /// Папка синхронизации — security-scoped bookmark (R-36).
    public var syncBookmark: Data?
    public var onboardingDone = false
    public var voice = VoiceSettings()

    public init() {}

    enum CodingKeys: String, CodingKey { case llm, context, lastCorrections, lastLang, syncBookmark, onboardingDone, voice }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llm = (try? c.decodeIfPresent(LLMSettings.self, forKey: .llm)) ?? LLMSettings()
        context = (try? c.decodeIfPresent(ContextPolicy.self, forKey: .context)) ?? ContextPolicy()
        lastCorrections = (try? c.decodeIfPresent(Set<CorrectionMode>.self, forKey: .lastCorrections)) ?? []
        lastLang = (try? c.decodeIfPresent(Lang.self, forKey: .lastLang)) ?? .en
        syncBookmark = try? c.decodeIfPresent(Data.self, forKey: .syncBookmark)
        onboardingDone = (try? c.decodeIfPresent(Bool.self, forKey: .onboardingDone)) ?? false
        voice = (try? c.decodeIfPresent(VoiceSettings.self, forKey: .voice)) ?? VoiceSettings()
    }
}

/// Хранение настроек в UserDefaults (есть и на iOS).
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
