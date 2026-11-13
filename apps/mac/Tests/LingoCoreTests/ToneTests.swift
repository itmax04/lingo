import Foundation
import Testing
@testable import LingoCore

/// LINGO-09 M-1a: the tone field (MR-01, MR-03), the `local` mark (MR-44) and the shared fixture `tone-settings.json` (MAC-01, MAC-02).
@Suite struct ToneTests {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("packages/contracts/fixtures/events/tone-settings.json")

    @Test func fixtureDecodesTolerantly() throws {
        guard case .object(let file) = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: Self.url)),
              case .object(let base) = file["base"], case .array(let cases) = file["cases"] else { Issue.record("bad fixture"); return }
        #expect(cases.count >= 10)
        for c in cases {
            guard case .object(let o) = c, let name = o["name"]?.string, case .object(let extra) = o["extra"] else { Issue.record("bad case"); continue }
            let settings = try JSONValue.object(base.merging(extra) { _, new in new }).decode(SessionSettings.self)
            var expected: Tone?
            if case .object(let t) = o["tone"] {
                expected = Tone(harshness: t["harshness"]?.int ?? -1, hostility: t["hostility"]?.int ?? -1, profanity: t["profanity"]?.bool ?? false)
            }
            #expect(settings.tone == expected, "\(name)")
        }
    }

    @Test func noToneEncodesAsBefore() throws {
        let s = SessionSettings(lang: .de, mode: .free, corrections: [.inline])
        guard case .object(let o) = try JSONValue.from(s) else { Issue.record("object"); return }
        #expect(o["tone"] == nil)
        // A level-0 tone is dropped on init and on assignment, so it is never written (MR-01).
        var z = SessionSettings(lang: .de, mode: .free, corrections: [.inline], tone: Tone(harshness: 0, hostility: 0, profanity: true))
        #expect(z.tone == nil)
        z.tone = .strictTeacher; #expect(z.tone == .strictTeacher)
        z.tone = .off; #expect(z.tone == nil)
        guard case .object(let t) = try JSONValue.from(SessionSettings(lang: .de, mode: .free, corrections: [.inline], tone: .combined)) else { return }
        #expect(t["tone"] != nil)
    }

    @Test func presets() {
        #expect([Tone.off, .strictTeacher, .conflict, .combined].map { [$0.harshness, $0.hostility] } == [[0, 0], [3, 0], [0, 3], [3, 3]])
        #expect([Tone.off, .strictTeacher, .conflict, .combined].allSatisfy { !$0.profanity })
        #expect(Tone.off.level == 0 && !Tone.off.isActive && Tone.conflict.level == 3 && Tone.combined.isActive)
    }

    @Test func localMarkIsOptionalInThePayload() throws {
        let plain = Payload.MessageCreated(role: .assistant, text: "x", lang: .de)
        guard case .object(let o) = try JSONValue.from(plain) else { Issue.record("object"); return }
        #expect(o["local"] == nil)
        let local = Payload.MessageCreated(role: .assistant, text: "x", lang: .de, local: true)
        #expect(try JSONValue.from(local).decode(Payload.MessageCreated.self).local == true)
        #expect(try JSONValue.from(plain).decode(Payload.MessageCreated.self).local == nil)
        #expect(ChatMessage(id: "m", session: "s", role: .assistant, text: "x", lang: .de, createdAt: Date()).local == false)
    }
}
