import Foundation
import Testing
@testable import LingoCore

/// LINGO-10 G-5a: what the Goethe screen reads from the journal (BR-34 counts, BR-36 Debriefs list) and the Training list (BR-34).
@Suite struct GoetheHubTests {
    static let plan = "b1-plan-park", talk = "b1-talk-bicycle", discuss = "b1-discuss-bicycle", partner = "b1-talk-secondhand"

    private func store(_ name: String) throws -> (JournalStore, DialogEngine) {
        let store = try JournalStore(base: tempDir(name), deviceName: "Mac", deviceID: "mac-gh")
        return (store, DialogEngine(store: store) { fatalError("no model call in these tests") })
    }
    private func say(_ store: JournalStore, _ sid: String, _ role: Role = .user, at: Date = Date()) async throws {
        _ = try await store.append(EventType.messageCreated, session: sid, Payload.MessageCreated(role: role, text: "Hallo", lang: .de, kind: .normal), at: at)
    }
    private func end(_ store: JournalStore, _ sid: String, at: Date = Date()) async throws {
        _ = try await store.append(EventType.sessionEnded, session: sid, payload: .object([:]), at: at)
    }

    @Test func countsLiveGermanExamSessionsWithALearnerMessageLegacyIncluded() async throws {
        let (st, e) = try store("gh1")
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        // Training on the planning task, practised twice (the second one later), plus a legacy exam holding the same task.
        let t1 = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)!)
        try await say(st, t1, at: day)
        let t2 = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)!)
        try await say(st, t2, at: day.addingTimeInterval(86_400))
        let legacy = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss])!)
        try await say(st, legacy, at: day.addingTimeInterval(10))
        // No learner message: not counted. A deleted session: not counted. IELTS: not counted.
        _ = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)!)
        let gone = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)!)
        try await say(st, gone)
        try await e.delete(gone)
        let ielts = try await e.createSession(ExamKind.ielts.settings(tasks: ExamKind.ielts.drawTasks())!)
        try await say(st, ielts)

        let counts = GoetheHub.practice(await st.state)
        #expect(counts[Self.plan]?.count == 3)
        #expect(counts[Self.plan]?.last == day.addingTimeInterval(86_400), "the latest of the sessions")
        #expect(counts[Self.talk]?.count == 1 && counts[Self.discuss]?.count == 1, "a legacy exam counts each of its three tasks once")
        #expect(counts.keys.allSatisfy { ExamCatalog.task($0)?.exam == .goetheB1 }, "IELTS ids never appear")
    }

    @Test func aMockCountsEachOfItsThreeTasksButNotThePartnersTalk() async throws {
        let (st, e) = try store("gh2")
        let sid = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: Self.partner)!)
        try await say(st, sid)
        let counts = GoetheHub.practice(await st.state)
        #expect(counts[Self.plan]?.count == 1 && counts[Self.talk]?.count == 1 && counts[Self.discuss]?.count == 1)
        #expect(counts[Self.partner] == nil)
    }

    @Test func debriefsListsEndedSessionsWithAFormatNewestFirst() async throws {
        let (st, e) = try store("gh3")
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        let training = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.talk], format: .training, teil: 2)!)
        try await say(st, training, at: day); try await end(st, training, at: day.addingTimeInterval(1))
        let mock = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss], format: .mock, partnerTask: Self.partner)!)
        try await say(st, mock, at: day.addingTimeInterval(100)); try await end(st, mock, at: day.addingTimeInterval(101))
        // Not listed: a running Training, a legacy session (no format) and a deleted one.
        let running = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)!)
        try await say(st, running, at: day.addingTimeInterval(200))
        let legacy = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan, Self.talk, Self.discuss])!)
        try await end(st, legacy, at: day.addingTimeInterval(300))
        let gone = try await e.createSession(ExamKind.goetheB1.settings(tasks: [Self.plan], format: .training, teil: 1)!)
        try await end(st, gone, at: day.addingTimeInterval(400)); try await e.delete(gone)

        let list = GoetheHub.debriefs(await st.state)
        #expect(list.map(\.id) == [mock, training])
        #expect(list[0].format == .mock && list[0].teil == nil && list[0].topic == ExamCatalog.task(Self.talk)?.title)
        #expect(list[1].format == .training && list[1].teil == 2 && list[1].topic == ExamCatalog.task(Self.talk)?.title)
    }

    @Test func theTrainingListFollowsTheCatalogueAndFiltersByCategory() {
        for teil in 1...3 {
            let all = GoetheHub.tasks(teil: teil, category: nil)
            #expect(all.count == 12 && all.allSatisfy { $0.part == teil })
            let cats = GoetheHub.categories(teil: teil)
            #expect(cats.count >= 2 && cats == ExamCategory.allCases.filter(cats.contains), "fixed order")
            for c in cats {
                let some = GoetheHub.tasks(teil: teil, category: c)
                #expect(!some.isEmpty && some.allSatisfy { $0.category == c })
            }
            #expect(cats.reduce(0) { $0 + GoetheHub.tasks(teil: teil, category: $1).count } == 12)
        }
    }
}
