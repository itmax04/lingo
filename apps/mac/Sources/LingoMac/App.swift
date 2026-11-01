import AppKit
import LingoCore
import SwiftUI

@main
@MainActor
enum LingoMain {
    static var delegate: AppDelegate?
    static func main() {
        let args = CommandLine.arguments
        InterfacePreferences.prepare(arguments: args)
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
            let url = URL(fileURLWithPath: args[i + 1])
            Task { @MainActor in exit(await UISnapshot.run(to: url)) }
            RunLoop.main.run()
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
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = String(localized: "Lingo — first launch")
        w.appearance = nil
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
            var seconds = 20
            if let d = CommandLine.arguments.firstIndex(of: "--duration"), d + 1 < CommandLine.arguments.count, let minutes = Double(CommandLine.arguments[d + 1]), minutes.isFinite, minutes > 0, minutes <= 24 * 60 {
                seconds = max(Int((minutes * 60).rounded()), 20)
            } else if let d = CommandLine.arguments.firstIndex(of: "--duration") {
                print("--duration needs a number of minutes between 0 and 1440 (got \(d + 1 < CommandLine.arguments.count ? CommandLine.arguments[d + 1] : "nothing")); using 20 seconds")
            }
            exit(AudioDiag.stability(to: CommandLine.arguments[i + 1], seconds: seconds))
        }
        if let i = CommandLine.arguments.firstIndex(of: "--audio-diag"), i + 1 < CommandLine.arguments.count { AudioDiag.step(CommandLine.arguments[i + 1], "didFinishLaunching") }
        if CommandLine.arguments.contains("--quit-check") { QuitCheck.run(); return }
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

    /// Free the whisper contexts before AppKit calls `exit`, otherwise ggml aborts while tearing down its Metal devices (crash on ⌘Q).
    func applicationWillTerminate(_ notification: Notification) {
        services?.turn?.stopVoice(cancelTurn: true)
        WhisperEngine.closeAll()
    }
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
        w.backgroundColor = NSColor(Theme.C.bgTitlebar)
        w.appearance = nil
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

/// Fixture-only rendering: no real journal, credentials, audio or provider requests.
@MainActor
enum UISnapshot {
    static func run(to url: URL) async -> Int32 {
        NSApplication.shared.setActivationPolicy(.accessory)
        let args = CommandLine.arguments
        func option(_ name: String) -> String? {
            guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
            return args[index + 1]
        }
        let theme = option("--ui-theme") ?? "dark"
        let defaults = UserDefaults.standard
        var process = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        process["LingoInterfaceAppearance"] = theme
        defaults.setVolatileDomain(process, forName: UserDefaults.argumentDomain)
        NSApp.appearance = NSAppearance(named: theme == "light" ? .aqua : .darkAqua)
        let model = AppModel()
        Fixtures.fill(model)
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-ui-" + UUID().uuidString)
        let suite = "lingo-ui-" + UUID().uuidString
        guard let isolated = UserDefaults(suiteName: suite) else { return 1 }
        defer { try? FileManager.default.removeItem(at: base); isolated.removePersistentDomain(forName: suite) }
        let secrets = InMemorySecretStore()
        guard let services = try? AppServices(model: model, settingsStore: SettingsStore(defaults: isolated), secrets: secrets, base: base) else { return 1 }
        model.services = services
        Fixtures.fill(model)
        var llm = LLMSettings()
        llm.keys = [KeyRecord(id: "demo-1", provider: .groq, last4: "0000"),
                    KeyRecord(id: "demo-2", provider: .groq, last4: "1111", invalid: true, invalidReason: "HTTP 401")]
        llm.knownModels[.groq] = ["openai/gpt-oss-120b", "openai/gpt-oss-20b"]
        llm.knownModelsAt[.groq] = Date()
        let keys = KeysController(settings: llm, secrets: secrets) { _ in }
        // Each capture is rendered immediately so mutable fixture state cannot leak to another screen.
        var ok = true
        func capture<V: View>(_ name: String, _ view: V, _ size: NSSize = NSSize(width: 1280, height: 800)) async {
            let target = option("--ui-all") == nil ? url : url.deletingLastPathComponent().appendingPathComponent("mac-" + name + "-" + theme + "-" + String(Int(size.width)) + "x" + String(Int(size.height)) + ".png")
            if option("--ui-all") == nil && name != "conversation-speaking" { return }
            ok = await render(view.modifier(InterfaceAppearance()), size: size, to: target) && ok
            print("ui-snapshot: " + target.path)
        }
        await capture("conversation-speaking", MainView(model: model))
        if option("--ui-all") != nil {
            await capture("conversation-narrow", MainView(model: model), NSSize(width: 1100, height: 800))
            model.hintsVisible = true
            for section in [AppSection.today, .dictionary, .progress, .teacher] {
                model.section = section
                await capture(section.rawValue + "-overview", MainView(model: model))
            }
            model.section = .conversations
            for state in [VoiceState.idle, .recording, .listening, .thinking, .speaking, .paused] {
                model.voiceState = state
                await capture("voice-" + String(describing: state), MainView(model: model))
            }
            model.voiceState = .recording
            model.banner = String(localized: "Saved on this Mac")
            await capture("voice-recording-notice", MainView(model: model))
            model.banner = nil
            model.networkUp = false
            model.banner = String(localized: "No network: model replies are unavailable")
            await capture("voice-offline", MainView(model: model))
            model.networkUp = true
            let quotaSteps = keys.settings.chain.filter(\.enabled).flatMap { entry in
                keys.settings.keys(for: entry.provider).filter { !$0.invalid }.map { keys.settings.stepInfo(provider: entry.provider, model: entry.model, key: $0) }
            }
            services.settings.llm = keys.settings
            for step in quotaSteps { ProviderHealth.shared.reportFailure(step, .http(status: 429, message: "Quota exhausted", retryAfter: 60)) }
            model.banner = String(localized: "Quota exhausted")
            await capture("voice-quota", MainView(model: model))
            for step in quotaSteps { ProviderHealth.shared.reportSuccess(step) }
            model.banner = nil
            model.messages[1].heard = Fixtures.corrected
            await capture("conversation-heard", MainView(model: model))
            model.messages[2].segments.insert(.say(.ru, Fixtures.russianExplanation), at: 0)
            await capture("conversation-russian", MainView(model: model))
            model.messages[2].interruptedAt = 12
            await capture("conversation-interrupted", MainView(model: model))
            Fixtures.fill(model)
            model.messages.append(ChatMessage(id: "recap", session: "s1", role: .assistant,
                text: "seit zwei Tage → seit zwei Tagen", lang: .ru, createdAt: Date(), kind: .summary))
            await capture("recap-complete", MainView(model: model))
            model.messages.removeLast()
            model.messages.append(ChatMessage(id: "error", session: "s1", role: .assistant,
                text: String(localized: "Quota exhausted"), lang: .de, createdAt: Date(), kind: .error))
            await capture("conversation-error", MainView(model: model))
            Fixtures.fill(model)
            await capture("correction-detail", MainView(model: model).overlay(alignment: .topTrailing) {
                CorrectionDetailView(fix: Fix(original: Fixtures.original, corrected: Fixtures.corrected, rule: Fixtures.rule))
                    .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card)).padding(.top, 180).padding(.trailing, 288)
            })
            await capture("session-menu", MainView(model: model).overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 12) { SessionActionsContent() }
                    .padding(16).frame(width: 200).background(Theme.C.surfaceCard, in: RoundedRectangle(cornerRadius: Theme.R.card))
                    .subtleStroke(RoundedRectangle(cornerRadius: Theme.R.card)).padding(.top, 480).padding(.leading, 100)
            })
            for tab in SettingsTab.allCases {
                await capture("settings-" + tab.rawValue, SettingsView(keys: keys, services: services, tab: tab))
            }
            await capture("new-session-form", NewSessionView(lang: .de, lastCorrections: [.inline], onStart: { _, _ in }, onCancel: {}))
            // LINGO-08 VAC-07: "My words" in the new-session screen, the vocabulary with all languages, the paste sheet.
            await capture("new-session-my-words", NewSessionView(lang: .de, lastCorrections: [.inline], vocabularyCount: { _ in 3 }, onStart: { _, _ in }, onCancel: {}), NSSize(width: 820, height: 680))
            model.section = .dictionary
            model.vocabularyFilter = nil
            await capture("dictionary-all", MainView(model: model))
            model.vocabularyFilter = .de
            model.section = .conversations
            await capture("vocabulary-paste", VocabularyPasteView(lang: .de, onAdd: { _, _ in }, onCancel: {}), NSSize(width: 520, height: 560))
            await capture("transcript-edit", EditMessageView(message: model.messages[1], onSave: { _ in }, onRegenerate: { _ in }, onCancel: {}))
            for step in 0..<3 {
                await capture("onboarding-" + String(step), OnboardingView(services: services, keys: keys, initialStep: step, onDone: {}))
            }
        }
        return ok ? 0 : 1
    }
    static func render<V: View>(_ view: V, size: NSSize, to url: URL) async -> Bool {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height).background(Theme.C.bgWindow))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSApp.appearance
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil; window.close() }
        // Explicit pixel dimensions keep evidence at 2× even on a 1× or off-screen display.
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return false }
        rep.size = size
        var previous: Data?
        var stablePasses = 0
        for pass in 1...8 {
            // Yield the main actor so deferred SwiftUI updates can actually execute.
            try? await Task.sleep(for: .milliseconds(80))
            hosting.layoutSubtreeIfNeeded()
            hosting.displayIfNeeded()
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            guard let pixels = rep.bitmapData else { return false }
            let current = Data(bytes: pixels, count: rep.bytesPerRow * rep.pixelsHigh)
            stablePasses = current == previous ? stablePasses + 1 : 0
            previous = current
            // Two unchanged captures after at least four passes allow onAppear/onChange to settle.
            if pass >= 4 && stablePasses >= 2 { break }
        }
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: url)) != nil
    }
}
