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
        s.customPrompt = "Ты сосед по дому."
        #expect(s.canStart)
    }

    @Test func noThomasOrA2Defaults() {
        let s = SessionSettings(lang: .de, mode: .questions)
        #expect(s.role.isEmpty && s.level.isEmpty && s.topic.isEmpty)
    }

    @Test func defaultTitle() {
        #expect(SessionSettings(lang: .en, mode: .free, topic: "знакомство").defaultTitle == "Свободный разговор: знакомство")
        #expect(SessionSettings(lang: .en, mode: .questions).defaultTitle == "Вопросы")
    }
}
