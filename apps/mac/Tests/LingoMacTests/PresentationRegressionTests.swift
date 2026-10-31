import AppKit
import SwiftUI
import Testing
import LingoCore
@testable import LingoMac

@Suite(.serialized) @MainActor struct PresentationRegressionTests {
    @Test func freshInstallUsesRussianAndKeepsSystemAndEnglishAsExplicitChoices() throws {
        let suite = "lingo-language-test-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        InterfacePreferences.prepare(arguments: [], defaults: defaults, preferred: ["de-DE", "en-US"])
        let process = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        #expect(InterfacePreferences.defaultLanguage == "ru")
        #expect(process[InterfacePreferences.languageKey] == nil)
        #expect(process["AppleLanguages"] as? [String] == ["ru"])
        #expect(defaults.persistentDomain(forName: suite)?[InterfacePreferences.languageKey] == nil)
        #expect(InterfacePreferences.localeIdentifier(language: nil, preferred: ["de-DE"]) == "ru")
        #expect(InterfacePreferences.localeIdentifier(language: "system", preferred: ["de-DE"]) == "de-DE")
        #expect(InterfacePreferences.localeIdentifier(language: "system", preferred: []) == "en")
        defaults.set("system", forKey: InterfacePreferences.languageKey)
        InterfacePreferences.prepare(arguments: [], defaults: defaults, preferred: ["de-DE", "en-US"])
        #expect(defaults.volatileDomain(forName: UserDefaults.argumentDomain)["AppleLanguages"] as? [String] == ["de-DE", "en-US"])
        defaults.set("ru", forKey: InterfacePreferences.languageKey)
        InterfacePreferences.prepare(arguments: [], defaults: defaults, preferred: ["de-DE"])
        #expect(defaults.volatileDomain(forName: UserDefaults.argumentDomain)["AppleLanguages"] as? [String] == ["ru"])
        InterfacePreferences.prepare(arguments: ["--ui-language", "en"], defaults: defaults)
        #expect(defaults.volatileDomain(forName: UserDefaults.argumentDomain)["AppleLanguages"] as? [String] == ["en"])
        #expect(defaults.persistentDomain(forName: suite)?[InterfacePreferences.languageKey] as? String == "ru")
    }

    @Test func resizingKeepsTheOwnersHintsChoice() async throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let model = AppModel()
        Fixtures.fill(model)
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        for visible in [true, false] {
            model.hintsVisible = visible
            for width in [1100.0, 1280.0, 1100.0] {
                #expect(await UISnapshot.render(MainView(model: model), size: NSSize(width: width, height: 700), to: folder.appendingPathComponent("resize.png")))
                #expect(model.hintsVisible == visible)
            }
        }
    }

    @Test func noticesDoNotReplaceVoiceStateOrCapturedLevels() {
        let model = AppModel()
        Fixtures.fill(model)
        model.voiceState = .recording
        for notice in ["Phrase saved", "Sync complete", "Echo cancellation unavailable", "Quota exhausted"] {
            model.banner = notice
            #expect(model.voiceUnavailableReason() == nil)
            let panel = VoicePanel(state: model.voiceState, levels: [0.2, 0.8], unavailable: model.voiceUnavailableReason())
            #expect(panel.activeLevels == [0.2, 0.8])
        }
        model.networkUp = false
        #expect(model.voiceUnavailableReason() != nil)
        #expect(VoicePanel(state: .recording, levels: [0.5], unavailable: model.voiceUnavailableReason()).activeLevels == [0.5])
        model.networkUp = true
        model.hasKey = false
        #expect(model.voiceUnavailableReason() != nil)
        #expect(VoicePanel(state: .idle, levels: [0.5]).activeLevels.isEmpty)
    }

    @Test func quotaNeedsEveryUsableRouteToHaveAnActual429AndExpires() {
        let now = Date(timeIntervalSince1970: 1000)
        let health = ProviderHealth()
        let entries = [ChainEntry(id: "a", provider: .groq, model: "a"), ChainEntry(id: "b", provider: .groq, model: "b")]
        var settings = LLMSettings(keys: [KeyRecord(id: "fixture", provider: .groq, last4: "0000")], chain: entries)
        let a = StepInfo(provider: .groq, model: "a", keyID: "fixture")
        let b = StepInfo(provider: .groq, model: "b", keyID: "fixture")
        health.reportFailure(a, .http(status: 429, message: "limit", retryAfter: 30), now: now)
        #expect(!VoiceAvailability.quotaExhausted(settings: settings, health: health, now: now))
        health.reportFailure(b, .network("offline"), now: now)
        #expect(!VoiceAvailability.quotaExhausted(settings: settings, health: health, now: now))
        health.reportFailure(b, .http(status: 429, message: "limit", retryAfter: 30), now: now)
        #expect(VoiceAvailability.quotaExhausted(settings: settings, health: health, now: now))
        #expect(!VoiceAvailability.quotaExhausted(settings: settings, health: health, now: now.addingTimeInterval(31)))
        health.reportSuccess(b)
        settings.pinnedEntryID = "a"
        #expect(VoiceAvailability.quotaExhausted(settings: settings, health: health, now: now))
        settings.keys[0].invalid = true
        #expect(!VoiceAvailability.quotaExhausted(settings: settings, health: health, now: now))
    }

    @Test func accentFollowsSessionLanguageAndFilterFallback() {
        let model = AppModel()
        Fixtures.fill(model)
        model.langFilter = .en
        #expect(model.studyLanguage == .de)
        model.selectedSessionID = "s2"
        #expect(model.studyLanguage == .en)
        #expect(Theme.accent(model.studyLanguage) == Theme.C.accentEnglish)
        model.selectedSessionID = nil
        #expect(model.studyLanguage == .en)
        model.langFilter = .de
        #expect(Theme.accent(model.studyLanguage) == Theme.C.accentGerman)
    }

    @Test func microphoneLabelIncludesEveryActiveState() {
        #expect(VoicePanel(state: .idle, levels: []).microphoneLabel == String(localized: "Speak"))
        for state in [VoiceState.recording, .listening, .thinking, .speaking, .paused] {
            #expect(VoicePanel(state: state, levels: []).microphoneLabel == String(localized: "Microphone: \(state.title)"))
        }
    }

    @Test func emptyHintSectionsDisappearWhileOtherSectionsRemain() {
        let topic = Phrase(lang: .de, text: "Hallo", translation: "Hello", source: .topic)
        let correction = Phrase(lang: .de, text: "Guten Tag", translation: "Hello", source: .correction)
        #expect(HintsPanel(phrases: [], starred: []).sections.isEmpty)
        let panel = HintsPanel(phrases: [topic], starred: [], corrections: [correction, correction])
        #expect(panel.sections.map(\.0) == ["topic", "fix"])
        #expect(panel.sections.map { $0.2.count } == [1, 1])
    }

    @Test func diffPreservesExactSourceCasingWhitespaceAndSurroundings() throws {
        let text = "Before: ICH\t habe  seit zwei Tage\nKopfschmerzen. After."
        let fix = Fix(original: "ich habe seit zwei Tage Kopfschmerzen.", corrected: "ich habe seit zwei Tagen Kopfschmerzen.")
        let diff = try #require(InlineCorrection(text: text, fix: fix))
        #expect(diff.before == "Before: ICH\t habe  seit zwei ")
        #expect(diff.wrong == "Tage")
        #expect(diff.after == "\nKopfschmerzen. After.")
        #expect(diff.before + diff.wrong + diff.after == text)
        #expect(diff.right == "Tagen")
        let casing = try #require(InlineCorrection(text: "i live here.", fix: Fix(original: "i live here.", corrected: "I live here.")))
        #expect(casing.wrong == "i")
        #expect(casing.right == "I")
    }

    @Test func insertionKeepsSourceSpacingAndAddsOnlyMissingSeparators() throws {
        for (original, corrected) in [("I ready.", "I am ready."), ("Ready", "Ready now"), ("ready", "I am ready")] {
            let diff = try #require(InlineCorrection(text: original, fix: Fix(original: original, corrected: corrected)))
            #expect(diff.before + diff.wrong + diff.after == original)
            #expect(diff.before + diff.replacementPrefix + diff.right + diff.replacementSuffix + diff.after == corrected)
        }
    }

    @Test func correctionIndexKeepsExtraUnattachableAndDisabledFixesVisible() {
        let date = Date(timeIntervalSince1970: 1000)
        let first = Fix(original: "I is here.", corrected: "I am here.")
        let extra = Fix(original: "is here", corrected: "am here", rule: "Another explanation")
        let unmatched = Fix(original: "different", corrected: "other")
        let user = ChatMessage(id: "u", session: "s", role: .user, text: first.original, lang: .en, createdAt: date)
        var assistant = ChatMessage(id: "a", session: "s", role: .assistant, text: "", lang: .en,
                                    segments: [.fix(first), .fix(extra), .fix(unmatched)], createdAt: date)
        let index = MessageCorrections(messages: [user, assistant])
        #expect(index.inline == ["u": first])
        #expect(index.fallback == ["a": [extra, unmatched]])
        let disabled = MessageCorrections(messages: [user, assistant], showInline: false)
        #expect(disabled.inline.isEmpty)
        #expect(disabled.fallback["a"] == [first, extra, unmatched])
        assistant.segments = [.fix(unmatched)]
        #expect(MessageCorrections(messages: [user, assistant]).inline.isEmpty)
        let nextUser = ChatMessage(id: "u2", session: "s", role: .user, text: "unrelated", lang: .en, createdAt: date)
        assistant.segments = [.fix(first)]
        #expect(MessageCorrections(messages: [user, nextUser, assistant]).inline.isEmpty)
        assistant.session = "other"
        #expect(MessageCorrections(messages: [user, assistant]).inline.isEmpty)
    }

    @Test func waveformUpdatesDoNotInvalidateTheStreamingCorrectionInput() {
        let model = AppModel()
        Fixtures.fill(model)
        model.streaming = "@say de: Guten Tag!"
        let before = model.displayMessages
        model.levels.append(0.5)
        #expect(model.displayMessages == before)
        model.streaming = "@say de: Guten Tag! Wie geht es Ihnen?"
        #expect(model.displayMessages != before)
    }

    @Test func correctedUserBubbleStillOpensEditor() async throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let model = AppModel()
        Fixtures.fill(model)
        let message = model.messages[1]
        let fix = Fix(original: message.text, corrected: Fixtures.corrected, rule: Fixtures.rule)
        let view = MessageBubble(message: message, maxWidth: 450, correction: fix, onTap: { model.editing = message })
            .frame(width: 600, height: 200, alignment: .topLeading)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 200)
        let window = NSWindow(contentRect: NSRect(x: -20_000, y: -20_000, width: 600, height: 200),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(200))
        hosting.layoutSubtreeIfNeeded()
        // The transcript line is separate from the Correction button underneath it.
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try #require(NSEvent.mouseEvent(with: type, location: NSPoint(x: 500, y: 174), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
            window.sendEvent(event)
        }
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.editing?.id == message.id)
    }

    @Test func snapshotUsesTwoPixelsPerPointAndWaitsForDeferredLayout() async throws {
        NSApplication.shared.setActivationPolicy(.accessory)
        let folder = try temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("settled.png")
        #expect(await UISnapshot.render(DeferredLayoutProbe(), size: NSSize(width: 80, height: 60), to: url))
        let rep = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        #expect(rep.pixelsWide == 160)
        #expect(rep.pixelsHigh == 120)
        let color = try #require(rep.colorAt(x: 80, y: 60)?.usingColorSpace(.sRGB))
        #expect(color.greenComponent > 0.9)
        #expect(color.redComponent < 0.1)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-presentation-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}

private struct DeferredLayoutProbe: View {
    @State private var settled = false
    var body: some View {
        Rectangle().fill(settled ? Color(.sRGB, red: 0, green: 1, blue: 0, opacity: 1) : Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1))
            .onAppear { DispatchQueue.main.async { settled = true } }
    }
}
