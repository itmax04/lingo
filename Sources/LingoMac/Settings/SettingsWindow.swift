import AppKit
import LingoCore
import SwiftUI

/// Settings tabs (R-44). "Voice", "Sync" and "Data" were added in P-04 and P-10.
enum SettingsTab: String, CaseIterable, Identifiable {
    case keys, quota, voice, sync, data
    var title: LocalizedStringKey {
        switch self {
        case .keys: "Keys and models"
        case .quota: "Quota"
        case .voice: "Voice"
        case .sync: "Sync"
        case .data: "Data"
        }
    }
    var id: Self { self }
}

struct SettingsView: View {
    let keys: KeysController
    var services: AppServices?
    @State var tab: SettingsTab = .keys

    var body: some View {
        TabView(selection: $tab) {
            KeysSettingsView(keys: keys)
                .tabItem { Text(SettingsTab.keys.title) }
                .tag(SettingsTab.keys)
            if let svc = services {
                QuotaView(services: svc).tabItem { Text(SettingsTab.quota.title) }.tag(SettingsTab.quota)
                VoiceSettingsView(services: svc).tabItem { Text(SettingsTab.voice.title) }.tag(SettingsTab.voice)
                SyncSettingsView(services: svc, model: svc.model).tabItem { Text(SettingsTab.sync.title) }.tag(SettingsTab.sync)
                DataSettingsView(services: svc).tabItem { Text(SettingsTab.data.title) }.tag(SettingsTab.data)
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
        w.title = String(localized: "Lingo Settings")
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = NSHostingView(rootView: SettingsView(keys: keys, services: services, tab: tab))
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = w
    }
}
