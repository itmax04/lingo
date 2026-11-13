import Foundation
import Testing
@testable import LingoCore

/// LINGO-09 M-11a: the `@reply` silent tag (MR-50, MAC-31), the switch and its hiding rules (MR-49, MAC-30), `reply.revealed` (MR-44).
@Suite struct ReplyOptionsTests {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("packages/contracts/fixtures/protocol/reply-options.json")

    static func items(_ chunks: [String], _ lang: Lang) -> [ReplyStreamParser.Item] {
        var p = ReplyStreamParser(studyLang: lang)
        var out: [ReplyStreamParser.Item] = []
        for c in chunks { out += p.feed(c) }
        return out + p.finish()
    }

    @Test func fixture() throws {
        guard case .object(let file) = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: Self.url)),
              case .array(let cases) = file["cases"] else { Issue.record("bad fixture"); return }
        #expect(cases.count >= 10)
        for c in cases {
            guard case .object(let o) = c, let name = o["name"]?.string, let text = o["text"]?.string,
                  let lang = o["studyLang"]?.string.flatMap(Lang.init), case .array(let want) = o["options"] else { Issue.record("bad case"); continue }
            let expected = want.map { v -> ReplyOption in
                guard case .object(let w) = v else { return ReplyOption(lang: .en, text: "?", translation: "?") }
                return ReplyOption(lang: Lang(rawValue: w["lang"]?.string ?? "") ?? .en, text: w["text"]?.string ?? "", translation: w["translation"]?.string ?? "")
            }
            #expect(ReplyOptions.parse(text, studyLang: lang) == expected, "\(name): options")
            // Silent: never a segment, never a violation, never spoken, whatever the chunk boundaries.
            let parsed = ReplyProtocol.parse(text, studyLang: lang)
            let spoken = parsed.segments.compactMap(\.sayText).joined(separator: " ")
            #expect(spoken == o["spokenText"]?.string, "\(name): spoken text")
            #expect(parsed.violations == o["violations"]?.int, "\(name): violations")
            #expect(parsed.segments.filter { if case .hint = $0 { true } else { false } }.count == o["hints"]?.int, "\(name): hints")
            let whole = Self.items([text], lang)
            #expect(Self.items(text.map { String($0) }, lang) == whole, "\(name): chunking")
            for item in whole {
                if case .speak(_, let t) = item { #expect(!t.contains("|"), "\(name): \(t)") }
            }
            // The display fallback drops the lines too (reasoning blocks are cut by the parsers, not by this fallback, for every silent tag).
            if !text.contains("<think>") { #expect(!ReplyProtocol.removingSilentLines(text).contains("@reply"), "\(name): removingSilentLines") }
        }
    }

    @Test func switchHidingRules() {
        let ordinary = SessionSettings(lang: .de, mode: .free, corrections: [.inline])
        #expect(ReplyOptions.isOffered(ordinary))
        #expect(!ReplyOptions.isOffered(ordinary, ended: true))
        var toned = ordinary; toned.tone = .strictTeacher
        #expect(!ReplyOptions.isOffered(toned))
        #expect(ReplyOptions.isOffered(SessionSettings(lang: .de, mode: .free, corrections: [.inline], activity: Activity(kind: .scenario, id: "doctor"))))
        #expect(!ReplyOptions.isOffered(SessionSettings(lang: .de, mode: .free, corrections: [.inline], activity: .warmup(["c1"]))))
        #expect(!ReplyOptions.isOffered(SessionSettings(lang: .de, mode: .free, corrections: [.inline], activity: Activity(kind: .exam, exam: "ielts"))))
        #expect(!ReplyOptions.isOffered(SessionSettings(lang: .de, mode: .free, corrections: [.inline], activity: Activity(kind: .exam, exam: "goethe_b1", format: .training))))
    }

    @Test func promptEqualsTodaysWithTheSwitchOffAndAddsTheRuleWhenOn() {
        let s = SessionSettings(lang: .de, mode: .free, topic: "Wohnort", level: "B1", corrections: [.inline])
        let base = PromptBuilder.system(s)
        #expect(PromptBuilder.system(s, replyOptions: false) == base)
        #expect(!base.contains("@reply"))
        let on = PromptBuilder.system(s, replyOptions: true)
        #expect(on.contains("@reply de:") && on.contains("not an @hint"))
        // MAC-30: ≤ 40 estimated tokens at 3.5 characters per token.
        #expect(Double(on.count - base.count) / 3.5 <= 40, "added \(on.count - base.count) characters")
        // Hidden and without effect where the switch is not offered.
        var toned = s; toned.tone = .conflict
        #expect(PromptBuilder.system(toned, replyOptions: true) == PromptBuilder.system(toned))
        let warm = SessionSettings(lang: .de, mode: .free, corrections: [.inline], activity: .warmup(["c1"]))
        #expect(PromptBuilder.system(warm, replyOptions: true) == PromptBuilder.system(warm))
        let exam = SessionSettings(lang: .en, mode: .free, corrections: [], activity: Activity(kind: .exam, exam: "ielts"))
        #expect(PromptBuilder.system(exam, replyOptions: true) == PromptBuilder.system(exam))
    }

    @Test func requestCarriesTheSwitch() {
        let s = SessionSettings(lang: .en, mode: .free, level: "B1", corrections: [.inline])
        let msgs = [ChatMessage(id: "m1", session: "s", role: .user, text: "Hi", lang: .en, createdAt: Date())]
        #expect(!PromptBuilder.dialogRequest(settings: s, summary: "", messages: msgs).system.contains("@reply"))
        let r = PromptBuilder.dialogRequest(settings: s, summary: "", messages: msgs, replyOptions: true)
        #expect(r.system.contains("@reply en:") && r.purpose == .dialog)
        #expect(LLMPurpose.replyOptions.rawValue == "replyOptions")
    }

    @Test func switchIsDeviceLocalAndTolerant() throws {
        var a = AppSettings()
        #expect(a.replyOptions == false)
        a.replyOptions = true
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(a))
        #expect(back.replyOptions)
        #expect(try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8)).replyOptions == false)
        #expect(try JSONDecoder().decode(AppSettings.self, from: Data("{\"replyOptions\":\"yes\"}".utf8)).replyOptions == false)
    }

    @Test func replyRevealedPayload() throws {
        let p = Payload.ReplyRevealed(message: "m1", index: 2)
        #expect(try JSONValue.from(p).decode(Payload.ReplyRevealed.self) == p)
        #expect(EventType.all.contains(EventType.replyRevealed) && EventType.replyRevealed == "reply.revealed")
        func state(_ payload: JSONValue) -> Int {
            let e = Event(id: "e1", device: "d", seq: 1, lamport: 1, ts: Date(timeIntervalSince1970: 1), type: EventType.replyRevealed, session: "s", payload: payload)
            return Merger.build([e]).unknownEvents
        }
        #expect(state(.object(["message": .string("m1"), "index": .number(0)])) == 0)
        #expect(state(.object(["message": .string("m1"), "index": .number(-1)])) == 1)
        #expect(state(.object(["message": .string("m1")])) == 1)
        #expect(state(.object(["message": .number(1), "index": .number(0)])) == 1)
    }

    /// MR-44, MR-45: the shared journal fixture: two valid events change nothing, three malformed ones count as unknown.
    @Test func journalFixture() throws {
        let url = Self.url.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("events/reply-revealed.jsonl")
        let text = try String(contentsOf: url, encoding: .utf8)
        let events = try text.split(separator: "\n").map { try Event(line: $0) }
        #expect(events.count == 5)
        #expect(try events.map { try $0.line() }.joined(separator: "\n") + "\n" == text)
        let st = Merger.build(events)
        #expect(st.unknownEvents == 3)
        #expect(Merger.build(events.reversed()).unknownEvents == 3)
    }

    /// MAC-30: the snapshot of an ordinary session with reply options on (`LINGO_RECORD_SNAPSHOTS=1` re-records it).
    @Test func snapshotWithTheSwitchOn() throws {
        let s = PromptBuilderTests.settings(.free, [.inline])
        let text = PromptBuilder.system(s, replyOptions: true)
        let url = PromptBuilderTests.dir.appendingPathComponent("prompt-free-inline-replyoptions.txt")
        if ProcessInfo.processInfo.environment["LINGO_RECORD_SNAPSHOTS"] == "1" { try text.write(to: url, atomically: true, encoding: .utf8); return }
        #expect(text == (try String(contentsOf: url, encoding: .utf8)), "snapshot prompt-free-inline-replyoptions.txt changed")
    }
}
