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
    @Test func pastedListSplitsLinesAndTranslations() {
        let list = VocabularyText.parseList("""
        Feierabend — конец рабочего дня
        sich verabreden - договориться о встрече

        Fernweh: тоска по дальним странам
        eine Ausrede\tотговорка
        nur Text
        """)
        #expect(list.map(\.text) == ["Feierabend", "sich verabreden", "Fernweh", "eine Ausrede", "nur Text"])
        #expect(list.map(\.translation) == ["конец рабочего дня", "договориться о встрече", "тоска по дальним странам", "отговорка", ""])
    }

    @Test func normalisationKeepsUmlautsAndDropsPunctuation() {
        #expect(VocabularyText.normalize("  Let's   GO!  ") == "lets go")
        #expect(VocabularyText.normalize("Größe, bitte.") == "größe bitte")
        #expect(VocabularyText.key(lang: .de, text: "Feierabend!") == VocabularyText.key(lang: .de, text: "feierabend"))
    }
}

@Suite struct VocabularyContractTests {
    struct SelectionFile: Decodable {
        struct Item: Decodable { let id: String; let lang: Lang; let text: String; let createdAt: String; let offered: Int; let used: Int; let mistakes: Int; let lastPractised: String? }
        struct Case: Decodable { let name: String; let lang: Lang; let count: Int; let usedInSession: [String]; let items: [Item]; let expected: [String] }
        let cases: [Case]
    }
    struct MatchingFile: Decodable {
        struct Case: Decodable { let item: String; let utterance: String; let expected: Bool }
        let cases: [Case]
    }

    @Test func selectionMatchesTheGoldenFixture() throws {
        let f = try JSONDecoder().decode(SelectionFile.self, from: Data(contentsOf: contracts.appendingPathComponent("selection.json")))
        #expect(f.cases.count >= 3)
        for c in f.cases {
            let items = c.items.map { VocabItem(id: $0.id, lang: $0.lang, text: $0.text, createdAt: isoDate($0.createdAt), offered: $0.offered,
                                                used: $0.used, mistakes: $0.mistakes, lastPractised: $0.lastPractised.map(isoDate)) }
            let got = VocabularySelection.select(items, lang: c.lang, usedInSession: Set(c.usedInSession), count: c.count).map(\.id)
            #expect(got == c.expected, "\(c.name)")
        }
    }

    @Test func matchingMatchesTheGoldenFixture() throws {
        let f = try JSONDecoder().decode(MatchingFile.self, from: Data(contentsOf: contracts.appendingPathComponent("matching.json")))
        #expect(f.cases.count >= 10)
        for c in f.cases { #expect(VocabularyMatcher.contains(c.item, in: c.utterance) == c.expected, "\(c.item) in \(c.utterance)") }
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
        let r1 = try await e.addVocabulary(lang: .de, entries: VocabularyText.parseList("Feierabend — конец дня\n\nFernweh"), source: .list)
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
        for (by, outcome) in [(VocabActor.assistant, VocabOutcome.ok), (.learner, .mistake), (.learner, .ok)] {
            try await store.append(EventType.vocabUsed, session: "s1", Payload.VocabUsed(item: id, by: by, outcome: outcome))
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
            try await store.append(EventType.vocabUsed, session: "s1", Payload.VocabUsed(item: id, by: .learner, outcome: .ok))
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
