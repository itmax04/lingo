import Foundation
import LingoCore
import Testing
@testable import LingoMac

/// LINGO-10 G-5b host behaviour: the Mock preparation (BR-08, BR-08a, BAC-07), notes (BR-22, BAC-11), aids off (BR-20, BAC-16)
/// and the locking of the Goethe screen (BR-37, F2). Synthetic data only: no key, no audio, no network.
@MainActor @Suite(.serialized) struct GoetheMockHostTests {
    func wait(_ condition: () -> Bool) async {
        for _ in 0..<400 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }

    // MARK: Draw (BR-08)

    @Test func theDrawGivesOnePlanningTaskAndTwoDifferentTopicsWithALinkedDiscussion() throws {
        var seen = Set<String>()
        for _ in 0..<40 {
            var draw = try #require(GoetheHub.drawMock())
            #expect(draw.topics.count == 2 && draw.topics[0] != draw.topics[1] && draw.chosen == 0)
            #expect(ExamCatalog.task(draw.planning)?.part == 1)
            seen.insert(draw.topics[0])
            for chosen in 0...1 {
                draw.chosen = chosen
                let s = try #require(draw.selection)
                #expect(ExamCatalog.validMock(ids: s.tasks, partnerTask: s.partner), "the session content passes BR-01")
                #expect(s.tasks[1] == draw.topics[chosen] && s.partner == draw.topics[1 - chosen], "the topic not chosen becomes the partner's (A-03)")
            }
        }
        #expect(seen.count > 1, "the draw is random")
    }

    // MARK: Preparation (BR-08a, BAC-07)

    @Test func preparationHasNoSessionNoMicrophoneAndLocksTheScreen() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        #expect(!e.model.mockActive && !e.model.goetheLocked)
        e.services.beginMockPrep()
        let prep = try #require(e.model.mockPrep)
        #expect(e.model.mockActive && e.model.mockAidsOff && e.model.goetheLocked)
        #expect(!prep.ended && prep.remaining(now: prep.startedAt) == 900)
        await wait { e.sink.micMuted }
        #expect(await e.services.store.state.sessions.isEmpty && e.services.exam == nil, "no session exists during preparation (A-01)")
        // a second Start while preparing changes nothing
        let first = prep.draw
        e.services.beginMockPrep()
        #expect(e.model.mockPrep?.draw == first)
        // the topic may change until the end; the other one becomes the partner's
        e.services.chooseMockTopic(1)
        #expect(e.model.mockPrep?.draw.chosen == 1)
        e.services.chooseMockTopic(7)
        #expect(e.model.mockPrep?.draw.chosen == 1)
    }

    @Test func doneCreatesTheSessionWithTheFrozenSelectionAndKeepsTheNotes() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.beginMockPrep()
        e.services.chooseMockTopic(1)
        let draw = try #require(e.model.mockPrep?.draw)
        e.model.goetheNotes = "meine Notizen"
        e.services.finishMockPrep()
        #expect(e.model.mockPrep?.ended == true)
        e.services.chooseMockTopic(0)
        #expect(e.model.mockPrep?.draw.chosen != 0 || e.model.mockPrep == nil, "the selection is frozen once preparation ends")
        await wait { e.model.examRun?.format == .mock }
        await wait { e.model.mockPrep == nil }
        let sid = try #require(e.services.exam?.sessionID)
        let a = try #require(await e.services.store.state.sessions[sid]?.settings.activity)
        #expect(a.format == .mock && a.tasks == [draw.planning, draw.topics[1], ExamCatalog.tasks(.goetheB1, part: 3).first { $0.linkedTo == draw.topics[1] }!.id])
        #expect(a.partnerTask == draw.topics[0])
        #expect(e.model.goetheNotes == "meine Notizen", "notes stay for the whole run (BR-22)")
        #expect(e.model.mockActive && e.model.mockAidsOff && e.model.goetheLocked, "locked while the Mock runs")
        e.services.stopExam()
        #expect(e.model.goetheNotes.isEmpty && !e.model.mockActive, "gone after the run (A-04)")
    }

    @Test func abandoningThePreparationLeavesNoSessionAndNoNotes() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.beginMockPrep()
        e.model.goetheNotes = "weg damit"
        e.services.discardMockPrep()
        #expect(e.model.mockPrep == nil && e.model.goetheNotes.isEmpty && !e.model.goetheLocked)
        #expect(await e.services.store.state.sessions.isEmpty)
        // the preparation can start again
        e.services.beginMockPrep()
        #expect(e.model.mockPrep != nil)
    }

    @Test func aFailedSessionCreationKeepsThePreparationAndItsNotes() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.beginMockPrep()
        e.model.goetheNotes = "bleibt"
        try FileManager.default.removeItem(at: e.base)
        try Data("not a directory".utf8).write(to: e.base)
        e.services.finishMockPrep()
        await wait { e.model.mockPrep?.failed == true }
        #expect(e.model.goetheNotes == "bleibt" && e.model.mockPrep?.ended == true && e.services.exam == nil && !e.model.startingExam)
        #expect(e.model.banner != nil)
    }

    @Test func aStartCancelledByNavigationDuringCreationLeavesARetryablePreparation() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.beginMockPrep()
        e.model.goetheNotes = "bleibt"
        e.services.finishMockPrep()
        e.services.examSelectionChanged()   // the learner clicks another session while the voice is being set up
        await wait { e.model.mockPrep?.failed == true || e.model.mockPrep == nil }
        #expect(e.model.mockPrep == nil || (e.model.mockPrep?.failed == true && e.model.goetheNotes == "bleibt"))
        #expect(!e.model.startingExam && e.services.exam == nil)
    }

    @Test func anotherExamStartCannotReplaceTheMockPreparation() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.beginMockPrep()
        e.model.goetheNotes = "bleibt"
        e.services.startExam(.ielts)
        #expect(e.model.mockPrep != nil && e.model.goetheNotes == "bleibt" && !e.model.startingExam)
    }

    @Test func aRefusedPreparationSaysWhy() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.readOnly = true
        e.services.beginMockPrep()
        #expect(e.model.banner == e.model.disabledReason && e.model.mockPrep == nil)
    }

    // MARK: Aids off (BR-20, BAC-16)

    @Test func russianShortcutHasNoEffectDuringAMockButWorksInTraining() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.beginMockPrep()
        e.services.toggleRussian()
        #expect(!e.model.russianOnce && e.tc.forceRussianOnce == false)
        e.services.discardMockPrep()
        e.services.toggleRussian()
        #expect(e.model.russianOnce, "outside a Mock the shortcut works as before")
        e.services.toggleRussian()
    }

    @Test func trainingKeepsTheAidsAndALiveTrainingLocksStarts() async throws {
        let e = try ExamHostTests.Env(); defer { e.clean() }
        e.model.online = true
        e.services.startGoetheTraining(teil: 1, task: "b1-plan-park")
        await wait { !e.model.startingExam && e.model.examRun != nil }
        #expect(e.model.trainingLive && e.model.goetheLocked && !e.model.mockAidsOff && !e.model.mockActive, "F2: a live Training locks Start and debrief rows, not the aids")
        let sid = e.services.exam?.sessionID
        e.services.beginMockPrep()
        #expect(e.model.mockPrep == nil && e.services.exam?.sessionID == sid, "a Mock cannot replace a live Training")
        e.services.stopExam()
        #expect(!e.model.trainingLive && !e.model.goetheLocked)
    }

    // MARK: Notes in the panel (BR-22)

    @Test func theMockPanelShowsOneNotesFieldForEveryPart() throws {
        var run = try #require(ExamRun(kind: .goetheB1, tasks: ["b1-plan-park", "b1-talk-bicycle", "b1-discuss-bicycle"], format: .mock, partnerTask: "b1-talk-secondhand", now: Date()))
        var seen = 0
        for _ in 0..<5 {
            let panel = ExamPanel(run: run, busy: false, followUp: false, notes: .constant("x"), onDone: { _ in }, onFinish: {})
            if panel.notesTitle != nil { seen += 1 }
            run.advance(expected: run.phase, timeUp: false, turnRunning: false, now: Date())
        }
        #expect(seen == 5)
    }
}

