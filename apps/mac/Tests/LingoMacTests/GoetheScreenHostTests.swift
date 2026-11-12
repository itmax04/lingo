import Foundation
import LingoCore
import Testing
@testable import LingoMac

/// LINGO-10 G-5a host behaviour: Training start from the Goethe screen (BR-16, BAC-08 start), the panel (R-1, R-5), the debrief card states
/// (BR-30, BR-31) and the Hints of a Training (BR-19). Synthetic data only: no key, no audio, no network.
@MainActor @Suite(.serialized) struct GoetheScreenHostTests {
    static let plan = "b1-plan-park", talk = "b1-talk-bicycle", discuss = "b1-discuss-bicycle"

    func wait(_ condition: () -> Bool) async {
        for _ in 0..<400 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }

    // MARK: Start

    @Test func trainingStartsOnTheChosenTaskWithInlineCorrectionsAndKeepsAPlanOfTeil2() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.goetheNotes = "my plan"
        e.services.startGoetheTraining(teil: 2, task: Self.talk)
        await wait { !e.model.startingExam }
        let sid = try #require(e.services.exam?.sessionID)
        let s = try #require(await e.services.store.state.sessions[sid])
        let a = try #require(s.settings.activity)
        #expect(a.format == .training && a.teil == 2 && a.tasks == [Self.talk] && a.partnerTask == nil && a.exam == "goethe_b1")
        #expect(s.settings.corrections == [.inline] && s.settings.role == "Gesprächspartner")
        #expect(e.model.examRun?.format == .training && e.model.examRun?.phase == .goethe2)
        #expect(e.model.goetheNotes == "my plan", "a plan written before Start stays for the run (BR-22)")
        e.services.stopExam()
        #expect(e.model.goetheNotes.isEmpty, "gone after the run (A-04)")
    }

    @Test func aTeil1TrainingStartsWithoutNotesAndAnInvalidChoiceStartsNothing() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.goetheNotes = "left over"
        e.services.startGoetheTraining(teil: 1, task: Self.talk) // a Teil 2 task for Teil 1
        e.services.startGoetheTraining(teil: 4, task: Self.plan)
        #expect(!e.model.startingExam && e.services.exam == nil)
        #expect(await e.services.store.state.sessions.isEmpty)
        e.services.startGoetheTraining(teil: 1, task: Self.plan)
        await wait { !e.model.startingExam }
        #expect(e.model.examRun?.phase == .goethe1 && e.model.goetheNotes.isEmpty, "Teil 1 has no notes (A-12)")
    }

    @Test func aRefusedStartSaysWhy() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.readOnly = true
        e.services.startGoetheTraining(teil: 1, task: Self.plan)
        #expect(e.model.banner == e.model.disabledReason && e.services.exam == nil)
    }

    // MARK: Panel (R-1, R-5)

    private func panel(_ teil: Int, task: String, advance: Int = 0, busy: Bool = false, followUp: Bool = false) throws -> ExamPanel {
        var run = try #require(ExamRun(kind: .goetheB1, tasks: [task], format: .training, teil: teil, now: Date()))
        for _ in 0..<advance { run.advance(expected: run.phase, timeUp: false, turnRunning: false, now: Date()) }
        return ExamPanel(run: run, busy: busy, followUp: followUp, onDone: { _ in }, onFinish: {})
    }

    @Test func doneStaysEnabledDuringThePartnersTalkButNotDuringAModelReply() throws {
        let talkPart = try panel(3, task: Self.discuss, busy: true)
        #expect(talkPart.run.phase == .goethePartner && !talkPart.doneDisabled, "R-1: Done during the talk")
        let feedback = try panel(3, task: Self.discuss, advance: 1, busy: true)
        #expect(feedback.run.phase == .goetheFeedback && feedback.doneDisabled, "a running reply still blocks Done")
        #expect(try !panel(3, task: Self.discuss, advance: 1).doneDisabled)
        #expect(try panel(1, task: Self.plan, busy: true).doneDisabled)
        #expect(try panel(2, task: Self.talk, followUp: true).doneDisabled)
    }

    @Test func thePartnersTalkIsInTheTrainingPanelWithAGuaranteedHeight() throws {
        let talkPart = try panel(3, task: Self.discuss)
        let talk = try #require(talkPart.run.task.talk)
        #expect(talk.count > 200, "the run holds the whole talk (BR-17)")
        #expect(talkPart.bodyHeight.min >= 200, "the scroll view must not be squeezed to the task lines by the greedy message list")
        #expect(try panel(3, task: Self.discuss, advance: 1).bodyHeight.min >= 160, "the other parts show their plan points too")
    }

    @Test func thePanelLabelSaysWhatEachPartIs() throws {
        #expect(try panel(1, task: Self.plan).partLabel == .number(1))
        #expect(try panel(2, task: Self.talk).partLabel == .number(2))
        #expect(try panel(3, task: Self.discuss).partLabel == .partnerTalk)
        #expect(try panel(3, task: Self.discuss, advance: 1).partLabel == .feedback)
        #expect(try panel(3, task: Self.discuss, advance: 2).partLabel == .number(3))
        let mock = try #require(ExamRun(kind: .goetheB1, tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: "b1-talk-secondhand", now: Date()))
        #expect(ExamPanel(run: mock, busy: false, followUp: false, onDone: { _ in }, onFinish: {}).partLabel == .introduction)
        // IELTS and a legacy German exam keep "Part N".
        let ielts = try #require(ExamRun(kind: .ielts, tasks: ExamKind.ielts.drawTasks(), now: Date()))
        #expect(ExamPanel(run: ielts, busy: false, followUp: false, onDone: { _ in }, onFinish: {}).partLabel == .number(1))
    }

    // MARK: Debrief card and Hints

    private func env(_ settings: SessionSettings, parts: [ExamPhase], learner: Bool, debrief: String? = nil) async throws -> (ExamHostTests.Env, String) {
        let e = try ExamHostTests.Env()
        let sid = try await e.services.engine.createSession(settings)
        let store = e.services.store
        for (i, p) in parts.enumerated() {
            _ = try await store.append(EventType.examPart, session: sid, Payload.ExamPart(part: p))
            if learner && i == 0 { _ = try await store.append(EventType.messageCreated, session: sid, Payload.MessageCreated(role: .user, text: "Ich fahre gern Fahrrad.", lang: .de, kind: .normal)) }
        }
        if let debrief { _ = try await store.append(EventType.messageCreated, session: sid, Payload.MessageCreated(role: .assistant, text: debrief, lang: .ru, kind: .summary)) }
        _ = try await store.append(EventType.sessionEnded, session: sid)
        e.model.apply(await store.state)
        e.model.selectedSessionID = sid
        e.model.refreshSelection()
        return (e, sid)
    }
    private var training1: SessionSettings { ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)! }

    @Test func aTrainingWithNothingFinishedSaysSoInsteadOfOfferingRetry() async throws {
        let (e, _) = try await env(training1, parts: [.goethe1], learner: true)
        defer { e.clean() }
        #expect(e.model.debriefCard == .nothingToAssess && e.model.goetheCard == nil)
        let (e2, _) = try await env(training1, parts: [], learner: false)
        defer { e2.clean() }
        #expect(e2.model.debriefCard == .nothingToAssess, "no learner turn is needed for the Goethe message")
    }

    @Test func aFinishedTeilWithoutAStoredDebriefOffersRetry() async throws {
        let (e, sid) = try await env(training1, parts: [.goethe1, .goetheEnd], learner: true)
        defer { e.clean() }
        #expect(e.model.debriefCard == .unavailable)
        e.model.debriefRunning.insert(sid)
        #expect(e.model.debriefCard == .running)
    }

    @Test func aStoredDebriefIsParsedForTheCardWithPointsComputedByTheApp() async throws {
        let text = """
        [1E] B: Alle Punkte besprochen.
        [1I] A: Gute Reaktionen.
        [1W] C: Einfache Wörter.
        [1S] C: Einige Fehler.
        [T1]
        + Klare Vorschläge
        + Höflich
        > a → b — c
        > d → e — f
        > g → h — i
        """
        let (e, _) = try await env(training1, parts: [.goethe1, .goetheEnd], learner: true, debrief: text)
        defer { e.clean() }
        let card = try #require(e.model.goetheCard)
        #expect(e.model.debriefCard == nil && !card.incomplete && card.structured)
        guard case .scored(let r) = card.teile[0].status else { Issue.record("Teil 1 should be scored"); return }
        #expect(r.points == 6 + 4 + 4 + 4 && card.teile[0].maximum == 28 && card.teile.count == 1, "B 6 + A 4 + C 4 + C 4 over 28")
        #expect(r.strengths.count == 2 && r.improvements.count == 3)
    }

    @Test func aLegacyGermanExamKeepsItsOldCardAndNeverGetsAGoetheCard() async throws {
        let legacy = ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss])!
        let (e, _) = try await env(legacy, parts: [.goethePrep, .goethe1], learner: true, debrief: "Fluency and coherence: B1–B2")
        defer { e.clean() }
        #expect(e.model.goetheCard == nil && e.model.goethePlan == nil && e.model.debriefCard == nil)
        let (e2, _) = try await env(legacy, parts: [.goethePrep], learner: true)
        defer { e2.clean() }
        #expect(e2.model.debriefCard == .unavailable, "the legacy Retry card is unchanged")
    }

    @Test func trainingTeilIsKnownOnlyForATrainingSession() async throws {
        let (e, _) = try await env(ExamKind.goetheB1.settings(tasks: [Self.talk], format: .training, teil: 2)!, parts: [], learner: false)
        defer { e.clean() }
        #expect(e.model.trainingTeil == 2)
        let mock = ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: "b1-talk-secondhand")!
        let (e2, _) = try await env(mock, parts: [], learner: false)
        defer { e2.clean() }
        #expect(e2.model.trainingTeil == nil)
        #expect((1...3).allSatisfy { !ExamCatalog.goethePhrases(teil: $0).isEmpty }, "the Training Hints have phrases for every Teil")
    }
}
