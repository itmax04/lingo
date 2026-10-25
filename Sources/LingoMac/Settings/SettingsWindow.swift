import AppKit
import LingoCore
import SwiftUI

/// Вкладки настроек (R-44). «Голос», «Синхронизация», «Данные» добавляются в P-04 и P-10.
enum SettingsTab: String, CaseIterable, Identifiable {
    case keys = "Ключи и модели", voice = "Голос", sync = "Синхронизация", data = "Данные"
    var id: String { rawValue }
}

struct SettingsView: View {
    let keys: KeysController
    var services: AppServices?
    @State var tab: SettingsTab = .keys

    var body: some View {
        TabView(selection: $tab) {
            KeysSettingsView(keys: keys)
                .tabItem { Text(SettingsTab.keys.rawValue) }
                .tag(SettingsTab.keys)
            if let svc = services {
                VoiceSettingsView(services: svc).tabItem { Text(SettingsTab.voice.rawValue) }.tag(SettingsTab.voice)
                SyncSettingsView(services: svc, model: svc.model).tabItem { Text(SettingsTab.sync.rawValue) }.tag(SettingsTab.sync)
                DataSettingsView(services: svc).tabItem { Text(SettingsTab.data.rawValue) }.tag(SettingsTab.data)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .background(Theme.C.bgWindow)
        .preferredColorScheme(.dark)
    }
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(keys: KeysController, services: AppServices? = nil, tab: SettingsTab = .keys) {
        if let w = window { w.makeKeyAndOrderFront(nil); NSApp.activate(); return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 720),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        w.title = "Настройки Lingo"
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = NSHostingView(rootView: SettingsView(keys: keys, services: services, tab: tab))
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = w
    }
}
