import Foundation
import Testing
@testable import LingoCore

/// LINGO-09 M-1b: the blame filter (MR-15, MAC-07). `LINGO_RECORD_FIXTURES=1` writes `blame-markers.json`.
@Suite struct BlameFilterTests {
    static let teacher = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("packages/contracts/fixtures/teacher")

    struct Case: Decodable { let name: String; let tone: [Int]?; let lang: Lang; let raw: String; let text: String; let removed: Int }
    struct Golden: Decodable { let cases: [Case] }

    static func tone(_ t: [Int]?) -> Tone? { t.map { Tone(harshness: $0[0], hostility: $0[1]) } }

    /// MAC-07: golden cases per language.
    @Test func goldenCases() throws {
        let g = try JSONDecoder().decode(Golden.self, from: Data(contentsOf: Self.teacher.appendingPathComponent("blame-filter.json")))
        #expect(g.cases.count >= 15)
        for c in g.cases {
            var asked = 0
            let r = BlameFilter.filter(raw: c.raw, tone: Self.tone(c.tone), lang: c.lang, replacement: { asked += 1; return "NEUTRAL" })
            #expect(r.text == c.text, "\(c.name)")
            #expect(r.removed == c.removed, "\(c.name)")
            #expect(asked <= 1, "\(c.name): the replacement is asked at most once")
        }
    }

    /// The marker list is a contract fixture, written from Swift.
    @Test func markerFixture() throws {
        struct F: Codable, Equatable { var rule: String; var markers: [String: [String]] }
        let f = F(rule: "LINGO-09 MR-15: blame markers per study language, written by Swift BlameFilterTests (LINGO_RECORD_FIXTURES=1). Lower case; a trailing * is a stem; several words are one phrase.",
                  markers: Dictionary(uniqueKeysWithValues: BlameFilter.markers.map { ($0.key.rawValue, $0.value) }))
        let url = Self.teacher.appendingPathComponent("blame-markers.json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(f) + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" { try data.write(to: url); return }
        #expect(try JSONDecoder().decode(F.self, from: Data(contentsOf: url)) == f, "blame-markers.json is out of date")
    }

    /// The neutral line that replaces blame never carries a marker itself, at any band.
    @Test func neutralLinesCarryNoMarker() {
        for lang in [Lang.de, .en] { for band in 1...5 {
            for line in ToneLines.lines(.neutral, lang: lang, level: band) {
                #expect(!BlameFilter.hasBlame(line, lang: lang), "\(lang) band \(band): \(line)")
            }
        } }
    }

    /// Streaming: held until the first @fix, then released; without a fix the speech is rebuilt from the filtered text.
    @Test func gateHoldsUntilTheFixOrTheEnd() {
        let tone = Tone(harshness: 3, hostility: 0)
        func run(_ chunks: [String]) -> (spoken: [String], atEnd: [String]) {
            var p = ReplyStreamParser(studyLang: .de)
            var g = BlameGate(tone: tone, lang: .de)
            var spoken: [String] = []
            for c in chunks { for i in p.feed(c) { spoken += g.offer(i).map(\.1) } }
            for i in p.finish() { spoken += g.offer(i).map(\.1) }
            let early = spoken
            let late = g.finish(raw: p.text, replacement: { "NEUTRAL" }).map(\.1)
            return (early, late)
        }
        // Judge first: the fix comes before speech, nothing is held back.
        let withFix = run(["@fix: Ich bin gehen → Ich gehe | Verb\n", "@say de: Falsch. Noch einmal.\n"])
        #expect(withFix.spoken == ["Falsch.", "Noch einmal."] && withFix.atEnd.isEmpty)
        // A fix after the speech releases what was held.
        let lateFix = run(["@say de: Falsch. Noch einmal.\n", "@fix: Ich bin gehen → Ich gehe | Verb"])
        #expect(lateFix.spoken == ["Falsch.", "Noch einmal."] && lateFix.atEnd.isEmpty)
        // No fix: nothing is spoken before the end, then only the sentences without blame.
        let noFix = run(["@say de: Falsch. ", "Wie heißt du?\n"])
        #expect(noFix.spoken.isEmpty && noFix.atEnd == ["Wie heißt du?"])
        // Nothing left: the neutral line.
        let allBlame = run(["@say de: Das ist falsch.\n"])
        #expect(allBlame.spoken.isEmpty && allBlame.atEnd == ["NEUTRAL"])
    }

    /// Without a tone, or with hostility only, the gate never holds anything (ordinary sessions still speak as lines arrive).
    @Test func gateIsOpenWithoutHarshness() {
        for tone in [nil, Tone(harshness: 0, hostility: 4)] {
            var g = BlameGate(tone: tone, lang: .en)
            #expect(!g.isHolding)
            #expect(g.offer(.speak(.en, "Wrong.")).map(\.1) == ["Wrong."])
            #expect(g.finish(raw: "@say en: Wrong.", replacement: { "x" }).isEmpty)
        }
    }

    /// What is spoken at the end equals the stored speech: same text through the same parser.
    @Test func spokenAndStoredAgree() {
        let tone = Tone(harshness: 3, hostility: 3)
        let raw = "@say de: Falsch ist hier nur deine Laune. Was willst du?\n@tutor de: Das war ein Fehler. Weiter."
        var g = BlameGate(tone: tone, lang: .de)
        let spoken = g.finish(raw: raw, replacement: { "NEUTRAL" }).map(\.1)
        let f = BlameFilter.filter(raw: raw, tone: tone, lang: .de, replacement: { "NEUTRAL" })
        let stored = ReplyProtocol.parse(f.text, studyLang: .de).segments.compactMap { seg -> String? in if case .say(_, let t) = seg { return t }; return nil }
        #expect(spoken == ["Falsch ist hier nur deine Laune.", "Was willst du?", "Weiter."])
        #expect(stored == ["Falsch ist hier nur deine Laune. Was willst du?", "Weiter."])
    }

    // MARK: Engine

    func engine(_ reply: [String]) throws -> (DialogEngine, JournalStore) {
        let store = try JournalStore(base: tempDir("blame"), deviceName: "Mac", deviceID: "mac-test")
        let p = MockProvider(id: .groq, behavior: { _, _ in .text(reply) }, calls: CallLog())
        let settings = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "m")], firstTokenTimeout: 2)
        return (DialogEngine(store: store) { ChainFactory.chain(settings: settings, secrets: InMemorySecretStore(["k": "synthetic"]), health: ProviderHealth(), providers: [.groq: p]) }, store)
    }

    /// Runs one turn and returns what was spoken and the stored segments of the reply.
    func turn(_ e: DialogEngine, tone: Tone?) async throws -> (sid: String, spoken: [String], said: [String], mid: String?) {
        var st = SessionSettings(lang: .de, mode: .free, corrections: [.inline])
        st.tone = tone
        let sid = try await e.createSession(st)
        var spoken: [String] = [], said: [String] = [], mid: String?
        for await ev in e.send(session: sid, text: "Ich bin gehen nach Hause", lang: .de) {
            switch ev {
            case .speak(_, let t): spoken.append(t)
            case .finished(let id, _, let segs, _):
                mid = id
                said = segs.compactMap { if case .say(_, let t) = $0 { return t }; return nil }
            default: break
            }
        }
        return (sid, spoken, said, mid)
    }

    @Test func engineReplacesBlameWithoutAFixAndWritesTheCount() async throws {
        let (e, store) = try engine(["@say de: Das ist falsch.\n"])
        let r = try await turn(e, tone: Tone(harshness: 3, hostility: 0))
        let neutral = ToneLines.lines(.neutral, lang: .de, level: 3)
        #expect(neutral.contains(r.spoken.joined(separator: " ")), "a neutral line, spoken sentence by sentence")
        #expect(r.said.joined(separator: " ") == r.spoken.joined(separator: " "), "what is spoken is what is stored")
        let events = await store.allEvents()
        let raw = events.compactMap { try? $0.payload.decode(Payload.MessageCreated.self) }.first { $0.role == .assistant }
        #expect(raw?.text.contains("falsch") == true, "the raw reply is stored as always")
        let filtered = events.filter { $0.type == EventType.toneFiltered }
        #expect(filtered.count == 1)
        let p = try filtered[0].payload.decode(Payload.ToneFiltered.self)
        #expect(p.removed == 1 && p.message == r.mid)
        #expect(!(String(data: try JSONEncoder().encode(filtered[0].payload), encoding: .utf8) ?? "").contains("falsch"), "no text in the event")
    }

    /// MR-15 "shown": no streamed partial carries a blame sentence that the filter later removes.
    @Test func partialsNeverShowRemovedBlame() async throws {
        let (e, _) = try engine(["@say de: Das ist fal", "sch. Noch einmal.\n"])
        var st = SessionSettings(lang: .de, mode: .free, corrections: [.inline])
        st.tone = Tone(harshness: 3, hostility: 0)
        let sid = try await e.createSession(st)
        var partials: [String] = []
        for await ev in e.send(session: sid, text: "Ich bin gehen nach Hause", lang: .de) { if case .partial(let t) = ev { partials.append(t) } }
        #expect(!partials.isEmpty)
        #expect(partials.allSatisfy { !$0.contains("fal") })
    }

    @Test func swearingNeedsTheLevelThatNamesIt() {
        for (h, o, yes) in [(1, 0, false), (4, 4, false), (5, 0, true), (0, 5, true)] {
            let b = TonePrompt.block(Tone(harshness: h, hostility: o, profanity: true))
            #expect(b.contains("Swearing: \(yes ? "yes" : "no")"), "levels \(h)/\(o)")
        }
    }

    @Test func engineKeepsBlameThatAFixBacks() async throws {
        let (e, store) = try engine(["@fix: Ich bin gehen → Ich gehe | Verb\n", "@say de: Falsch. Noch einmal.\n"])
        let r = try await turn(e, tone: Tone(harshness: 3, hostility: 0))
        #expect(r.spoken == ["Falsch.", "Noch einmal."])
        #expect(r.said == ["Falsch. Noch einmal."])
        #expect(await store.allEvents().filter { $0.type == EventType.toneFiltered }.isEmpty)
    }

    @Test func engineLeavesOrdinarySessionsAlone() async throws {
        let (e, store) = try engine(["@say de: Das ist falsch.\n"])
        let r = try await turn(e, tone: nil)
        #expect(r.spoken == ["Das ist falsch."] && r.said == ["Das ist falsch."])
        #expect(await store.allEvents().filter { $0.type == EventType.toneFiltered }.isEmpty)
    }
}

/// MR-45: the shared journal fixture of `tone.filtered`.
@Suite struct ToneFilteredFixtureTests {
    @Test func journalFixture() throws {
        let url = BlameFilterTests.teacher.deletingLastPathComponent().appendingPathComponent("events/tone-filtered.jsonl")
        let text = try String(contentsOf: url, encoding: .utf8)
        let events = try text.split(separator: "\n").map { try Event(line: $0) }
        #expect(events.count == 5)
        #expect(try events.map { try $0.line() }.joined(separator: "\n") + "\n" == text)
        #expect(Merger.build(events).unknownEvents == 3)
        #expect(Merger.build(events.reversed()).unknownEvents == 3)
    }
}
