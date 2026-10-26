import Foundation

/// Lingo languages: target languages `en`, `de` and the explanation language `ru` (spec, section 1).
public enum Lang: String, Codable, Sendable, CaseIterable, Hashable {
    case en, de, ru

    /// Target languages (the English/Deutsch segment, R-05).
    public static let studied: [Lang] = [.en, .de]

    /// Name in the sidebar segment (mockup: "English", "Deutsch"); each language is named in itself.
    public var nativeName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .ru: "Русский"
        }
    }

    /// "in English" — for the header subtitle (R-40).
    public var inLanguagePhrase: String {
        switch self {
        case .en: String(localized: "in English")
        case .de: String(localized: "in German")
        case .ru: String(localized: "in Russian")
        }
    }

    /// Short label next to a bubble (R-08).
    public var tag: String { rawValue.uppercased() }

    /// Locale for recognition and speech.
    public var localeIdentifier: String {
        switch self {
        case .en: "en-US"
        case .de: "de-DE"
        case .ru: "ru-RU"
        }
    }
}
