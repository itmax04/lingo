import Foundation
import Testing
@testable import LingoCore
@testable import LingoEvalKit

/// Scripted provider: each request takes the next outcome (a reply, or nil for a provider failure).
final class DebriefProvider: LLMProvider, @unchecked Sendable {
    let id: ProviderID = .groq
    private let lock = NSLock()
    private var outcomes: [String?]
    private(set) var requests: [LLMRequest] = []
    init(_ outcomes: [String?]) { self.outcomes = outcomes }
    var all: [LLMRequest] { lock.withLock { requests } }
    func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error> {
        let outcome: String? = lock.withLock { requests.append(request); return outcomes.isEmpty ? nil : outcomes.removeFirst() }
        return AsyncThrowingStream { c in
            if let text = outcome {
                c.yield(.model(model)); c.yield(.text(text)); c.yield(.done(stopReason: "stop")); c.finish()
            } else {
                c.finish(throwing: LLMError.http(status: 500, message: "synthetic failure"))
            }
        }
    }
}

@Suite struct ExamDebriefTests {
    static let good = """
    Fluency and coherence: Ровная речь. Ориентировочный диапазон: B1–B2
    Сильные стороны:
    1. Ясные ответы
    2. Хорошие примеры
    Что улучшить:
    1. I go → I went — прошедшее время
    Это оценка для практики, а не официальный балл.
    """

    private func setup(_ name: String, _ p: DebriefProvider, kind: ExamKind = .ielts, answers: [String] = ["I went to a park yesterday."]) async throws -> (DialogEngine, JournalStore, String) {
        let store = try JournalStore(base: tempDir(name), deviceName: "Mac", deviceID: "mac-debrief")
        let llm = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "m")], firstTokenTimeout: 2)
        let engine = DialogEngine(store: store) { ChainFactory.chain(settings: llm, secrets: InMemorySecretStore(["k": "synthetic"]), providers: [.groq: p]) }
        let id = try await engine.createSession(kind.settings(tasks: kind.drawTasks())!)
        for a in answers { _ = try await engine.recordUser(session: id, text: a, lang: kind.lang) }
        return (engine, store, id)
    }
    private func summaries(_ store: JournalStore, _ id: String) async -> [ChatMessage] {
        (await store.state.messages[id] ?? []).filter { $0.kind == .summary }
    }

    // MARK: filter and the shared marker list

    @Test func filterDropsMarkerLinesInGermanEnglishAndRussian() {
        let text = "Gute Struktur.\nIhre Aussprache ist klar.\nGood vocabulary.\nYour pronunciation was fine.\nХорошая грамматика.\nПроизношение отличное.\nНужно следить за интонацией."
        #expect(PronunciationFilter.removingMarkedLines(from: text) == "Gute Struktur.\nGood vocabulary.\nХорошая грамматика.")
        for line in ["Betonung beachten", "Work on your accent", "Это звучит с акцентом", "softer s", "Der Akzent stört"] { #expect(PronunciationFilter.matches(line), "\(line)") }
    }

    @Test func filterKeepsEverydayIdioms() {
        for line in ["That sounds like a plan.", "Das klingt wie ein guter Plan.", "Это звучит как хороший план.", "Нужно акцентировать внимание на примерах."] {
            #expect(!PronunciationFilter.matches(line), "\(line)")
        }
    }

    @Test func evalRuleUsesTheSameList() {
        #expect(DialogRules.pronunciation == PronunciationFilter.markers)
    }

    // MARK: request (XR-03, PX-04)

    @Test func requestFollowsXR03AndPX04() throws {
        let ielts = ExamKind.ielts.settings(tasks: ExamKind.ielts.drawTasks())!
        let msgs = [ChatMessage(id: "u1", session: "s", role: .user, text: "I like travelling.", lang: .en, createdAt: Date())]
        let req = try #require(PromptBuilder.examFeedbackRequest(settings: ielts, fixes: [Fix(original: "I goed", corrected: "I went", rule: "past")], messages: msgs))
        #expect(req.purpose == .examFeedback && req.maxTokens == 900)
        for c in ["Fluency and coherence", "Lexical resource", "Grammatical range and accuracy"] { #expect(req.system.contains(c)) }
        #expect(req.system.contains("Write in Russian") && req.system.contains("Never give an overall level, band or score"))
        #expect(req.system.contains("Never mention or assess pronunciation") && req.system.contains("not an official score") == false)
        #expect(req.system.contains("а не официальный балл"))
        #expect(req.messages[0].text.contains("learner: I like travelling.") && req.messages[0].text.contains("I goed → I went | past"))
        let goethe = ExamKind.goetheB1.settings(tasks: ExamKind.goetheB1.drawTasks())!
        let g = try #require(PromptBuilder.examFeedbackRequest(settings: goethe, fixes: [], messages: msgs))
        for c in ["Aufgabenerfüllung", "Kohärenz", "Wortschatz", "Grammatik"] { #expect(g.system.contains(c)) }
    }

    @Test func requestCapsLearnerTurnsAndSkipsWithoutThem() throws {
        let s = ExamKind.ielts.settings(tasks: ExamKind.ielts.drawTasks())!
        let long = (0..<30).map { ChatMessage(id: "u\($0)", session: "s", role: .user, text: String(repeating: "word ", count: 120), lang: .en, createdAt: Date()) }
        let req = try #require(PromptBuilder.examFeedbackRequest(settings: s, fixes: [], messages: long))
        let body = req.messages[0].text
        let turns = body.components(separatedBy: "<learner_turns>\n")[1].components(separatedBy: "\n</learner_turns>")[0]
        #expect(turns.unicodeScalars.count <= PromptBuilder.examFeedbackTurnCap + 30 * 9)  // + "learner: " prefixes
        #expect(turns.components(separatedBy: "\n").count == 30, "every part keeps a share")
        let examiner = [ChatMessage(id: "a", session: "s", role: .assistant, text: "Tell me about your home.", lang: .en, createdAt: Date())]
        #expect(PromptBuilder.examFeedbackRequest(settings: s, fixes: [], messages: examiner) == nil)
        #expect(PromptBuilder.examFeedbackRequest(settings: s, fixes: [], messages: []) == nil)
    }

    // MARK: engine

    @Test func storesOneFilteredSummaryAndNeverRepeats() async throws {
        let p = DebriefProvider([Self.good + "\nPronunciation was clear.\nDie Aussprache war gut."])
        let (engine, store, id) = try await setup("debrief-ok", p)
        #expect(await engine.examDebrief(id) == .stored)
        let s = await summaries(store, id)
        #expect(s.count == 1 && s[0].lang == .ru && !PronunciationFilter.matches(s[0].text) && s[0].text.contains("Ровная речь"))
        #expect(await engine.examDebrief(id) == .skipped)
        #expect(p.all.count == 1 && p.all[0].purpose == .examFeedback)
    }

    @Test func noRequestWithoutLearnerTurnsOrOutsideExams() async throws {
        let p = DebriefProvider([Self.good])
        let (engine, store, id) = try await setup("debrief-empty", p, answers: [])
        #expect(await engine.examDebrief(id) == .skipped)
        let ordinary = try await engine.createSession(SessionSettings(lang: .en, mode: .free))
        _ = try await engine.recordUser(session: ordinary, text: "Hello there.", lang: .en)
        #expect(await engine.examDebrief(ordinary) == .skipped)
        #expect(p.all.isEmpty)
        #expect(await summaries(store, id).isEmpty)
    }

    @Test func failureStoresNothingAndRetrySendsExactlyOneRequest() async throws {
        let p = DebriefProvider([nil, Self.good])
        let (engine, store, id) = try await setup("debrief-retry", p)
        #expect(await engine.examDebrief(id) == .failed)
        #expect(p.all.count == 1, "no automatic retry")
        #expect(await summaries(store, id).isEmpty)
        #expect(await engine.examDebrief(id) == .stored)
        let stored = await summaries(store, id)
        #expect(p.all.count == 2 && stored.count == 1)
    }

    @Test func replyOfOnlyPronunciationLinesIsAFailure() async throws {
        let p = DebriefProvider(["Ваше произношение хорошее.\nYour accent is nice."])
        let (engine, store, id) = try await setup("debrief-pron", p)
        #expect(await engine.examDebrief(id) == .failed)
        #expect(await summaries(store, id).isEmpty)
    }

    @Test func noSecondRequestWhileOneRuns() async throws {
        let p = DebriefProvider([Self.good, Self.good])
        let (engine, store, id) = try await setup("debrief-concurrent", p)
        async let a = engine.examDebrief(id)
        async let b = engine.examDebrief(id)
        let results = await [a, b]
        #expect(results.filter { $0 == .stored }.count == 1)
        let stored = await summaries(store, id)
        #expect(p.all.count == 1 && stored.count == 1)
    }
}
