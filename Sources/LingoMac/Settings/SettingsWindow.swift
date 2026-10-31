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
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { LingoMark().frame(width: 32, height: 32); Text("Lingo").font(Theme.F.logo) }
                    .padding(.bottom, 24)
                ForEach(SettingsTab.allCases) { item in
                    Button { tab = item } label: {
                        Text(item.title).font(Theme.F.rowTitle).foregroundStyle(tab == item ? Theme.accent(services?.model.studyLanguage ?? .de) : Theme.C.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                            .background(tab == item ? Theme.accentSurface(services?.model.studyLanguage ?? .de) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: Theme.R.button))
                    }.buttonStyle(LingoButtonStyle())
                }
                Spacer()
            }.padding(20).frame(width: 200).background(Theme.C.bgSidebar)
            ColumnDivider()
            VStack(spacing: 0) {
                HStack { Text(tab.title).font(Theme.F.title); Spacer() }.padding(24)
                switch tab {
                case .keys: KeysSettingsView(keys: keys)
                case .quota:
                    if let services { QuotaView(services: services) } else { unavailable }
                case .voice:
                    if let services { VoiceSettingsView(services: services) }
                    else { InterfaceSettingsView().padding(24) }
                case .sync:
                    if let services { SyncSettingsView(services: services, model: services.model) } else { unavailable }
                case .data:
                    if let services { DataSettingsView(services: services) } else { unavailable }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.C.bgWindow)
        }
        .frame(minWidth: 900, minHeight: 700)
        .foregroundStyle(Theme.C.textPrimary)
        .modifier(InterfaceAppearance())
        .environment(\.studyLanguage, services?.model.studyLanguage ?? .de)
    }
    private var unavailable: some View {
        VStack(spacing: 16) {
            Text("Available in the running app").font(Theme.F.subtitle)
            Spacer()
        }.padding(24)
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
        w.appearance = nil
        w.contentView = NSHostingView(rootView: SettingsView(keys: keys, services: services, tab: tab))
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window = w
    }
}
