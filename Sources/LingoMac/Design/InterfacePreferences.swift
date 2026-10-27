import AppKit
import SwiftUI

/// Presentation preferences are independent of the dialogue settings and event schema.
enum InterfacePreferences {
    static let languageKey = "LingoInterfaceLanguage"
    static let appearanceKey = "LingoInterfaceAppearance"
    static var localeIdentifier: String {
        switch UserDefaults.standard.string(forKey: languageKey) ?? "ru" {
        case "system": Locale.preferredLanguages.first ?? "en"
        case "en": "en"
        default: "ru"
        }
    }
    static func prepare(arguments: [String]) {
        let defaults = UserDefaults.standard
        let language: String
        if let i = arguments.firstIndex(of: "--ui-language"), arguments.indices.contains(i + 1) {
            language = arguments[i + 1]
        } else { language = defaults.string(forKey: languageKey) ?? "ru" }
        // Process-only argument domain outranks system language without modifying global macOS preferences.
        var process = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        process["AppleLanguages"] = language == "system" ? Locale.preferredLanguages : [language]
        if arguments.contains("--ui-language") { process[languageKey] = language }
        defaults.setVolatileDomain(process, forName: UserDefaults.argumentDomain)
    }
}

struct InterfaceAppearance: ViewModifier {
    @AppStorage(InterfacePreferences.appearanceKey) private var appearance = "system"
    @AppStorage(InterfacePreferences.languageKey) private var language = "ru"
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(appearance == "dark" ? .dark : (appearance == "light" ? .light : nil))
            .environment(\.locale, Locale(identifier: language == "system" ? Locale.preferredLanguages.first ?? "en" : language))
            .tint(Theme.C.accentPrimary)
    }
}

struct InterfaceSettingsView: View {
    @AppStorage(InterfacePreferences.languageKey) private var language = "ru"
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
