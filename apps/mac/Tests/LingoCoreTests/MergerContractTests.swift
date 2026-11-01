import Foundation
import Testing
@testable import LingoCore

/// Golden expected state of `Merger.build` for the shared journals (LINGO-03 P-07c): the TypeScript reducer must give the same.
/// Re-record: `LINGO_RECORD_FIXTURES=1 swift test --filter MergerContractTests`.
@Suite struct MergerContractTests {
    static let events = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("packages/contracts/fixtures/events")

    static func journal(_ name: String) throws -> [Event] {
        try String(contentsOf: events.appendingPathComponent(name), encoding: .utf8)
            .split(separator: "\n").filter { !$0.isEmpty }.map { try Event(line: $0) }
    }

    /// A neutral projection of the state: every field the reducer produces, dates as contract strings.
    static func projection(_ st: HistoryState) throws -> JSONValue {
        func date(_ d: Date) -> JSONValue { .string(Event.formatTS(d)) }
        func opt(_ s: String?) -> JSONValue { s.map(JSONValue.string) ?? .null }
        // `corrections` is a Set: its JSON order changes between runs, so the projection lists it in `CorrectionMode.allCases` order.
        func settings(_ s: SessionSettings) throws -> JSONValue {
            guard case .object(var o) = try JSONValue.from(s) else { return .null }
            o["corrections"] = .array(s.corrections.sorted().map { .string($0.rawValue) })
            return .object(o)
        }
        let sessions = try st.sessions.values.sorted { $0.id < $1.id }.map { s -> JSONValue in
            .object(["id": .string(s.id), "title": .string(s.title), "settings": try settings(s.settings),
                     "createdAt": date(s.createdAt), "lastActivity": date(s.lastActivity), "state": .string(s.state.rawValue),
                     "deleted": .bool(s.deleted), "summary": .string(s.summary), "summaryThrough": opt(s.summaryThrough)])
        }
        let messages = try st.messages.mapValues { list in
            JSONValue.array(try list.map { m in
                .object(["id": .string(m.id), "role": .string(m.role.rawValue), "text": .string(m.text), "lang": .string(m.lang.rawValue),
                         "heard": opt(m.heard), "segments": try JSONValue.from(m.segments), "createdAt": date(m.createdAt),
                         "source": opt(m.source), "interruptedAt": m.interruptedAt.map { .number(Double($0)) } ?? .null,
                         "kind": .string(m.kind.rawValue)])
            })
        }
        let fixes = try st.fixes.mapValues { list in
            JSONValue.array(try list.map { .object(["message": .string($0.message), "fix": try JSONValue.from($0.fix), "ts": date($0.ts)]) })
        }
        let hints = try st.hints.mapValues { JSONValue.array(try $0.map { try JSONValue.from($0) }) }
        let starred = try st.starred.mapValues { try JSONValue.from($0) }
        func item(_ i: VocabItem) -> JSONValue {
            .object(["id": .string(i.id), "lang": .string(i.lang.rawValue), "text": .string(i.text), "translation": .string(i.translation),
                     "note": .string(i.note), "example": .string(i.example), "source": .string(i.source.rawValue), "createdAt": date(i.createdAt),
                     "offered": .number(Double(i.offered)), "used": .number(Double(i.used)), "mistakes": .number(Double(i.mistakes)),
                     "lastPractised": i.lastPractised.map(date) ?? .null])
        }
        let vocab: [String: JSONValue] = [
            "items": .array(st.vocabulary().map(item)),
            "usedInSession": .object(st.vocabUsedInSession.mapValues { .array($0.sorted().map(JSONValue.string)) }),
            "uses": .array(st.vocabUses.map { .object(["item": .string($0.item), "session": .string($0.session), "by": .string($0.by.rawValue),
                                                         "outcome": .string($0.outcome.rawValue), "at": date($0.at)]) }),
            "addKeys": .array(st.vocabAddKeys.sorted().map(JSONValue.string)),
            "targets": .object(Dictionary(uniqueKeysWithValues: st.sessions.keys.map { ($0, JSONValue.array(st.vocabTargets(session: $0).map { .string($0.id) })) })),
        ]
        return .object([
            "vocab": .object(vocab),
            "sessions": .array(sessions), "visibleSessions": .array(st.visibleSessions().map { .string($0.id) }),
            "messages": .object(messages), "fixes": .object(fixes), "hints": .object(hints), "starred": .object(starred),
            "profile": .object(["goals": .string(st.profile.goals), "interests": .string(st.profile.interests)]),
            "profileUpdates": .array(st.profileUpdates.map { u in
                .object(["ts": date(u.ts), "lamport": .number(Double(u.version.lamport)), "device": .string(u.version.device),
                         "goals": opt(u.goals), "interests": opt(u.interests)])
            }),
            "eventCount": .number(Double(st.eventCount)), "maxLamport": .number(Double(st.maxLamport)),
            "lastSeq": .object(st.lastSeq.mapValues { .number(Double($0)) }), "unknownEvents": .number(Double(st.unknownEvents)),
        ])
    }

    @Test(arguments: ["sample-journal", "merge-two-devices.input", "edge", "vocab-edge"])
    func goldenState(name: String) throws {
        let golden = Self.events.appendingPathComponent(name.replacingOccurrences(of: ".input", with: "") + ".state.json")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        let text = String(decoding: try enc.encode(try Self.projection(Merger.build(try Self.journal(name + ".jsonl")))), as: UTF8.self) + "\n"
        if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" {
            try text.write(to: golden, atomically: true, encoding: .utf8)
            return
        }
        #expect(try String(contentsOf: golden, encoding: .utf8) == text, "\(golden.lastPathComponent) changed")
    }
}
