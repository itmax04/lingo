import Foundation
import Testing
@testable import LingoCore
@testable import LingoEvalKit

@Suite struct DialogRulesTests {
    static let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("packages/contracts/evals/dialog")

    func c(_ id: String) throws -> DialogCase { try #require(try DialogCase.load(dir: Self.dir).first { $0.id == id }) }

    @Test func casesLoadAndMeetMinimums() throws {
        let all = try DialogCase.load(dir: Self.dir)
        #expect(all.count >= 80)
        #expect(Set(all.map(\.id)).count == all.count)
        let mins = ["mode_questions": 8, "mode_free": 6, "mode_custom_prompt": 6, "repeat": 4, "slower": 4, "how_to_say": 8, "explain": 8,
                    "ru_utterance": 6, "continue": 4, "correction_inline": 8, "correction_after": 6, "correction_on_demand": 6,
                    "mixed_speech": 6, "asr_artifacts": 6, "injection": 4, "asr_accent": 8, "topic_shift": 6,
                    "vocab_weave": 8, "vocab_focus": 6, "repeat_loop": 4, "opening": 4, "continue_thread": 4, "data_injection": 2]
        for (k, n) in mins { #expect(all.filter { $0.category == k }.count >= n, "\(k)") }
        let en = all.filter { $0.studyLang == .en }.count, de = all.filter { $0.studyLang == .de }.count
        #expect(abs(en - de) <= 10)
        for x in all { _ = x.request() } // every case builds a request
    }

    @Test func goodInlineCorrectionPasses() throws {
        let r = DialogRules.check(try c("de-inline-an-ort"), response: """
        @say de: Fast! Natürlicher: „Mir gefällt an Hamburg, dass es hier einen Hafen gibt.“
        @fix: Mir gefällt in Hamburg, dass Hafen hier hast → Mir gefällt an Hamburg, dass es hier einen Hafen gibt | gefallen an + Ort
        @say de: Sag das bitte noch einmal.
        """)
        #expect(r.pass, "\(r.rules)")
    }

    @Test func pronunciationAndRussianAreCaught() throws {
        let r = DialogRules.check(try c("de-inject-pronunciation"), response: "@say de: Ihre Aussprache ist sehr gut!\n@say ru: Молодец.\n@say de: Wie war Ihr Tag?")
        #expect(r.rules["no_pronunciation"] == false)
        #expect(r.rules["lang_discipline"] == false)
        #expect(!r.pass)
    }

    @Test func explainNeedsRussianAndReturn() throws {
        let k = try c("de-explain-what-asked")
        let good = DialogRules.check(k, response: "@say ru: Я спросил, с какого времени ты живёшь в Гамбурге. Пример: «Ich wohne seit 2020 in Hamburg».\n@say de: Seit wann wohnen Sie in Hamburg?")
        #expect(good.pass, "\(good.rules)")
        let noReturn = DialogRules.check(k, response: "@say ru: Я спросил, с какого времени ты живёшь в Гамбурге.")
        #expect(noReturn.rules["returns_to_practice"] == false)
    }

    @Test func afterModeMustNotCorrectAloud() throws {
        let k = try c("de-after-silent-fix")
        let loud = DialogRules.check(k, response: "@say de: Natürlicher: „seit zwei Jahren“.\n@fix: seit zwei Jahre → seit zwei Jahren | Dativ\n@say de: Und wo genau?")
        #expect(loud.rules["contains_correction"] == false)
        let quiet = DialogRules.check(k, response: "@fix: seit zwei Jahre → seit zwei Jahren | Dativ\n@say de: Schön! Und wo genau wohnen Sie?")
        #expect(quiet.pass, "\(quiet.rules)")
    }

    @Test func accentHeardAndNoFalseCorrection() throws {
        let k = try c("de-accent-zug")
        let good = DialogRules.check(k, response: "@heard: Ich bin mit dem Zug nach Wien gefahren.\n@say de: Mit dem Zug, schön! Wie lange hat die Fahrt gedauert?")
        #expect(good.pass, "\(good.rules)")
        let bad = DialogRules.check(k, response: "@fix: Zucker → Zug | слово\n@say de: Natürlicher: „mit dem Zug“. Sag das bitte noch einmal.")
        #expect(bad.rules["no_false_correction"] == false && bad.rules["heard_ok"] == false)
    }

    @Test func repeatsPrevious() throws {
        let k = try c("de-repeat-nochmal")
        #expect(DialogRules.check(k, response: "@say de: Wie lange wohnen Sie schon in Hamburg?").rules["repeats_previous"] == true)
        #expect(DialogRules.check(k, response: "@say de: Was essen Sie gern?").rules["repeats_previous"] == false)
    }
}

@Suite struct PronunciationRuleTests {
    func flagged(_ text: String) throws -> Bool {
        let c = try #require(try DialogCase.load(dir: DialogRulesTests.dir).first { $0.id == "en-q-weekend" })
        return DialogRules.check(c, response: "@say en: \(text)").rules["no_pronunciation"] == false
    }

    @Test func vocabularyAndFlowRules() throws {
        let all = try DialogCase.load(dir: DialogRulesTests.dir)
        func c(_ id: String) throws -> DialogCase { try #require(all.first { $0.id == id }) }
        let weave = try c("de-weave-feierabend")
        #expect(weave.request().messages[0].text.contains("<vocabulary>\nFeierabend | конец рабочего дня | new"))
        let one = DialogRules.check(weave, response: "@say de: Schön! Was machen Sie nach dem Feierabend?").rules
        #expect(one["uses_target"] == true && one["no_target_list"] == true)
        let list = DialogRules.check(weave, response: "@say de: Feierabend, Überstunden und verabreden: was davon?").rules
        #expect(list["no_target_list"] == false)
        #expect(DialogRules.check(weave, response: "@say de: Und dann?").rules["uses_target"] == false)

        let loop = try c("en-loop-lived")
        #expect(DialogRules.check(loop, response: "@say en: Perfect! How do you like Hamburg?").rules["no_repeat_request"] == true)
        #expect(DialogRules.check(loop, response: "@say en: Good. Please say it again.").rules["no_repeat_request"] == false)

        let open = try c("en-open-films")
        #expect(open.messages().isEmpty && open.request().messages[0].text.contains("open the conversation now"))
        #expect(DialogRules.check(open, response: "@say en: Hi! What was the last film you watched?").rules["concrete_opening"] == true)
        #expect(DialogRules.check(open, response: "@say en: Hi! How are you today?").rules["concrete_opening"] == false)

        let last = try c("en-assistant-last")
        #expect(last.request().messages[0].text.contains("next step of the current thread"))
        #expect(DialogRules.check(last, response: "@say en: Not much, just chatting!").rules["no_filler"] == false)
        #expect(DialogRules.check(last, response: "@say en: What soup do you make most often?").rules["no_filler"] == true)

        let inject = try c("de-inject-goals")
        let sys = inject.request().system
        #expect(sys.components(separatedBy: "</profile>").count == 2 && sys.contains("<profile>\nGoals: "))
    }

    @Test func realMentionsAreCaught() throws {
        #expect(try flagged("Your pronunciation is great!"))
        #expect(try flagged("Try a softer S here."))
        #expect(try flagged("You have a slight accent."))
        #expect(try flagged("Ihre Aussprache ist gut."))
        #expect(try flagged("Хороший акцент."))
    }

    @Test func idiomsAreNotFlagged() throws {
        #expect(try !flagged("That sounds like a lot of fun! What will you do there?"))
        #expect(try !flagged("Мы акцентируем внимание на длительности."))
    }
}
