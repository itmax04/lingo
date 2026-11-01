import Foundation
import Testing
@testable import LingoCore

/// LINGO-05 T-4: the "Today" summary (GR-03, TAC-13) and the warm-up end data (WR-04, WR-05, TAC-14).
@Suite struct TodayTests {
    static let cal = StatsTests.cal
    private func engine(_ name: String) throws -> (DialogEngine, JournalStore) {
        let store = try JournalStore(base: tempDir(name), deviceName: "Mac", deviceID: "mac-today")
        return (DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }, store)
    }

    @Test func emptyJournalPlansBothLanguagesWithFreeConversation() async throws {
        let (_, store) = try engine("today-empty")
        let t = await store.state.todaySummary(now: StatsTests.now, calendar: Self.cal)
        #expect(t.plans.map(\.lang) == [.de, .en] && t.plans.allSatisfy { $0.next == .freeConversation })
        #expect(t.goalMinutes == 15 && t.minutesToday == 0 && t.streak == 0 && t.week == Array(repeating: false, count: 7) && !t.goalReached)
    }

    @Test func dueCardsMakeTheWarmupTheNextActivity() async throws {
        let (e, store) = try engine("today-warm")
        _ = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.after]))
        try await e.addVocabulary(lang: .de, entries: (1...7).map { ("Wort\($0)", "") }, source: .list)
        let t = await store.state.todaySummary(now: Date(), calendar: Self.cal)
        // Only German has a session, so only German is planned; 5 new cards a day.
        #expect(t.plans == [LanguagePlan(lang: .de, next: .warmup(cards: HistoryState.newCardsPerDay))])
        #expect(t.plans[0].warmupMinutes == 3)  // ⌈5 × 0.6⌉
        // Empty queue → free conversation again.
        let st = await store.state
        for c in st.dueCards(lang: .de, now: Date(), calendar: Self.cal) {
            try await store.append(EventType.cardReviewed, session: "w", Payload.CardReviewed(card: c.id, rating: .good, message: "m"))
        }
        // The 5 new cards of the day are used up and the others are not due before tomorrow → free conversation.
        let after = await store.state.todaySummary(now: Date(), calendar: Self.cal).plans
        #expect(after.first?.next == .freeConversation)
    }

    @Test func goalRingStreakAndWeekDots() throws {
        let st = Merger.build(StatsTests.journal())
        let t = st.todaySummary(now: StatsTests.now, calendar: Self.cal)
        #expect(t.goalMinutes == 60 && t.minutesToday == 8 && !t.goalReached && t.streak == 2)
        // Oct 20…26: only Oct 24 and Oct 25 reached their goals (5 minutes).
        #expect(t.week == [false, false, false, false, true, true, false])
    }

    @Test func warmupSummaryCountsRatingsAndFindsTheNextDueTime() async throws {
        let (e, store) = try engine("today-summary")
        try await e.addVocabulary(lang: .de, entries: [("eins", ""), ("zwei", ""), ("drei", ""), ("vier", "")], source: .list)
        let sid = try #require(try await e.startWarmup(lang: .de, corrections: [.inline]))
        let queue = try #require(await store.state.sessions[sid]?.settings.warmupCards)
        let t = Date()
        let ratings: [CardRating] = [.good, .again, .easy]
        for (i, r) in ratings.enumerated() {
            try await store.append(EventType.cardReviewed, session: sid, Payload.CardReviewed(card: queue[i], rating: r, message: "m\(i)"), at: t)
        }
        var s = try #require(await store.state.warmupSummary(session: sid))
        #expect(s.reviewed == 3 && s.again == 1 && s.hard == 0 && s.good == 1 && s.easy == 1)
        #expect(s.cards.map(\.card.id) == Array(queue.prefix(3)))
        // `again` comes back first (tomorrow at the latest); the easy card is far away.
        let st = await store.state
        #expect(s.nextDue == [queue[0], queue[1], queue[2]].compactMap { st.cardState($0)?.due }.min())
        // Suspending the earliest card moves the next due time to the next one; a non-warm-up session has no summary.
        await e.setCardSuspended(queue[1], true)
        s = try #require(await store.state.warmupSummary(session: sid))
        #expect(s.nextDue == [queue[0], queue[2]].compactMap { st.cardState($0)?.due }.min())
        #expect(await store.state.suspendedCardList(lang: .de).map(\.id) == [queue[1]])
        await e.setCardSuspended(queue[1], false)
        #expect(await store.state.suspendedCardList(lang: .de).isEmpty)
        let plain = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.after]))
        #expect(await store.state.warmupSummary(session: plain) == nil)
    }

    @Test func startingAgainOpensTheUnreviewedWarmupInsteadOfADuplicate() async throws {
        let (e, store) = try engine("today-reuse")
        try await e.addVocabulary(lang: .de, entries: [("eins", ""), ("zwei", "")], source: .list)
        #expect(await e.reusableWarmup(lang: .de) == nil)
        let sid = try #require(try await e.startWarmup(lang: .de, corrections: [.inline]))
        let reuseDE = await e.reusableWarmup(lang: .de), reuseEN = await e.reusableWarmup(lang: .en)
        #expect(reuseDE == sid && reuseEN == nil)
        let queue = try #require(await store.state.sessions[sid]?.settings.warmupCards)
        try await store.append(EventType.cardReviewed, session: sid, Payload.CardReviewed(card: queue[0], rating: .good, message: "m"))
        #expect(await e.reusableWarmup(lang: .de) == nil)  // a warm-up in progress is not reopened as new
    }

    @Test func theEngineSaysWhenTheWarmupIsFinished() async throws {
        let (e, store) = try engine("today-finished")
        try await e.addVocabulary(lang: .de, entries: [("eins", ""), ("zwei", "")], source: .list)
        let sid = try #require(try await e.startWarmup(lang: .de, corrections: [.inline]))
        let queue = try #require(await store.state.sessions[sid]?.settings.warmupCards)
        let before = await e.warmupFinished(sid)
        #expect(!before)
        for c in queue { try await store.append(EventType.cardReviewed, session: sid, Payload.CardReviewed(card: c, rating: .good, message: "m")) }
        let after = await e.warmupFinished(sid), unknown = await e.warmupFinished("no-such-session")
        #expect(after && !unknown)
    }

    @Test func aLanguageWithoutRecentSessionsIsLeftOutOfThePlan() async throws {
        let (e, store) = try engine("today-langs")
        let old = Date().addingTimeInterval(-40 * 86_400)
        try await store.append(EventType.sessionCreated, session: "old-en", Payload.SessionCreated(title: "E", settings: SessionSettings(lang: .en, mode: .free, corrections: [.after])), at: old)
        _ = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.after]))
        let plans = await store.state.todaySummary(now: Date(), calendar: Self.cal).plans
        #expect(plans.map(\.lang) == [.de])  // the English session is 40 days old
    }
}

