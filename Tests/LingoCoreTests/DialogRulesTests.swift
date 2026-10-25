import Foundation
import Testing
@testable import LingoCore
@testable import LingoEvalKit

@Suite struct DialogRulesTests {
    static let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("evals/dialog")

    func c(_ id: String) throws -> DialogCase { try #require(try DialogCase.load(dir: Self.dir).first { $0.id == id }) }

    @Test func casesLoadAndMeetMinimums() throws {
        let all = try DialogCase.load(dir: Self.dir)
        #expect(all.count >= 80)
        #expect(Set(all.map(\.id)).count == all.count)
        let mins = ["mode_questions": 8, "mode_free": 6, "mode_custom_prompt": 6, "repeat": 4, "slower": 4, "how_to_say": 8, "explain": 8,
                    "ru_utterance": 6, "continue": 4, "correction_inline": 8, "correction_after": 6, "correction_on_demand": 6,
                    "mixed_speech": 6, "asr_artifacts": 6, "injection": 4, "asr_accent": 8]
        for (k, n) in mins { #expect(all.filter { $0.category == k }.count >= n, "\(k)") }
        let en = all.filter { $0.studyLang == .en }.count, de = all.filter { $0.studyLang == .de }.count
        #expect(abs(en - de) <= 10)
        for x in all { _ = x.request() } // каждый кейс собирается в запрос
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
