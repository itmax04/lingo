import AppKit
import LingoCore
import SwiftUI

@main
@MainActor
enum LingoMain {
    static var delegate: AppDelegate?
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--audio-diag"), i + 1 < args.count { AudioDiag.step(args[i + 1], "main") }
        if let i = args.firstIndex(of: "--export-iconset"), i + 1 < args.count {
            do {
                try AppIconView.exportIconset(to: URL(fileURLWithPath: args[i + 1]))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("export-iconset: \(error)\n".utf8))
                exit(1)
            }
        }
        // Service mode: a PNG snapshot of the window on fixtures (evidence for AC-11), without audio, network or journal.
        if let i = args.firstIndex(of: "--ui-snapshot"), i + 1 < args.count {
            exit(UISnapshot.run(to: URL(fileURLWithPath: args[i + 1])))
        }
        // Service mode: check all keys and `GET /models` (H-1, P-03). Key values are never printed.
        // Runs from the signed .app: only it gets keys from the Keychain without a prompt.
        if args.contains("--ui-click-test") { exit(UIClickTest.run()) }
        if let i = args.firstIndex(of: "--selftest") {
            setvbuf(stdout, nil, _IOLBF, 0)
            let files = args.dropFirst(i + 1).filter { !$0.hasPrefix("--") }
            let lang: Lang = args.contains("--en") ? .en : .de
            let box = Box(Int32(0))
            Task { @MainActor in box.value = await SelfTest.run(files: Array(files), lang: lang); exit(box.value) }
            RunLoop.main.run()
        }
        if args.contains("--help-eval") { print("--eval-dialog <cases> <out> [--models m1,m2] [--only ids] [--max-cases 10] [--budget 15] [--offset 0] [--allow-daytime] [--provider groq]"); exit(0) }
        if args.contains("--eval-dialog") {
            setvbuf(stdout, nil, _IOLBF, 0)
            exit(Headless.evalDialog(args: args))
        }
        if args.contains("--check-keys") {
            setvbuf(stdout, nil, _IOLBF, 0)
            exit(Headless.checkKeys(showAll: args.contains("--all-models")))
        }
        let app = NSApplication.shared
        // `NSApplication.delegate` is a weak reference: the delegate is kept statically, otherwise the optimizer may release it before `run()`.
        delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    let model = AppModel()
    var services: AppServices?
    private let settingsWindow = SettingsWindowController()
    lazy var keys = KeysController(settings: services?.settings.llm ?? SettingsStore().load().llm, secrets: KeychainStore()) { [weak self] llm in
        self?.services?.updateSettings { $0.llm = llm }
    }

    private var keyMonitor: Any?

    /// Voice-mode keyboard (R-06, DESIGN.md §8): space — hold (if focus is not in a text field), Esc — stop, ⌥R — "I'm speaking Russian".
    func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] e in
            guard let self, let svc = self.services, e.window === self.window, e.window?.attachedSheet == nil else { return e }
            let textFocused = e.window?.firstResponder is NSText
            switch (e.type, e.keyCode) {
            case (.keyDown, 49) where !textFocused:            // space
                if !e.isARepeat { svc.spaceDown() }
                return nil
            case (.keyUp, 49) where !textFocused:
                svc.spaceUp()
                return nil
            case (.keyDown, 53):                                 // Esc
                svc.escape()
                return textFocused ? e : nil
            case (.keyDown, 15) where e.modifierFlags.contains(.option):  // ⌥R
                svc.toggleRussian()
                return nil
            default:
                return e
            }
        }
    }

    private var onboardingWindow: NSWindow?

    func showOnboarding() {
        guard let svc = services else { return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 520), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = String(localized: "Lingo — first launch")
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = NSHostingView(rootView: OnboardingView(services: svc, keys: keys) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        })
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        onboardingWindow = w
    }

    @objc func showSTTCheck(_ sender: Any?) { STTCheckWindow.show(part: "part1") }

    @objc func showSettings(_ sender: Any?) {
        settingsWindow.show(keys: keys, services: services)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("launch")
        if let i = CommandLine.arguments.firstIndex(of: "--audio-stability"), i + 1 < CommandLine.arguments.count {
            exit(AudioDiag.stability(to: CommandLine.arguments[i + 1]))
        }
        if let i = CommandLine.arguments.firstIndex(of: "--audio-diag"), i + 1 < CommandLine.arguments.count { AudioDiag.step(CommandLine.arguments[i + 1], "didFinishLaunching") }
        do {
            let svc = try AppServices(model: model)
            services = svc
            model.services = svc
            svc.keys = keys
            Task { await svc.start() }
        } catch {
            model.banner = String(localized: "Could not open the journal: \(String(describing: error))")
        }
        if CommandLine.arguments.contains("--settings") { showSettings(nil) }
        if let i = CommandLine.arguments.firstIndex(of: "--audio-diag"), i + 1 < CommandLine.arguments.count {
            exit(AudioDiag.run(to: CommandLine.arguments[i + 1]))
        }
        installKeyMonitor()
        NSApp.mainMenu = MainMenu.build()
        let w = MainWindow.make(model: model)
        w.makeKeyAndOrderFront(nil)
        window = w
        if let svc = services, !svc.settings.onboardingDone, !CommandLine.arguments.contains("--stt-check") { showOnboarding() }
        // The service check window stays above the main one (otherwise the main window took focus and closed it, H-2).
        if let i = CommandLine.arguments.firstIndex(of: "--stt-check") {
            let part = i + 1 < CommandLine.arguments.count ? CommandLine.arguments[i + 1] : "part1"
            STTCheckWindow.show(part: part)
        }
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@MainActor
enum MainWindow {
    static func make(model: AppModel) -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Lingo"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        // Title bar — `bg.titlebar` (DESIGN.md §1).
        w.backgroundColor = NSColor(srgbRed: 0x1B / 255, green: 0x21 / 255, blue: 0x25 / 255, alpha: 1)
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentMinSize = Theme.S.minWindow
        w.contentView = NSHostingView(rootView: MainView(model: model))
        w.setFrameAutosaveName("LingoMain")
        if !w.setFrameUsingName("LingoMain") { w.center() }
        w.isReleasedWhenClosed = false
        return w
    }
}

@MainActor
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: String(localized: "About Lingo"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Settings…"), action: #selector(AppDelegate.showSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(withTitle: String(localized: "Speech recognition check…"), action: #selector(AppDelegate.showSTTCheck(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: String(localized: "Hide Lingo"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: String(localized: "Quit Lingo"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: String(localized: "Edit"))
        edit.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let win = NSMenu(title: String(localized: "Window"))
        win.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = win
        main.addItem(windowItem)
        NSApp.windowsMenu = win
        return main
    }
}

/// `--ui-snapshot <file.png>`: a 1280×800 snapshot of the main window on fixtures (modelled on IC `UISnapshots.render`, commit cf0e764).
@MainActor
enum UISnapshot {
    static func run(to url: URL) -> Int32 {
        NSApplication.shared.setActivationPolicy(.accessory)
        let model = AppModel()
        Fixtures.fill(model)
        let size = NSSize(width: 1280, height: 800)
        var ok = render(MainView(model: model), size: size, to: url)
        // Settings with synthetic keys (values only in memory).
        var llm = LLMSettings()
        llm.keys = [KeyRecord(id: "k1", provider: .groq, last4: "a1b2"),
                    KeyRecord(id: "k2", provider: .groq, last4: "c3d4", invalid: true, invalidReason: "HTTP 401")]
        llm.knownModels[.groq] = ["openai/gpt-oss-120b", "openai/gpt-oss-20b", "qwen/qwen3.8-27b"]
        llm.knownModelsAt[.groq] = Date()
        let keys = KeysController(settings: llm, secrets: InMemorySecretStore(["k1": "synthetic-0000", "k2": "synthetic-1111"])) { _ in }
        keys.checks["k1"] = KeyCheckResult.ok(models: ["a", "b", "c"]).summary
        let settingsURL = url.deletingPathExtension().appendingPathExtension("settings.png")
        ok = render(SettingsView(keys: keys), size: NSSize(width: 900, height: 1100), to: settingsURL) && ok
        let newURL = url.deletingPathExtension().appendingPathExtension("new-session.png")
        ok = render(NewSessionView(lang: .de, lastCorrections: [.inline], onStart: { _, _ in }, onCancel: {}), size: NSSize(width: 620, height: 640), to: newURL) && ok
        print(ok ? "ui-snapshot: \(url.path), \(settingsURL.path), \(newURL.path)" : "ui-snapshot: FAILED")
        return ok ? 0 : 1
    }

    static func render<V: View>(_ view: V, size: NSSize, to url: URL) -> Bool {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hosting
        window.orderFrontRegardless()
        for _ in 0..<8 { RunLoop.main.run(until: Date().addingTimeInterval(0.08)); hosting.layoutSubtreeIfNeeded() }
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return false }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        window.orderOut(nil)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: url)) != nil
    }
}
