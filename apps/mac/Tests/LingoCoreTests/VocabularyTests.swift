import Foundation
import Testing
@testable import LingoCore

private let contracts = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("packages/contracts/fixtures/vocab")

private func isoDate(_ s: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f.date(from: s)!
}

@Suite struct VocabularyTextTests {
    struct TextFile: Decodable {
        struct Norm: Decodable { let `in`: String; let out: String }
        struct Key: Decodable { let lang: Lang; let text: String; let out: String }
        struct Entry: Decodable { let text: String; let translation: String }
        struct Parse: Decodable { let `in`: String; let entries: [Entry]; let rejected: Int }
        let normalize: [Norm]
        let key: [Key]
        let parseList: Parse
    }

    @Test func textRulesMatchTheGoldenFixture() throws {
        let f = try JSONDecoder().decode(TextFile.self, from: Data(contentsOf: contracts.appendingPathComponent("text.json")))
        for c in f.normalize { #expect(VocabularyText.normalize(c.in) == c.out, "\(c.in)") }
        for c in f.key { #expect(VocabularyText.key(lang: c.lang, text: c.text) == c.out) }
        let parsed = VocabularyText.parseList(f.parseList.in)
        #expect(parsed.entries.map(\.text) == f.parseList.entries.map(\.text))
        #expect(parsed.entries.map(\.translation) == f.parseList.entries.map(\.translation))
        #expect(parsed.rejected == f.parseList.rejected)
    }

    @Test func longLinesAndTheLineLimitAreRejected() {
        let long = String(repeating: "x", count: 121)
        #expect(VocabularyText.parseList("\(long) — перевод\nok").rejected == 1)
        let many = (1...205).map { "word\($0)" }.joined(separator: "\n")
        let r = VocabularyText.parseList(many)
        #expect(r.entries.count == 200 && r.rejected == 5)
    }
}

@Suite struct VocabularyContractTests {
    struct SelectionFile: Decodable {
        struct Item: Decodable { let id: String; let lang: Lang; let text: String; let createdAt: String; let offered: Int; let used: Int; let mistakes: Int; let lastPractised: String? }
        struct Case: Decodable { let name: String; let lang: Lang; let count: Int; let usedInSession: [String]; let pinned: String?; let items: [Item]; let expected: [String] }
        let cases: [Case]
    }
    struct MatchingFile: Decodable {
        struct Case: Decodable { let lang: Lang; let item: String; let utterance: String; let expected: Bool }
        let cases: [Case]
    }

    @Test func selectionMatchesTheGoldenFixture() throws {
        let f = try JSONDecoder().decode(SelectionFile.self, from: Data(contentsOf: contracts.appendingPathComponent("selection.json")))
        #expect(f.cases.count >= 3)
        for c in f.cases {
            let items = c.items.map { VocabItem(id: $0.id, lang: $0.lang, text: $0.text, createdAt: isoDate($0.createdAt), offered: $0.offered,
                                                used: $0.used, mistakes: $0.mistakes, lastPractised: $0.lastPractised.map(isoDate)) }
            let got = VocabularySelection.select(items, lang: c.lang, usedInSession: Set(c.usedInSession), count: c.count, pinned: c.pinned).map(\.id)
            #expect(got == c.expected, "\(c.name)")
        }
    }

    @Test func matchingMatchesTheGoldenFixture() throws {
        let f = try JSONDecoder().decode(MatchingFile.self, from: Data(contentsOf: contracts.appendingPathComponent("matching.json")))
        #expect(f.cases.count >= 30)
        for c in f.cases { #expect(VocabularyMatcher.contains(c.item, in: c.utterance, lang: c.lang) == c.expected, "\(c.item) in \(c.utterance)") }
    }
}

@Suite struct VocabularyJournalTests {
    private func engine(_ name: String, device: String = "mac-voc1") throws -> (DialogEngine, JournalStore) {
        let store = try JournalStore(base: tempDir(name), deviceName: "Mac", deviceID: device)
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }
        return (e, store)
    }

    @Test func addingAListSkipsDuplicatesAndEmptyLines() async throws {
        let (e, store) = try engine("voc-add")
        let r1 = try await e.addVocabulary(lang: .de, entries: VocabularyText.parseList("Feierabend — конец дня\n\nFernweh").entries, source: .list)
        #expect(r1.added == 2 && r1.duplicates == 0)
        let r2 = try await e.addVocabulary(lang: .de, entries: [("feierabend!", ""), ("eine Ausrede", "отговорка")], source: .manual)
        #expect(r2.added == 1 && r2.duplicates == 1)
        let r3 = try await e.addVocabulary(lang: .en, entries: [("Feierabend", "")], source: .manual)  // other language: not a duplicate
        #expect(r3.added == 1)
        let st = await store.state
        #expect(st.vocabulary(lang: .de).map(\.text).sorted() == ["Feierabend", "Fernweh", "eine Ausrede"])
        #expect(st.vocabulary(lang: .de).first { $0.text == "Feierabend" }?.translation == "конец дня")
    }

    @Test func updatesAndRemovalsAreLastWriterWinsAcrossDevices() async throws {
        let shared = tempDir("voc-sync")
        let folder = SyncFolder(picked: shared.appendingPathComponent("Lingo"))
        try FileManager.default.createDirectory(at: folder.picked, withIntermediateDirectories: true)
        let (a, sa) = try engine("voc-a", device: "mac-vaaa")
        let (b, sb) = try engine("voc-b", device: "web-vbbb")
        try await a.addVocabulary(lang: .en, entries: [("to break the ice", "")], source: .manual)
        _ = await sa.sync(with: folder); _ = await sb.sync(with: folder)
        let id = try #require(await sb.state.vocabulary(lang: .en).first?.id)
        try await b.updateVocabulary(id, translation: "растопить лёд")
        try await a.updateVocabulary(id, note: "at a party")
        _ = await sb.sync(with: folder); _ = await sa.sync(with: folder); _ = await sb.sync(with: folder)
        for s in [sa, sb] {
            let item = try #require(await s.state.vocab[id])
            #expect(item.translation == "растопить лёд" && item.note == "at a party")
        }
        try await a.removeVocabulary(id)
        _ = await sa.sync(with: folder); _ = await sb.sync(with: folder)
        #expect(await sb.state.vocab[id] == nil)
    }

    @Test func usageEventsBuildStatisticsAndSessionUse() async throws {
        let (e, store) = try engine("voc-use")
        try await e.addVocabulary(lang: .de, entries: [("Feierabend", "")], source: .manual)
        let id = try #require(await store.state.vocabulary(lang: .de).first?.id)
        for (by, outcome, msg) in [(VocabActor.assistant, VocabOutcome.ok, "m1"), (.learner, .mistake, "m2"), (.learner, .ok, "m3"),
                                   (.learner, .ok, "m3")] {  // the last one repeats (item, by, message): not counted again
            try await store.append(EventType.vocabUsed, session: "s1", Payload.VocabUsed(item: id, message: msg, by: by, outcome: outcome))
        }
        let st = await store.state
        let item = try #require(st.vocab[id])
        #expect(item.offered == 1 && item.mistakes == 1 && item.used == 1 && item.lastPractised != nil)
        #expect(st.vocabUsedInSession["s1"] == [id])
    }

    @Test func starredPhrasesAreItemsAndRemovingOneUnstarsIt() async throws {
        let (e, store) = try engine("voc-star")
        let p = Phrase(lang: .en, text: "Nice to meet you.", translation: "Приятно познакомиться.", source: .topic)
        try await e.star(p, on: true)
        let items = await store.state.vocabulary(lang: .en)
        #expect(items.count == 1 && items[0].source == .starred && items[0].translation == "Приятно познакомиться.")
        // A manual item with the same text is shown once.
        try await e.addVocabulary(lang: .en, entries: [("nice to meet you", "")], source: .manual)
        #expect(await store.state.vocabulary(lang: .en).count == 1)
        try await e.removeVocabulary(items[0].id)
        #expect(await store.state.starred.isEmpty)
    }

    @Test func profileIsLastWriterWinsPerField() async throws {
        let (e, store) = try engine("voc-prof")
        try await e.updateProfile(goals: "B2 exam in spring", interests: "football")
        try await e.updateProfile(interests: "football, cooking")
        let p = await store.state.profile
        #expect(p.goals == "B2 exam in spring" && p.interests == "football, cooking")
    }
}

@Suite struct VocabularyEventsFixtureTests {
    /// `fixtures/vocab/events.jsonl` is written by the real Swift code (LINGO_RECORD_FIXTURES=1) and must round-trip byte for byte.
    @Test func eventsFixtureRoundTripsAndBuildsState() async throws {
        let url = contracts.appendingPathComponent("events.jsonl")
        if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" {
            let store = try JournalStore(base: tempDir("voc-fx"), deviceName: "Mac", deviceID: "mac-fixture",
                                         clock: { Date(timeIntervalSince1970: 1_761_904_800) })
            let e = DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }
            try await e.addVocabulary(lang: .de, entries: [("Feierabend", "конец рабочего дня")], source: .manual)
            let id = try #require(await store.state.vocabulary(lang: .de).first?.id)
            try await e.updateVocabulary(id, note: "nach der Arbeit")
            try await store.append(EventType.vocabUsed, session: "s1", Payload.VocabUsed(item: id, message: "01K8WVBC80M0000000000000AA", by: .learner, outcome: .ok))
            try await e.updateProfile(goals: "B2 exam", interests: "football")
            try await e.removeVocabulary(id)
            let lines = try JournalReader.readDevice(store.ownDir).events.map { try $0.line() }
            try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.count == 5)
        let events = try lines.map { try Event(line: Substring($0)) }
        #expect(try events.map { try $0.line() } == lines)
        #expect(Set(events.map(\.type)) == [EventType.vocabAdded, EventType.vocabUpdated, EventType.vocabUsed, EventType.profileUpdated, EventType.vocabRemoved])
        let st = Merger.build(events)
        #expect(st.vocab.isEmpty && st.unknownEvents == 0 && st.profile.goals == "B2 exam")
    }
}


@Suite struct VocabularyMergeTests {
    private func ev(_ type: String, _ session: String = "", device: String = "mac-aaaa", seq: Int, lamport: Int, ms: Int, _ p: some Encodable) -> Event {
        Event(id: ULID.make(date: Date(timeIntervalSince1970: Double(ms) / 1000)), device: device, seq: seq, lamport: lamport,
              ts: Date(timeIntervalSince1970: Double(ms) / 1000), type: type, session: session, payload: try! JSONValue.from(p))
    }

    private func sample() -> [Event] {
        let add = ev(EventType.vocabAdded, seq: 1, lamport: 1, ms: 1_000, Payload.VocabAdded(item: .init(lang: .de, text: "Feierabend")))
        let dup = ev(EventType.vocabAdded, device: "web-bbbb", seq: 1, lamport: 1, ms: 2_000, Payload.VocabAdded(item: .init(lang: .de, text: "feierabend!")))
        return [add, dup,
                ev(EventType.vocabUpdated, seq: 2, lamport: 2, ms: 3_000, Payload.VocabUpdated(item: add.id, translation: "старый")),
                ev(EventType.vocabUpdated, device: "web-bbbb", seq: 2, lamport: 3, ms: 2_500, Payload.VocabUpdated(item: dup.id, translation: "новый")),
                ev(EventType.vocabUsed, "s1", seq: 3, lamport: 4, ms: 4_000, Payload.VocabUsed(item: dup.id, message: "u1", by: .learner, outcome: .ok)),
                ev(EventType.vocabUsed, "s1", device: "web-bbbb", seq: 3, lamport: 5, ms: 4_100, Payload.VocabUsed(item: add.id, message: "u1", by: .learner, outcome: .mistake)),
                ev(EventType.vocabUsed, "s2", seq: 4, lamport: 6, ms: 5_000, Payload.VocabUsed(item: add.id, message: "u2", by: .assistant, outcome: .ok)),
                ev(EventType.vocabUsed, "s2", seq: 5, lamport: 7, ms: 5_100, Payload.VocabUsed(item: "unknown", message: "u3", by: .learner, outcome: .ok))]
    }

    @Test func orderAndDuplicatesDoNotChangeTheResult() {
        let events = sample()
        let reference = Merger.build(events)
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<30 {
            let st = Merger.build((events + events.prefix(3)).shuffled(using: &rng))
            #expect(st.vocab == reference.vocab && st.vocabUses == reference.vocabUses && st.vocabUsedInSession == reference.vocabUsedInSession)
        }
    }

    @Test func sameTextFromTwoDevicesIsOneItemAndMistakeWins() throws {
        let st = Merger.build(sample())
        #expect(st.vocab.count == 1)
        let item = try #require(st.vocab.values.first)
        #expect(item.translation == "новый")       // the higher lamport wins, even through the duplicate id
        #expect(item.used == 0 && item.mistakes == 1 && item.offered == 1)  // (item, learner, u1): mistake wins; unknown item ignored
        #expect(st.vocabUsedInSession["s1"] == nil)
    }

    @Test func removalIsFinalEvenAgainstALaterUpdate() {
        let add = ev(EventType.vocabAdded, seq: 1, lamport: 1, ms: 1_000, Payload.VocabAdded(item: .init(lang: .en, text: "spot on")))
        let events = [add,
                      ev(EventType.vocabRemoved, seq: 2, lamport: 2, ms: 2_000, Payload.VocabRemoved(item: add.id)),
                      ev(EventType.vocabUpdated, device: "web-bbbb", seq: 1, lamport: 9, ms: 3_000, Payload.VocabUpdated(item: add.id, note: "later"))]
        for order in [events, events.reversed()] { #expect(Merger.build(Array(order)).vocab.isEmpty) }
    }

    @Test func statisticsBeforeASessionLeaveItsOwnUsesOut() throws {
        let st = Merger.build(sample())
        let id = try #require(st.vocab.keys.first)
        let beforeS2 = try #require(st.vocabulary(lang: .de, before: "s2").first { $0.id == id })
        #expect(beforeS2.offered == 0 && beforeS2.mistakes == 1)  // s2's assistant use is left out
        let beforeS1 = try #require(st.vocabulary(lang: .de, before: "s1").first { $0.id == id })
        #expect(beforeS1.offered == 1 && beforeS1.mistakes == 0)
    }

    @Test func mistakeOutcomeFollowsTheFixSpan() {
        let item = VocabItem(id: "x", lang: .de, text: "seit zwei Jahren", createdAt: Date())
        let other = Fix(original: "Ich wohne in Hamburg seit zwei Jahren und arbeite viel", corrected: "Ich wohne seit zwei Jahren in Hamburg und arbeite viel", rule: "Wortstellung")
        #expect(VocabularyMatcher.outcome(item, fixes: [other]) == .ok)    // the item itself is the same in both
        let wrong = Fix(original: "Ich wohne seit zwei Jahre hier", corrected: "Ich wohne seit zwei Jahren hier", rule: "Dativ")
        #expect(VocabularyMatcher.outcome(VocabItem(id: "y", lang: .de, text: "seit zwei Jahre", createdAt: Date()), fixes: [wrong]) == .mistake)
        #expect(VocabularyMatcher.outcome(item, fixes: []) == .ok)
    }

    @Test func oldJournalsGiveTheSameStateAsBefore() throws {
        for name in ["sample-journal.jsonl", "merge-two-devices.input.jsonl"] {
            let url = contracts.deletingLastPathComponent().appendingPathComponent("events/\(name)")
            let events = try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map { try Event(line: $0) }
            let st = Merger.build(events)
            #expect(st.vocab.isEmpty && st.vocabUses.isEmpty && !st.sessions.isEmpty, "\(name)")
        }
    }

    @Test func editingIsValidated() async throws {
        let store = try JournalStore(base: tempDir("voc-edit"), deviceName: "Mac", deviceID: "mac-edit")
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: LLMSettings(), secrets: InMemorySecretStore()) }
        try await e.addVocabulary(lang: .en, entries: [("spot on", "")], source: .manual)
        let id = try #require(await store.state.vocab.keys.first)
        await #expect(throws: DialogEngine.VocabularyError.emptyText) { try await e.updateVocabulary(id, text: "  !! ") }
        await #expect(throws: DialogEngine.VocabularyError.starredItem) { try await e.updateVocabulary("star:en:x", text: "y") }
        await #expect(throws: DialogEngine.VocabularyError.unknownItem) { try await e.updateVocabulary("nope", text: "y") }
    }
}

@Suite struct VocabularyTurnTests {
    private func engine(_ name: String, reply: @escaping @Sendable () -> MockProvider.Behavior) throws -> (DialogEngine, JournalStore, CallLog) {
        let store = try JournalStore(base: tempDir(name), deviceName: "Mac", deviceID: "mac-vt")
        let log = CallLog()
        let p = MockProvider(id: .groq, behavior: { _, _ in reply() }, calls: log)
        let llm = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "m")], firstTokenTimeout: 2)
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: llm, secrets: InMemorySecretStore(["k": "synthetic"]), health: ProviderHealth(), providers: [.groq: p]) }
        return (e, store, log)
    }
    private func run(_ e: DialogEngine, _ sid: String, _ text: String, lang: Lang = .de, command: CommandKind? = nil) async {
        for await _ in e.send(session: sid, text: text, lang: lang, command: command) {}
    }
    private func uses(_ store: JournalStore) async -> [VocabUse] { await store.state.vocabUses }

    @Test func aTurnCountsTheLearnerAndTheAssistantUse() async throws {
        let (e, store, _) = try engine("vt-1") { .text(["@say de: Schön! Was machst du nach dem Feierabend?"]) }
        try await e.addVocabulary(lang: .de, entries: [("Feierabend", ""), ("eine Ausrede", "")], source: .manual)
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]))
        await run(e, sid, "Ich habe um sechs Feierabend.")
        let u = await uses(store)
        #expect(u.map(\.by).sorted { $0.rawValue < $1.rawValue } == [.assistant, .learner])
        #expect(u.allSatisfy { $0.outcome == .ok })
        #expect(await store.state.vocabUsedInSession[sid]?.count == 1)
    }

    @Test func aFixOnTheItemIsAMistake() async throws {
        let (e, store, _) = try engine("vt-2") { .text(["@say de: Fast! Natürlicher: „Ich wohne seit zwei Jahren hier.“\n@fix: Ich wohne seit zwei Jahre hier → Ich wohne seit zwei Jahren hier | Dativ\n"]) }
        try await e.addVocabulary(lang: .de, entries: [("seit zwei Jahre", "")], source: .manual)
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]))
        await run(e, sid, "Ich wohne seit zwei Jahre hier.")
        let u = await uses(store)
        #expect(u.filter { $0.by == .learner }.map(\.outcome) == [.mistake])
        #expect(u.filter { $0.by == .assistant }.count == 1)  // the corrected phrase in @say counts as offered
    }

    @Test func commandsRussianAndASwitchedOffSessionAreNotCounted() async throws {
        let (e, store, _) = try engine("vt-3") { .text(["@say de: Gut."]) }
        try await e.addVocabulary(lang: .de, entries: [("Feierabend", "")], source: .manual)
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]))
        await run(e, sid, "Wie sagt man Feierabend?", command: .howToSay)
        await run(e, sid, "Feierabend — это конец дня", lang: .ru)
        let off = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline], useVocabulary: false))
        await run(e, off, "Ich habe Feierabend.")
        #expect(await uses(store).filter { $0.by == .learner }.isEmpty)
    }

    @Test func theLearnerUseCountsWhenNoModelAnswers() async throws {
        let (e, store, _) = try engine("vt-4") { .fail(.http(status: 503, message: "down")) }
        try await e.addVocabulary(lang: .de, entries: [("Feierabend", "")], source: .manual)
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]))
        await run(e, sid, "Ich habe Feierabend.")
        #expect(await uses(store).map(\.by) == [.learner])
    }

    @Test func targetsStayStableAndMoveOnAfterUse() async throws {
        let (e, store, _) = try engine("vt-5") { .text(["@say de: Hast du schon Feierabend?"]) }
        try await e.addVocabulary(lang: .de, entries: [("Feierabend", ""), ("eine Ausrede", ""), ("Fernweh", ""), ("die Regel", "")], source: .manual)
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]))
        let first = await e.vocabularyTargets(session: sid).map(\.text)
        #expect(first.count == 3)
        await run(e, sid, "Ich weiß nicht.")                 // the assistant offers Feierabend in this session
        #expect(await e.vocabularyTargets(session: sid).map(\.text) == first)  // stable: this session's uses are left out
        await run(e, sid, "Ja, ich habe Feierabend.")         // the learner uses it
        let after = await e.vocabularyTargets(session: sid).map(\.text)
        #expect(!after.contains("Feierabend") && after.count == 3)
        let focus = try await e.createSession(SessionSettings(lang: .de, mode: .questions, corrections: [.inline], vocabularyFocus: true, pinnedVocab: nil))
        #expect(await e.vocabularyTargets(session: focus).count == 4)  // up to 6 with the focus; 4 items exist
        let st = await store.state
        #expect(st.sessions[focus]?.settings.defaultTitle == String(localized: "My words"))
    }

    @Test func oldSettingsDecodeAndNewFieldsAreOmittedWhenUnset() throws {
        let old = #"{"lang":"de","mode":"free","topic":"","role":"","level":"","customPrompt":"","corrections":["inline"],"starter":"assistant"}"#
        let s = try JSONDecoder().decode(SessionSettings.self, from: Data(old.utf8))
        #expect(s.vocabularyOn && !s.isVocabularyFocus && s.useVocabulary == nil)
        let enc = String(decoding: try JSONEncoder().encode(s), as: UTF8.self)
        #expect(!enc.contains("useVocabulary") && !enc.contains("vocabularyFocus") && !enc.contains("pinnedVocab"))
        #expect(!SessionSettings(lang: .de, mode: .free, vocabularyFocus: true).isVocabularyFocus)  // focus only with Questions
    }

    @Test func recognitionContextKeepsTheTargetsWhenCut() throws {
        let ctx = try #require(RecognitionContext.make(lastAssistant: String(repeating: "lang ", count: 80), topic: "Arbeit",
                                                      phrases: ["Wie geht's?"], targets: ["Feierabend", "eine Ausrede"], maxChars: 120))
        #expect(ctx.hasSuffix("Feierabend eine Ausrede."))
    }
}
