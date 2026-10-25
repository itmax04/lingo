import Foundation

/// Языки Lingo: изучаемые `en`, `de` и язык объяснений `ru` (spec, раздел 1).
public enum Lang: String, Codable, Sendable, CaseIterable, Hashable {
    case en, de, ru

    /// Изучаемые языки (сегмент English/Deutsch, R-05).
    public static let studied: [Lang] = [.en, .de]

    /// Название в сегменте сайдбара (макет: «English», «Deutsch»).
    public var nativeName: String {
        switch self {
        case .en: "English"
        case .de: "Deutsch"
        case .ru: "Русский"
        }
    }

    /// «на английском» — для подзаголовка шапки (R-40).
    public var russianPrepositional: String {
        switch self {
        case .en: "на английском"
        case .de: "на немецком"
        case .ru: "на русском"
        }
    }

    /// Короткая метка у пузыря (R-08).
    public var tag: String { rawValue.uppercased() }

    /// Локаль для распознавания и озвучивания.
    public var localeIdentifier: String {
        switch self {
        case .en: "en-US"
        case .de: "de-DE"
        case .ru: "ru-RU"
        }
    }
}
