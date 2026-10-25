import Foundation
import Testing
@testable import LingoCore

@Suite struct ReplyProtocolTests {
    @Test func parsesAllTags() {
        let text = """
        @say de: Fast perfekt! Natürlicher wäre: „Ich heiße Alex. Freut mich.“
        @say ru: Это значит «приятно познакомиться».
        @fix: Mir gefällt in Rostock → Mir gefällt an Rostock | an + Ort: «нравится что-то в городе» — gefallen an
        @hint de: Freut mich, Sie kennenzulernen. | Приятно познакомиться.
        @say de: Sag das bitte noch einmal.
        """
        let p = ReplyProtocol.parse(text, studyLang: .de)
        #expect(p.violations == 0)
        #expect(p.segments.count == 5)
        #expect(p.segments[0] == .say(.de, "Fast perfekt! Natürlicher wäre: „Ich heiße Alex. Freut mich.“"))
        #expect(p.segments[1] == .say(.ru, "Это значит «приятно познакомиться»."))
        #expect(p.segments[2] == .fix(Fix(original: "Mir gefällt in Rostock", corrected: "Mir gefällt an Rostock",
                                          rule: "an + Ort: «нравится что-то в городе» — gefallen an")))
        #expect(p.segments[3] == .hint(Phrase(lang: .de, text: "Freut mich, Sie kennenzulernen.", translation: "Приятно познакомиться.", source: .hint)))
    }

    @Test func brokenLinesDoNotBreakTurn() {
        let text = """
        Hallo! Wie geht's?
        @say xx: komisch
        @fix: ohne Pfeil
        @unknown: etwas
        - **@say de:** Liste
        @say de:
        <think>internal</think>@say de: Danach
        """
        let p = ReplyProtocol.parse(text, studyLang: .de)
        #expect(p.segments == [.say(.de, "Hallo! Wie geht's?"), .say(.de, "komisch"), .say(.de, "etwas"), .say(.de, "Liste"), .say(.de, "Danach")])
        #expect(p.violations == 5) // без тега, неизвестный язык, @fix без стрелки, неизвестный тег, пустой @say
    }

    @Test func streamEmitsSentencesBeforeLineEnds() {
        var s = ReplyStreamParser(studyLang: .en)
        var items: [ReplyStreamParser.Item] = []
        for chunk in ["@say en: Hi, I’m Al", "ex. Nice to meet", " you. How are", " you?\n@hint en: Nice to meet you. | Приятно.\n", "@say ru: Привет"] {
            items += s.feed(chunk)
        }
        // Первое предложение готово до конца строки.
        #expect(items.first == .speak(.en, "Hi, I’m Alex."))
        items += s.finish()
        let spoken = items.compactMap { if case .speak(let l, let t) = $0 { return "\(l.rawValue):\(t)" }; return nil }
        #expect(spoken == ["en:Hi, I’m Alex.", "en:Nice to meet you.", "en:How are you?", "ru:Привет"])
        let segs = items.compactMap { if case .segment(let g) = $0 { return g }; return nil }
        #expect(segs.count == 3)
        #expect(s.violations == 0)
    }

    @Test func streamSkipsThinkingAcrossChunks() {
        var s = ReplyStreamParser(studyLang: .de)
        var items = s.feed("<thi")
        items += s.feed("nk>hidden. text. </th")
        items += s.feed("ink>@say de: Gut. Weiter")
        items += s.finish()
        let spoken = items.compactMap { if case .speak(_, let t) = $0 { return t }; return nil }
        #expect(spoken == ["Gut.", "Weiter"])
    }
}

@Suite struct ContextPolicyTests {
    func msgs(_ n: Int) -> [ChatMessage] {
        (0..<n).flatMap { i in
            [ChatMessage(id: "u\(i)", session: "s", role: .user, text: "u\(i)", lang: .de, createdAt: Date(timeIntervalSince1970: Double(i * 2))),
             ChatMessage(id: "a\(i)", session: "s", role: .assistant, text: "a\(i)", lang: .de, createdAt: Date(timeIntervalSince1970: Double(i * 2 + 1)))]
        }
    }

    @Test func windowKeepsLastNTurns() {
        let p = ContextPolicy(maxTurns: 6)
        let w = p.window(msgs(10))
        #expect(w.count == 12 && w.first?.id == "u4")
        #expect(ContextPolicy(maxTurns: 100).maxTurns == 40)
        #expect(ContextPolicy(maxTurns: 1).maxTurns == 6)
    }

    @Test func summaryEveryTenTurns() {
        let p = ContextPolicy()
        #expect(!p.needsSummary(msgs(9), through: nil))
        #expect(p.needsSummary(msgs(10), through: nil))
        #expect(!p.needsSummary(msgs(15), through: "a9"))
        #expect(p.needsSummary(msgs(20), through: "a9"))
    }
}

@Suite struct HeardTests {
    @Test func parsesHeardAndAttachesToUserMessage() throws {
        let p = ReplyProtocol.parse("@heard: My sister lives near the river.\n@say en: Oh nice! Is she older or younger?", studyLang: .en)
        #expect(p.violations == 0)
        #expect(p.segments.first == .heard("My sister lives near the river."))
        let created = try JSONValue.from(Payload.SessionCreated(title: "t", settings: SessionSettings(lang: .en, mode: .free, corrections: [.inline])))
        let u = ev("U1", device: "d", seq: 2, lamport: 2, ms: 2000, type: EventType.messageCreated, payload: msg("My system lives near the river.", lang: .en))
        let a = ev("A1", device: "d", seq: 3, lamport: 3, ms: 3000, type: EventType.messageCreated,
                   payload: try JSONValue.from(Payload.MessageCreated(role: .assistant, text: "", lang: .en, segments: p.segments, replyTo: "U1")))
        let st = Merger.build([ev("C", device: "d", seq: 1, lamport: 1, ms: 1000, type: EventType.sessionCreated, payload: created), u, a])
        #expect(st.messages["s1"]?.first { $0.id == "U1" }?.heard == "My sister lives near the river.")
        // В расшифровке для модели @heard не повторяется.
        #expect(!PromptBuilder.transcriptLine(st.messages["s1"]![1]).contains("@heard"))
    }
}
