import Foundation
import Testing
@testable import LingoCore

/// LINGO-05 T-2: statistics (GR-01), the daily goal and the streak (GR-02) on a synthetic Berlin journal with a gap over midnight,
/// the DST change of 2026-10-25, a deleted session, a duplicate fix, a summary message and a goal change. The journal and the expected
/// numbers are the golden fixture `fixtures/teacher/stats.input.jsonl` + `stats.json` for the TS port (LINGO_RECORD_FIXTURES=1).
@Suite struct StatsTests {
    static let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Berlin")!; return c }()
    static func local(_ day: Int, _ h: Int, _ m: Int, _ s: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m, second: s))!
    }
    static let now = local(26, 18, 0)
    static let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/contracts/fixtures/teacher")

    /// The synthetic journal, built from explicit events (fixed ids), so the fixture is byte-stable.
    static func journal() -> [Event] {
        var out: [Event] = []
        func add(_ type: String, _ session: String, _ at: Date, _ payload: some Encodable) {
            let n = out.count + 1
            out.append(Event(id: String(format: "01M5STATS%017d", n), device: "mac-stats0001", seq: n, lamport: n, ts: at, type: type,
                             session: session, payload: try! JSONValue.from(payload)))
        }
        func session(_ id: String, _ lang: Lang, _ at: Date) {
            add(EventType.sessionCreated, id, at, Payload.SessionCreated(title: id, settings: SessionSettings(lang: lang, mode: .free, corrections: [.after])))
        }
        /// `count` messages one minute apart, learner first: (count − 1) minutes of practice.
        func run(_ sid: String, _ lang: Lang, from start: Date, count: Int, step: TimeInterval = 60) {
            for i in 0..<count {
                let role: Role = i % 2 == 0 ? .user : .assistant
                add(EventType.messageCreated, sid, start.addingTimeInterval(Double(i) * step),
                    Payload.MessageCreated(role: role, text: role == .user ? "Ich gehe heute 2 Mal einkaufen, ok?" : "Gut.", lang: lang))
            }
        }
        session("s-de", .de, local(23, 19, 59))
        session("s-en", .en, local(24, 23, 58))
        session("s-gone", .de, local(26, 7, 59))
        add(EventType.goalSet, "", local(24, 9, 0), Payload.GoalSet(minutes: 5))
        add(EventType.goalSet, "", local(26, 7, 0), Payload.GoalSet(minutes: 60))
        add(EventType.goalSet, "", local(26, 7, 1), Payload.GoalSet(minutes: 500))  // clamped to 120 when read; the later event wins
        add(EventType.goalSet, "", local(26, 7, 2), Payload.GoalSet(minutes: 60))
        run("s-de", .de, from: local(23, 20, 0), count: 7)                                   // Oct 23: 6 min, goal 15 → not counted
        run("s-de", .de, from: local(24, 20, 0), count: 7)                                   // Oct 24: 6 min, goal 5 → counted
        add(EventType.messageCreated, "s-de", local(24, 20, 2, 30),
            Payload.MessageCreated(role: .assistant, text: "summary", lang: .de, kind: .summary))  // not counted
        run("s-de", .de, from: local(24, 20, 11), count: 2)                                  // a 5-minute gap → capped at 2 min
        let fix = Fix(original: "Ich habe gegeht", corrected: "Ich bin gegangen", rule: "Perfekt mit sein")
        add(EventType.fixRecorded, "s-de", local(24, 20, 1), Payload.FixRecorded(message: "01M5STATS00000000000000013", fix: fix))
        add(EventType.fixRecorded, "s-de", local(24, 20, 1, 5), Payload.FixRecorded(message: "01M5STATS00000000000000013", fix: fix))  // duplicate
        add(EventType.fixRecorded, "s-de", local(24, 20, 3), Payload.FixRecorded(message: "01M5STATS00000000000000015",
                                                                                   fix: Fix(original: "der Haus", corrected: "das Haus", rule: "Genus")))
        add(EventType.vocabAdded, "", local(23, 19, 0), Payload.VocabAdded(item: .init(lang: .de, text: "einkaufen")))
        let item = out.last!.id
        add(EventType.vocabUsed, "s-de", local(24, 20, 4), Payload.VocabUsed(item: item, message: "m", by: .learner, outcome: .ok))
        add(EventType.vocabUsed, "s-de", local(24, 20, 4), Payload.VocabUsed(item: item, message: "m2", by: .assistant, outcome: .ok))  // not counted
        run("s-en", .en, from: local(24, 23, 58, 30), count: 4)                              // over midnight: 1 min Oct 24, 2 min Oct 25
        // The DST change: 02:58 CEST … 02:04 CET are one local day, 6 minutes apart in real time.
        run("s-en", .en, from: Date(timeIntervalSince1970: 1_792_889_880), count: 7)        // 2026-10-25T00:58:00Z
        run("s-de", .de, from: local(26, 8, 0), count: 7)                                    // Oct 26: 6 min, goal 60 → not counted
        run("s-gone", .de, from: local(26, 9, 0), count: 4)
        add(EventType.fixRecorded, "s-gone", local(26, 9, 1), Payload.FixRecorded(message: "x", fix: fix))
        add(EventType.sessionDeleted, "s-gone", local(26, 10, 0), JSONValue.object([:]))
        return out
    }

    static func dayKey(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func expected(_ st: HistoryState) -> JSONValue {
        func days(_ lang: Lang?) -> JSONValue {
            .object(Dictionary(uniqueKeysWithValues: st.dayStats(lang: lang, calendar: cal).map { d, s in
                (dayKey(d), JSONValue.object(["practiceSeconds": .number(s.practiceSeconds), "practiceMinutes": .number(Double(s.practiceMinutes)),
                                              "sessions": .number(Double(s.sessions)), "learnerWords": .number(Double(s.learnerWords)),
                                              "vocabularyUsed": .number(Double(s.vocabularyUsed)), "mistakes": .number(Double(s.mistakes))]))
            }))
        }
        let rates = st.mistakesPer100Words(calendar: cal)
        let goalDays = (23...26).map { local($0, 12, 0) }
        return .object([
            "rule": .string("LINGO-05 GR-01/GR-02: statistics of stats.input.jsonl in Europe/Berlin at `now`; days are local dates; written by Swift StatsTests."),
            "calendar": .string("Europe/Berlin"),
            "now": .string(Event.formatTS(now)),
            "days": .object(["total": days(nil), "de": days(.de), "en": days(.en)]),
            "mistakesPer100WordsByWeek": .object(Dictionary(uniqueKeysWithValues: rates.map { (dayKey($0.key), JSONValue.number(($0.value * 1e6).rounded() / 1e6)) })),
            "goalByDay": .object(Dictionary(uniqueKeysWithValues: goalDays.map { (dayKey($0), JSONValue.number(Double(st.goalMinutes(on: $0, calendar: cal)))) })),
            "streak": .number(Double(st.streak(now: now, calendar: cal))),
        ])
    }

    @Test func goldenFixture() throws {
        let events = Self.journal()
        let st = Merger.build(events)
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        let input = try events.map { try $0.line() }.joined(separator: "\n") + "\n"
        let output = String(decoding: try enc.encode(Self.expected(st)), as: UTF8.self) + "\n"
        let inURL = Self.dir.appendingPathComponent("stats.input.jsonl"), outURL = Self.dir.appendingPathComponent("stats.json")
        if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" {
            try input.write(to: inURL, atomically: true, encoding: .utf8)
            try output.write(to: outURL, atomically: true, encoding: .utf8)
        }
        #expect(try String(contentsOf: inURL, encoding: .utf8) == input)
        #expect(try String(contentsOf: outURL, encoding: .utf8) == output)
        // The fixture round-trips through the journal codec.
        let parsed = try input.split(separator: "\n").map { try Event(line: $0) }
        #expect(Merger.build(parsed).unknownEvents == 0)
    }

    @Test func practiceSessionsWordsUsesAndMistakes() {
        let st = Merger.build(Self.journal())
        let total = st.dayStats(calendar: Self.cal)
        func day(_ d: Int) -> DayStats { total[Self.cal.startOfDay(for: Self.local(d, 12, 0))] ?? DayStats() }
        #expect(day(23).practiceSeconds == 360)  // the next day's run starts after a break: no phantom minutes
        // Oct 24: 6 min (the summary message does not split the run) + 2 min capped gap + 60 s + 1 min before midnight.
        #expect(day(24).practiceSeconds == 360 + 120 + 60 + 60)
        // Oct 25: 2 min after midnight + 6 min across the DST change.
        #expect(day(25).practiceSeconds == 120 + 360 && day(25).practiceMinutes == 8)
        #expect(day(26).practiceSeconds == 360)  // the deleted session does not count
        #expect(day(24).sessions == 2 && day(25).sessions == 1)
        #expect(day(24).learnerWords == 6 * 6)  // 6 learner messages of 6 words ("2" has no letter)
        #expect(day(24).vocabularyUsed == 1 && day(24).mistakes == 2 && day(26).mistakes == 0)
        #expect(st.dayStats(lang: .en, calendar: Self.cal)[Self.cal.startOfDay(for: Self.local(24, 12, 0))]?.practiceSeconds == 60)
        #expect(HistoryState.wordCount("Ich gehe heute 2 Mal einkaufen, ok?") == 6)
    }

    @Test func goalPerDayAndStreak() async throws {
        let st = Merger.build(Self.journal())
        #expect((23...26).map { st.goalMinutes(on: Self.local($0, 12, 0), calendar: Self.cal) } == [15, 5, 5, 60])
        #expect(st.streak(now: Self.now, calendar: Self.cal) == 2)  // Oct 25 and 24; Oct 26 not reached yet; Oct 23 below 15
        // The engine clamps; a later goal never rewrites past days.
        let store = try JournalStore(base: tempDir("goal"), deviceName: "Mac", deviceID: "mac-goal")
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }
        try await e.setDailyGoal(minutes: 1)
        #expect(await store.state.goalMinutes(on: Date()) == 5)
        try await e.setDailyGoal(minutes: 999)
        #expect(await store.state.goalMinutes(on: Date()) == 120)
    }

    @Test func cardCountsByState() async throws {
        let store = try JournalStore(base: tempDir("cardcounts"), deviceName: "Mac", deviceID: "mac-cc")
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }
        try await e.addVocabulary(lang: .de, entries: [("eins", ""), ("zwei", ""), ("drei", ""), ("vier", "")], source: .list)
        let t = Date(timeIntervalSince1970: 1_793_000_000)
        let ids = await store.state.cards(lang: .de).map(\.id)
        try await store.append(EventType.cardReviewed, session: "w", Payload.CardReviewed(card: ids[0], rating: .good, message: "m"), at: t)
        for (i, d) in [0, 20, 80, 240].enumerated() {  // easy reviews grow S above 21 days
            try await store.append(EventType.cardReviewed, session: "w\(i)", Payload.CardReviewed(card: ids[1], rating: .easy, message: "m"),
                                   at: t.addingTimeInterval(Double(d) * 86_400))
        }
        try await store.append(EventType.cardSuspended, session: "", Payload.CardSuspended(card: ids[3], suspended: true), at: t)
        let c = await store.state.cardCounts(lang: .de, now: t.addingTimeInterval(250 * 86_400), calendar: Self.cal)
        #expect(c == CardCounts(new: 1, learning: 1, mature: 1, dueToday: 1))
    }
}
