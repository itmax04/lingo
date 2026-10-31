import AppKit
import LingoCore
import SwiftUI

/// Presentation preferences are independent of the dialogue settings and event schema.
enum InterfacePreferences {
    static let languageKey = "LingoInterfaceLanguage"
    static let appearanceKey = "LingoInterfaceAppearance"
    static let defaultLanguage = "system"
    static var localeIdentifier: String {
        localeIdentifier(language: UserDefaults.standard.string(forKey: languageKey))
    }
    static func localeIdentifier(language: String?, preferred: [String] = Locale.preferredLanguages) -> String {
        switch language ?? defaultLanguage {
        case "ru": "ru"
        case "en": "en"
        default: preferred.first ?? "en"
        }
    }
    static func prepare(arguments: [String], defaults: UserDefaults = .standard, preferred: [String] = Locale.preferredLanguages) {
        let language: String
        if let i = arguments.firstIndex(of: "--ui-language"), arguments.indices.contains(i + 1) {
            language = arguments[i + 1]
        } else { language = defaults.string(forKey: languageKey) ?? defaultLanguage }
        // Process-only argument domain; persistent preferences and macOS settings stay untouched.
        var process = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        process["AppleLanguages"] = ["ru", "en"].contains(language) ? [language] : preferred
        if arguments.contains("--ui-language") { process[languageKey] = language }
        defaults.setVolatileDomain(process, forName: UserDefaults.argumentDomain)
    }
}

struct InterfaceAppearance: ViewModifier {
    @Environment(\.studyLanguage) private var studyLanguage
    @AppStorage(InterfacePreferences.appearanceKey) private var appearance = "system"
    @AppStorage(InterfacePreferences.languageKey) private var language = InterfacePreferences.defaultLanguage
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance == "dark" ? .dark : (appearance == "light" ? .light : nil))
            .environment(\.locale, Locale(identifier: InterfacePreferences.localeIdentifier(language: language)))
            .tint(Theme.accent(studyLanguage))
    }
}

struct InterfaceSettingsView: View {
    @AppStorage(InterfacePreferences.languageKey) private var language = InterfacePreferences.defaultLanguage
    @AppStorage(InterfacePreferences.appearanceKey) private var appearance = "system"
    var body: some View {
        SettingsCard(title: "Interface") {
            Picker("Interface language", selection: $language) {
                Text("Russian").tag("ru")
                Text("English").tag("en")
                Text("System").tag("system")
            }
            Text("Restart Lingo to apply the language to menus and service messages.")
                .font(Theme.F.meta).foregroundStyle(Theme.C.textSecondary)
            Picker("Theme", selection: $appearance) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
        }
    }
}
