import Foundation
import Testing
@testable import LingoCore

/// LINGO-05 T-1: FSRS-5 schedule (CR-03), cards (CR-01), reviews (CR-02) and the due queue (CR-04).
@Suite struct FSRSTests {
    static let t0 = Date(timeIntervalSince1970: 1_793_000_000)
    static func days(_ d: Double) -> Date { t0.addingTimeInterval(d * 86_400) }
    static let utc: Date = { var c = DateComponents(); c.year = 2022; c.month = 11; c.day = 29; c.hour = 12; c.minute = 30
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!; return cal.date(from: c)! }()

    // The next four tests repeat the expectations of py-fsrs 5.1.3 `tests/test_basic.py` with its default profile: an independent
    // check of the port (the reference code itself is not run here).
    @Test func referenceIntervalHistory() throws {
        let ratings: [CardRating] = [.good, .good, .good, .good, .good, .good, .again, .again, .good, .good, .good, .good, .good]
        var st: CardState?, at = Self.utc, history: [Int] = []
        for r in ratings {
            let next = FSRS.review(st, rating: r, at: at, profile: .reference)
            history.append(FSRS.elapsedDays(from: next.lastReview, to: next.due))
            at = next.due
            st = next
        }
        #expect(history == [0, 4, 14, 44, 125, 328, 0, 0, 7, 16, 34, 71, 142])  // test_review_card
    }

    @Test func referenceMemoState() throws {
        var st: CardState?, at = Self.utc
        for (r, ivl) in zip([CardRating.again, .good, .good, .good, .good, .good], [0.0, 0, 1, 3, 8, 21]) {
            st = FSRS.review(st, rating: r, at: at, profile: .reference)
            at = at.addingTimeInterval(ivl * 86_400)
        }
        let s = FSRS.review(st, rating: .good, at: at, profile: .reference)
        #expect(s.stability.rounded() == 49)  // test_memo_state
        #expect((s.difficulty * 10_000).rounded() / 10_000 == 7.0866)
    }

    @Test func referenceRepeatedEasyAndRelearning() throws {
        var st: CardState?
        for i in 0..<10 { st = FSRS.review(st, rating: .easy, at: Self.utc.addingTimeInterval(Double(i) * 1e-6), profile: .reference) }
        #expect(st?.difficulty == 1.0)  // test_repeated_correct_reviews
        // test_review_state / test_relearning
        var c = FSRS.review(nil, rating: .good, at: Self.utc, profile: .reference)
        c = FSRS.review(c, rating: .good, at: c.due, profile: .reference)
        #expect(c.phase == .review && c.step == nil)
        c = FSRS.review(c, rating: .good, at: c.due, profile: .reference)
        c = FSRS.review(c, rating: .again, at: c.due, profile: .reference)
        #expect(c.phase == .relearning && c.step == 0 && c.due.timeIntervalSince(c.lastReview) == 600)
        c = FSRS.review(c, rating: .again, at: c.due, profile: .reference)
        #expect(c.phase == .relearning && c.step == 0 && c.due.timeIntervalSince(c.lastReview) == 600)
        c = FSRS.review(c, rating: .good, at: c.due, profile: .reference)
        #expect(c.phase == .review && c.step == nil && c.due.timeIntervalSince(c.lastReview) >= 86_400)
        // Learning steps: good → 10 min, again → 1 min, hard → 5.5 min (test_*_learning_steps).
        #expect(FSRS.review(nil, rating: .good, at: Self.utc, profile: .reference).due.timeIntervalSince(Self.utc) == 600)
        #expect(FSRS.review(nil, rating: .again, at: Self.utc, profile: .reference).due.timeIntervalSince(Self.utc) == 60)
        #expect(FSRS.review(nil, rating: .hard, at: Self.utc, profile: .reference).due.timeIntervalSince(Self.utc) == 330)
        #expect(FSRS.review(nil, rating: .easy, at: Self.utc, profile: .reference).phase == .review)
    }

    @Test func lingoProfileHasNoMinuteSteps() throws {
        // test_no_learning_steps / test_no_relearning_steps: every answer schedules whole days.
        for r in CardRating.allCases {
            let first = FSRS.review(nil, rating: r, at: Self.t0)
            #expect(first.phase == .review && first.stability == max(FSRS.w[r.grade - 1], 0.1))
            #expect(FSRS.elapsedDays(from: first.lastReview, to: first.due) >= 1)
        }
        let lapse = try #require(FSRS.schedule([(.good, Self.t0), (.good, Self.days(3)), (.again, Self.days(20))]))
        #expect(lapse.phase == .review && lapse.lapses == 1 && FSRS.elapsedDays(from: lapse.lastReview, to: lapse.due) >= 1)
        #expect(FSRS.review(nil, rating: .again, at: Self.t0).lapses == 0)  // a first `again` is not a lapse
        // Exact multiples of a day are never one short; negative spans round down like Python.
        #expect(FSRS.elapsedDays(from: Self.t0.addingTimeInterval(0.1), to: Self.t0.addingTimeInterval(0.1 + 3 * 86_400)) == 3)
        #expect(FSRS.elapsedDays(from: Self.days(1), to: Self.t0.addingTimeInterval(86_400 - 1)) == -1)
    }

    @Test func easierAnswersGrowStabilityMoreAndLapsesShrinkIt() throws {
        let base: [(CardRating, Date)] = [(.good, Self.t0)]
        func after(_ r: CardRating) throws -> CardState { try #require(FSRS.schedule(base + [(r, Self.days(4))])) }
        let (again, hard, good, easy) = (try after(.again), try after(.hard), try after(.good), try after(.easy))
        #expect(again.stability < hard.stability && hard.stability < good.stability && good.stability < easy.stability)
        #expect(again.stability <= FSRS.w[2] / exp(FSRS.w[17] * FSRS.w[18]) + 1e-12)  // the post-lapse cap
        #expect(again.difficulty > good.difficulty && easy.difficulty < good.difficulty)
        // A later review (lower retrievability) grows stability more than an early one.
        let early = try #require(FSRS.schedule(base + [(.good, Self.days(2))]))
        let late = try #require(FSRS.schedule(base + [(.good, Self.days(8))]))
        #expect(late.stability > early.stability)
    }

    @Test func sameDayReviewsWholeDaysAndTheCap() throws {
        let s = try #require(FSRS.schedule([(.good, Self.t0), (.good, Self.t0.addingTimeInterval(3600))]))
        #expect(abs(s.stability - FSRS.w[2] * exp(FSRS.w[17] * FSRS.w[18])) < 1e-9)
        // 2.99 days count as 2 whole days, like the reference.
        #expect(FSRS.elapsedDays(from: Self.t0, to: Self.days(2.99)) == 2 && FSRS.elapsedDays(from: Self.t0, to: Self.days(0.99)) == 0)
        #expect(FSRS.intervalDays(10_000) == 365 && FSRS.intervalDays(0.01) == 1)
        #expect(abs(FSRS.retrievability(days: 7, stability: 7) - 0.9) < 1e-9)  // at t = S the recall chance is the target 0.9
    }

    /// Vectors of the app profile for the TS port (CR-03): `fixtures/teacher/fsrs.json`, written here with LINGO_RECORD_FIXTURES=1.
    /// The port is checked against py-fsrs above; these vectors pin the app profile on top of it.
    @Test func goldenVectors() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/contracts/fixtures/teacher/fsrs.json")
        let sequences: [(String, [(CardRating, Double)])] = [
            ("good every interval", [(.good, 0), (.good, 3), (.good, 13), (.good, 50)]),
            ("lapse then relearn", [(.good, 0), (.good, 3), (.again, 20), (.good, 21), (.good, 23)]),
            ("hard and easy", [(.hard, 0), (.easy, 2), (.hard, 9), (.easy, 15)]),
            ("same day", [(.again, 0), (.again, 0.01), (.good, 0.02), (.good, 1.5)]),
            ("again first, long gap (post-lapse cap)", [(.again, 0), (.again, 10), (.good, 11)]),
            ("long gap and interval cap", [(.good, 0), (.easy, 400), (.easy, 800)]),
            ("partial days are floored", [(.good, 0), (.good, 2.99), (.good, 9.5)]),
        ]
        var cases: [JSONValue] = []
        for (name, seq) in sequences {
            var states: [JSONValue] = []
            var st: CardState?
            for (r, d) in seq {
                let s = FSRS.review(st, rating: r, at: Self.days(d))
                st = s
                states.append(.object(["stability": .number((s.stability * 1e6).rounded() / 1e6), "difficulty": .number((s.difficulty * 1e6).rounded() / 1e6),
                                       "due": .string(Event.formatTS(s.due))]))
            }
            cases.append(.object(["name": .string(name), "start": .string(Event.formatTS(Self.t0)),
                                  "reviews": .array(seq.map { .array([.string($0.0.rawValue), .number($0.1)]) }), "states": .array(states)]))
        }
        let file = JSONValue.object(["rule": .string("LINGO-05 CR-03: FSRS-5 as py-fsrs 5.1.3 with the Lingo profile (default parameters, retention 0.9, no learning or relearning steps, maximum interval 365, no fuzzing, whole elapsed days). Review times are days after `start`; stability and difficulty rounded to 6 decimals; compare with a tolerance of 1e-6. Written by Swift FSRSTests, whose port is checked against the py-fsrs test expectations."),
                                     "cases": .array(cases)])
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        let text = String(decoding: try enc.encode(file), as: UTF8.self) + "\n"
        if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" { try text.write(to: url, atomically: true, encoding: .utf8) }
        else { #expect(try String(contentsOf: url, encoding: .utf8) == text) }
    }
}

@Suite struct TeacherCardTests {
    private func engine(_ name: String) throws -> (DialogEngine, JournalStore) {
        let store = try JournalStore(base: tempDir(name), deviceName: "Mac", deviceID: "mac-t1")
        return (DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }, store)
    }

    private func fix(_ store: JournalStore, _ sid: String, _ o: String, _ c: String, _ rule: String, at: Date) async throws {
        try await store.append(EventType.fixRecorded, session: sid, Payload.FixRecorded(message: "m", fix: Fix(original: o, corrected: c, rule: rule)), at: at)
    }

    private func review(_ store: JournalStore, _ card: String, _ r: CardRating, session: String = "w1", message: String = "m", at: Date) async throws {
        try await store.append(EventType.cardReviewed, session: session, Payload.CardReviewed(card: card, rating: r, message: message), at: at)
    }

    @Test func wordAndMistakeCards() async throws {
        let (e, store) = try engine("cards-1")
        try await e.addVocabulary(lang: .de, entries: [("Feierabend", "конец дня")], source: .manual)
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.after]))
        let t = FSRSTests.t0
        try await fix(store, sid, "seit zwei Jahre", "seit zwei Jahren", "Dativ nach seit", at: t)
        try await fix(store, sid, "Seit zwei Jahre", "seit zwei Jahren!", "dativ nach seit", at: t.addingTimeInterval(30))  // same original: once
        try await fix(store, sid, "seit drei Monate", "seit drei Monaten hier", "dativ nach seit!", at: t.addingTimeInterval(60))
        try await fix(store, sid, "ich habe gegeht", "ich bin gegangen", "Perfekt mit sein", at: t.addingTimeInterval(120))  // once: no card
        let st = await store.state
        let cards = st.cards(lang: .de)
        #expect(cards.map(\.kind) == [.mistake, .word])
        let m = try #require(cards.first)
        #expect(m.id == "mistake:de:dativ nach seit" && m.front == "seit zwei Jahren" && m.hint == "dativ nach seit!")
        #expect(m.createdAt == t.addingTimeInterval(60))
        #expect(cards[1].id == "word:de:feierabend" && cards[1].front == "Feierabend" && cards[1].hint == "конец дня")
        #expect(st.cards(lang: .en).isEmpty)
        // A long rule is cut to the key limit.
        let long = String(repeating: "Wortstellung im Nebensatz ", count: 5)
        try await fix(store, sid, "weil ich habe", "weil ich habe Zeit", long, at: t.addingTimeInterval(200))
        try await fix(store, sid, "dass er ist", "dass er krank ist", long + "!", at: t.addingTimeInterval(210))
        let longCard = try #require(await store.state.mistakeCards(lang: .de).first { $0.hint.hasPrefix("Wortstellung") })
        #expect(longCard.id.count == "mistake:de:".count + HistoryState.mistakeKeyLimit && longCard.hint.count <= HistoryState.mistakeHintLimit)
        // Fixes without a rule are not grouped.
        try await fix(store, sid, "ein Haus", "das Haus", "", at: t.addingTimeInterval(220))
        try await fix(store, sid, "ein Auto", "das Auto", "", at: t.addingTimeInterval(230))
        #expect(await !store.state.mistakeCards(lang: .de).contains { $0.id == "mistake:de:" })
        // Removing the item removes its card; its reviews stay and apply again when the same text comes back.
        try await review(store, "word:de:feierabend", .good, at: t)
        let item = try #require(await store.state.vocabulary(lang: .de).first)
        try await e.removeVocabulary(item.id)
        #expect(await !store.state.cards(lang: .de).contains { $0.kind == .word })
        try await e.addVocabulary(lang: .de, entries: [("feierabend", "")], source: .manual)
        let back = await store.state
        #expect(back.cards(lang: .de).contains { $0.id == "word:de:feierabend" } && back.cardState("word:de:feierabend")?.reviews == 1)
    }

    @Test func starredPhraseAndOwnItemShareOneCard() async throws {
        let (e, store) = try engine("cards-star")
        let t = FSRSTests.t0
        // A ★ phrase alone is a card; its review is kept under the key-based id.
        try await store.append(EventType.phraseStarred, session: "", Payload.PhraseMark(phrase: Phrase(lang: .de, text: "Genau!", translation: "", source: .topic)), at: t)
        #expect(await store.state.cards(lang: .de).map(\.id) == ["word:de:genau"])
        // An own item hides a ★ phrase with the same key (VR-02, e.g. synced from another device): still one card, the same id, the own
        // item's text and translation, and the ★ phrase's earlier date.
        try await e.addVocabulary(lang: .de, entries: [("Na klar", "конечно")], source: .manual)
        try await store.append(EventType.phraseStarred, session: "", Payload.PhraseMark(phrase: Phrase(lang: .de, text: "Na klar!", translation: "", source: .topic)), at: t)
        try await review(store, "word:de:na klar", .good, at: t.addingTimeInterval(60))
        let st = await store.state
        let card = try #require(st.cards(lang: .de).first { $0.id == "word:de:na klar" })
        #expect(st.cards(lang: .de).count == 2 && card.front == "Na klar" && card.hint == "конечно" && card.createdAt == t)
        #expect(st.cardState(card.id)?.reviews == 1)
    }

    @Test func reviewsScheduleAndTheDueQueue() async throws {
        let (e, store) = try engine("cards-2")
        try await e.addVocabulary(lang: .de, entries: (1...8).map { ("Wort\($0)", "") }, source: .list)
        let t = FSRSTests.t0
        let ids = await store.state.cards(lang: .de).map(\.id)
        try await review(store, ids[0], .good, at: t)
        try await review(store, ids[1], .again, at: t)
        try await review(store, ids[1], .easy, message: "m2", at: t.addingTimeInterval(5))  // the same session: not counted
        try await review(store, "word:de:unknown", .good, at: t)
        let st = await store.state
        #expect(st.cardReviews[ids[1]]?.map(\.rating) == [.again])
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        // Right after: `again` is due tomorrow and `good` in 3 days; 3 cards of the language were first reviewed today (incl. the card
        // that no longer exists) → 2 more new cards.
        let now = t.addingTimeInterval(11 * 60)
        let q = st.dueCards(lang: .de, now: now, calendar: cal)
        #expect(!q.contains { $0.id == ids[0] || $0.id == ids[1] } && q.count == 2)
        #expect(q.map(\.id) == Array(ids[2...3]))
        // Due on its local day: the `again` card is due all day tomorrow, even before its exact due time.
        let tomorrowMorning = cal.startOfDay(for: t.addingTimeInterval(86_400)).addingTimeInterval(60)
        #expect(st.dueCards(lang: .de, now: tomorrowMorning, calendar: cal).first?.id == ids[1])
        // The 25-hour DST day (Berlin, 2026-10-25): reviewed at 00:30, due 24 h later at 23:30 the same local day — not due again today.
        let dst = cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 0, minute: 30))!
        try await review(store, ids[7], .again, session: "dst", at: dst)
        let dstState = await store.state
        #expect(cal.isDate(dstState.cardState(ids[7])!.due, inSameDayAs: dst))
        #expect(!dstState.dueCards(lang: .de, now: dst.addingTimeInterval(23.5 * 3600), calendar: cal).contains { $0.id == ids[7] })
        // Days later both are due; the lower retrievability (the lapsed card) comes first, and a new day allows 5 new cards again.
        let later = t.addingTimeInterval(20 * 86_400)
        let q2 = st.dueCards(lang: .de, now: later, calendar: cal)
        #expect(Array(q2.prefix(2).map(\.id)) == [ids[1], ids[0]] && q2.count == 2 + 5)
        #expect(st.cardState("word:de:unknown") != nil && !st.cards(lang: .de).contains { $0.id == "word:de:unknown" })
        // A later session counts again.
        try await review(store, ids[1], .good, session: "w2", at: later)
        #expect(await store.state.cardReviews[ids[1]]?.count == 2)
    }

    @Test func suspendedCardsLeaveTheQueue() async throws {
        let (e, store) = try engine("cards-3")
        try await e.addVocabulary(lang: .de, entries: [("eins", ""), ("zwei", "")], source: .list)
        let ids = await store.state.cards(lang: .de).map(\.id)
        let t = FSRSTests.t0
        try await store.append(EventType.cardSuspended, session: "", Payload.CardSuspended(card: ids[0], suspended: true), at: t)
        #expect(await store.state.dueCards(lang: .de, now: t).map(\.id) == [ids[1]])
        try await store.append(EventType.cardSuspended, session: "", Payload.CardSuspended(card: ids[0], suspended: false), at: t.addingTimeInterval(1))
        #expect(await store.state.dueCards(lang: .de, now: t).map(\.id) == ids)
    }

    @Test func queueOrderTieBreaksAndTheNewCardLimit() async throws {
        let (e, store) = try engine("cards-4")
        let t = FSRSTests.t0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin")!
        // New cards come by createdAt, not by id: "zebra" was added first.
        try await store.append(EventType.vocabAdded, session: "", Payload.VocabAdded(item: .init(lang: .de, text: "zebra")), at: t)
        try await store.append(EventType.vocabAdded, session: "", Payload.VocabAdded(item: .init(lang: .de, text: "apfel")), at: t.addingTimeInterval(60))
        #expect(await store.state.dueCards(lang: .de, now: t, calendar: cal).map(\.id) == ["word:de:zebra", "word:de:apfel"])
        // Fixes of deleted and other-language sessions make no card.
        let gone = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.after]))
        let english = try await e.createSession(SessionSettings(lang: .en, mode: .free, corrections: [.after]))
        for (i, sid) in [gone, english].enumerated() {
            try await fix(store, sid, "a\(i)", "b\(i)", "Regel", at: t)
            try await fix(store, sid, "c\(i)", "d\(i)", "Regel", at: t.addingTimeInterval(1))
        }
        try await e.delete(gone)
        #expect(await store.state.mistakeCards(lang: .de).isEmpty)
        // Equal retrievability: the mistake card first, then older cards first.
        let live = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.after]))
        try await fix(store, live, "a", "b", "Regel", at: t)
        try await fix(store, live, "c", "d", "Regel", at: t.addingTimeInterval(1))
        for id in ["word:de:apfel", "word:de:zebra", "mistake:de:regel"] { try await review(store, id, .good, at: t.addingTimeInterval(120)) }
        let later = t.addingTimeInterval(10 * 86_400)
        #expect(await store.state.dueCards(lang: .de, now: later, calendar: cal).map(\.id) == ["mistake:de:regel", "word:de:zebra", "word:de:apfel"])
        // A card first reviewed today still counts against the new-card limit after it is suspended.
        try await e.addVocabulary(lang: .de, entries: (1...6).map { ("neu\($0)", "") }, source: .list)
        let today = later
        try await review(store, "word:de:neu1", .good, session: "w9", at: today)
        try await store.append(EventType.cardSuspended, session: "", Payload.CardSuspended(card: "word:de:neu1", suspended: true), at: today)
        let fresh = await store.state.dueCards(lang: .de, now: today, calendar: cal).filter { $0.id.hasPrefix("word:de:neu") }
        #expect(fresh.count == HistoryState.newCardsPerDay - 1 && !fresh.contains { $0.id == "word:de:neu1" })
    }

    /// The shared edge journal: one counted review; each malformed card event (bad source, no message, bad rating, non-bool) is unknown.
    @Test func edgeFixtureCardState() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/contracts/fixtures/events/edge.jsonl")
        let events = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map { try Event(line: $0) }
        let st = Merger.build(events)
        #expect(st.cardReviews["word:de:hallo"]?.map(\.rating) == [.good] && st.suspendedCards == ["word:de:hallo"])
        let malformed = events.filter { $0.type.hasPrefix("card.") }.count - 2
        #expect(malformed == 4)
    }
}
