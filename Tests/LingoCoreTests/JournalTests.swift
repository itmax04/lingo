import Foundation
import Testing
@testable import LingoCore

/// Временная папка теста.
func tempDir(_ name: String = "t") -> URL {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-\(name)-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
}

/// Событие вручную (для проверок слияния).
func ev(_ id: String, device: String, seq: Int, lamport: Int, ms: Int64, type: String, session: String = "s1",
        payload: JSONValue = .object([:])) -> Event {
    Event(id: id, device: device, seq: seq, lamport: lamport, ts: Date(timeIntervalSince1970: Double(ms) / 1000),
          type: type, session: session, payload: payload)
}

func msg(_ text: String, role: Role = .user, lang: Lang = .de) -> JSONValue {
    try! JSONValue.from(Payload.MessageCreated(role: role, text: text, lang: lang))
}

let settingsDE = SessionSettings(lang: .de, mode: .free, topic: "Wohnort", level: "A2", corrections: [.inline])

func created(_ title: String = "Свободный разговор: Wohnort") -> JSONValue {
    try! JSONValue.from(Payload.SessionCreated(title: title, settings: settingsDE))
}

@Suite struct EventCodecTests {
    @Test func ulidFormatAndOrder() {
        let a = ULID.make(date: Date(timeIntervalSince1970: 1_000))
        let b = ULID.make(date: Date(timeIntervalSince1970: 2_000))
        #expect(ULID.isValid(a) && ULID.isValid(b))
        #expect(a < b)
    }

    @Test func roundTripKeepsUnknownFields() throws {
        let line = #"{"v":1,"id":"01J0000000000000000000000A","device":"mac-a","seq":3,"lamport":7,"ts":"2026-10-25T10:00:00.123Z","type":"future.thing","session":"s1","payload":{"x":[1,2,{"y":null}]},"color":"blue"}"#
        let e = try Event(line: Substring(line))
        #expect(e.extra["color"] == .string("blue"))
        #expect(e.payload["x"] != nil)
        let again = try Event(line: Substring(try e.line()))
        #expect(again == e)
        #expect(e.tsMillis == 1_792_922_400_123) // 2026-10-25T10:00:00.123Z
    }
}

@Suite struct JournalIOTests {
    @Test func tornTailAndCorruptedLinesAreSkipped() throws {
        let good = try ev("A", device: "d", seq: 1, lamport: 1, ms: 1, type: EventType.sessionCreated, payload: created()).line()
        let good2 = try ev("B", device: "d", seq: 2, lamport: 2, ms: 2, type: EventType.messageCreated, payload: msg("Hallo")).line()
        let data = Data("\(good)\n{broken json\n\(good2)\n{\"v\":1,\"id\":\"C\"".utf8)
        let r = JournalReader.parse(data)
        #expect(r.events.map(\.id) == ["A", "B"])
        #expect(r.corruptedLines == 1)
        #expect(r.tornTail)
        #expect(!r.newerSchema)
    }

    @Test func newerSchemaIsReadOnly() throws {
        var e = ev("A", device: "d", seq: 1, lamport: 1, ms: 1, type: EventType.messageCreated, payload: msg("x"))
        e.v = Event.schemaVersion + 1
        let r = JournalReader.parse(Data((try e.line() + "\n").utf8))
        #expect(r.newerSchema && r.events.count == 1)
    }

    @Test func appendAfterTornTailStartsNewLine() throws {
        let dir = tempDir("w")
        let w = JournalWriter(dir: dir)
        let e1 = ev("A", device: "d", seq: 1, lamport: 1, ms: 1_761_386_400_000, type: EventType.messageCreated, payload: msg("eins"))
        try w.append([e1])
        let url = dir.appendingPathComponent(JournalWriter.fileName(for: e1.ts))
        // Обрыв записи: половина строки без перевода строки.
        let h = try FileHandle(forWritingTo: url)
        try h.seekToEnd()
        try h.write(contentsOf: Data(#"{"v":1,"id":"TORN","dev"#.utf8))
        try h.close()
        #expect(JournalReader.parse(try Data(contentsOf: url)).tornTail)
        let e2 = ev("B", device: "d", seq: 2, lamport: 2, ms: 1_761_386_400_001, type: EventType.messageCreated, payload: msg("zwei"))
        try w.append([e2])
        let r = try JournalReader.read(url)
        #expect(r.events.map(\.id) == ["A", "B"])
        #expect(r.corruptedLines == 1)
        #expect(!r.tornTail)
    }

    @Test func monthlyFileName() {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = 31; c.hour = 23; c.minute = 30
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        #expect(JournalWriter.fileName(for: cal.date(from: c)!) == "journal-2026-10.jsonl")
    }
}

@Suite struct MergerTests {
    func base() -> [Event] {
        [
            ev("E1", device: "mac-a", seq: 1, lamport: 1, ms: 1000, type: EventType.sessionCreated, payload: created()),
            ev("E2", device: "mac-a", seq: 2, lamport: 2, ms: 2000, type: EventType.messageCreated, payload: msg("Ich wohne in Hamburg")),
            ev("E3", device: "ios-b", seq: 1, lamport: 3, ms: 2000, type: EventType.messageCreated, payload: msg("Wo wohnen Sie?", role: .assistant)),
            ev("E4", device: "mac-a", seq: 3, lamport: 4, ms: 3000, type: EventType.messageCreated, payload: msg("Am Wochenende")),
        ]
    }

    @Test func orderByTsDeviceSeq() {
        let st = Merger.build(base())
        // Равные ts (2000): порядок по device — «ios-b» < «mac-a».
        #expect(st.messages["s1"]!.map(\.id) == ["E3", "E2", "E4"])
        #expect(st.sessions["s1"]!.title == "Свободный разговор: Wohnort")
    }

    @Test func permutationsAndDuplicatesGiveSameState() {
        let events = base()
        let reference = Merger.build(events)
        var rng = SeededRNG(seed: 42)
        for _ in 0..<50 {
            var shuffled = (events + events.prefix(2)).shuffled(using: &rng)
            shuffled += shuffled.prefix(1)
            let st = Merger.build(shuffled)
            #expect(st.messages == reference.messages)
            #expect(st.sessions == reference.sessions)
            #expect(st.eventCount == events.count)
        }
    }

    @Test func lwwByLamportThenDevice() throws {
        var events = base()
        let rename = { (t: String) in try JSONValue.from(Payload.SessionUpdated(title: t)) }
        events.append(ev("R1", device: "mac-a", seq: 4, lamport: 10, ms: 9000, type: EventType.sessionUpdated, payload: try rename("A")))
        events.append(ev("R2", device: "ios-b", seq: 2, lamport: 11, ms: 5000, type: EventType.sessionUpdated, payload: try rename("B")))
        #expect(Merger.build(events).sessions["s1"]!.title == "B") // больший lamport, хотя ts меньше
        events.append(ev("R3", device: "mac-a", seq: 5, lamport: 11, ms: 4000, type: EventType.sessionUpdated, payload: try rename("C")))
        #expect(Merger.build(events).sessions["s1"]!.title == "C") // равный lamport: «mac-a» > «ios-b»
        #expect(Merger.build(events.reversed()).sessions["s1"]!.title == "C")
    }

    @Test func editsInterruptionsTombstoneAndStars() throws {
        var events = base()
        events.append(ev("X1", device: "ios-b", seq: 2, lamport: 5, ms: 4000, type: EventType.messageEdited,
                         payload: try JSONValue.from(Payload.MessageEdited(message: "E2", text: "Ich wohne in Wien"))))
        events.append(ev("X2", device: "mac-a", seq: 4, lamport: 6, ms: 4100, type: EventType.messageInterrupted,
                         payload: try JSONValue.from(Payload.MessageInterrupted(message: "E3", at: 5))))
        let p = Phrase(lang: .de, text: "Freut mich.", translation: "Приятно.", source: .topic)
        events.append(ev("X3", device: "mac-a", seq: 5, lamport: 7, ms: 4200, type: EventType.phraseStarred, session: "",
                         payload: try JSONValue.from(Payload.PhraseMark(phrase: p))))
        events.append(ev("X4", device: "ios-b", seq: 3, lamport: 8, ms: 4300, type: EventType.phraseUnstarred, session: "",
                         payload: try JSONValue.from(Payload.PhraseMark(phrase: p))))
        events.append(ev("X5", device: "ios-b", seq: 4, lamport: 9, ms: 4400, type: "custom.future", payload: .object(["a": .bool(true)])))
        var st = Merger.build(events)
        #expect(st.messages["s1"]!.first { $0.id == "E2" }!.text == "Ich wohne in Wien")
        #expect(st.messages["s1"]!.first { $0.id == "E3" }!.interruptedAt == 5)
        #expect(st.starred.isEmpty)
        #expect(st.unknownEvents == 1)
        events.append(ev("X6", device: "mac-a", seq: 6, lamport: 12, ms: 4500, type: EventType.sessionDeleted))
        st = Merger.build(events)
        #expect(st.sessions["s1"]!.deleted)
        #expect(st.visibleSessions().isEmpty)
        #expect(st.messages["s1"]!.count == 3) // сообщения не теряются, сессия скрыта надгробием
    }

    /// Свойство: объединение коммутативно и идемпотентно на случайных журналах двух устройств.
    @Test func unionIsCommutativeAndIdempotent() {
        var rng = SeededRNG(seed: 7)
        for round in 0..<30 {
            let a = randomJournal(device: "mac-a", count: 30, rng: &rng)
            let b = randomJournal(device: "ios-b", count: 30, rng: &rng)
            let ab = Merger.build(a + b), ba = Merger.build(b + a), aab = Merger.build(a + a + b + b.shuffled(using: &rng))
            #expect(ab.messages == ba.messages, "round \(round)")
            #expect(ab.sessions == ba.sessions, "round \(round)")
            #expect(ab.messages == aab.messages && ab.sessions == aab.sessions, "round \(round)")
            let merged: Int = ab.messages.values.reduce(0) { $0 + $1.count }
            let expected: Int = (a + b).filter { $0.type == EventType.messageCreated }.count
            #expect(merged == expected)
        }
    }

    func randomJournal(device: String, count: Int, rng: inout SeededRNG) -> [Event] {
        var out = [ev("\(device)-c", device: device, seq: 1, lamport: 1, ms: 1000, type: EventType.sessionCreated, payload: created())]
        for i in 2...count {
            let ms = Int64(1000 + Int.random(in: 0..<50, using: &rng) * 100) // частые равные ts
            let lam = Int.random(in: 1..<20, using: &rng)
            if Int.random(in: 0..<5, using: &rng) == 0 {
                out.append(ev("\(device)-\(i)", device: device, seq: i, lamport: lam, ms: ms, type: EventType.sessionUpdated,
                              payload: try! JSONValue.from(Payload.SessionUpdated(title: "T\(i)"))))
            } else {
                out.append(ev("\(device)-\(i)", device: device, seq: i, lamport: lam, ms: ms, type: EventType.messageCreated, payload: msg("m\(i)")))
            }
        }
        return out
    }
}

/// Детерминированный генератор для повторяемых тестов.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
