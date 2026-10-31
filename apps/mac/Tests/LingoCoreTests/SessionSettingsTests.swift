import Foundation
import Testing
@testable import LingoCore

@Suite struct SessionSettingsTests {
    @Test func startRequiresCorrectionMode() {
        var s = SessionSettings(lang: .de, mode: .free)
        #expect(!s.canStart)
        s.corrections = [.after]
        #expect(s.canStart)
    }

    @Test func customPromptRequiresText() {
        var s = SessionSettings(lang: .en, mode: .customPrompt, corrections: [.inline])
        #expect(!s.canStart)
        s.customPrompt = "You are my neighbour."
        #expect(s.canStart)
    }

    @Test func noThomasOrA2Defaults() {
        let s = SessionSettings(lang: .de, mode: .questions)
        #expect(s.role.isEmpty && s.level.isEmpty && s.topic.isEmpty)
    }

    @Test func defaultTitle() {
        #expect(SessionSettings(lang: .en, mode: .free, topic: "introductions").defaultTitle == "Free conversation: introductions")
        #expect(SessionSettings(lang: .en, mode: .questions).defaultTitle == "Questions")
    }
}

@Suite struct AppSettingsTests {
    @Test func tolerantDecodingAndRoundTrip() throws {
        let old = #"{"lastLang":"de","llm":{"firstTokenTimeout":9}}"#
        let s = try JSONDecoder().decode(AppSettings.self, from: Data(old.utf8))
        #expect(s.lastLang == .de && s.llm.firstTokenTimeout == 9 && s.llm.chain == LLMSettings.defaultChain)
        let d = UserDefaults(suiteName: "lingo-test-\(UUID().uuidString)")!
        var x = AppSettings()
        x.llm.keys = [KeyRecord(id: "k", provider: .groq, last4: "abcd")]
        x.lastCorrections = [.inline, .after]
        SettingsStore(defaults: d).save(x)
        #expect(SettingsStore(defaults: d).load() == x)
        // Settings contain no key values — only the last 4 characters.
        let raw = String(decoding: d.data(forKey: SettingsStore.key)!, as: UTF8.self)
        #expect(raw.contains("abcd") && !raw.contains("secret"))
        #expect(x.llm.primaryLabel == "Groq · gpt-oss-120b")
    }
}
