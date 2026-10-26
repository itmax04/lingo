import Foundation

/// A journal event (R-35). Unknown types and fields are preserved (`extra`, `payload`) and ignored when building state.
public struct Event: Sendable, Hashable, Identifiable {
    /// Current schema version. A journal with a newer version is opened read-only (R-39).
    public static let schemaVersion = 1

    public var v: Int
    public var id: String
    public var device: String
    public var seq: Int
    public var lamport: Int
    public var ts: Date
    public var type: String
    public var session: String
    public var payload: JSONValue
    /// Top-level fields that this schema version does not know.
    public var extra: [String: JSONValue]

    public init(v: Int = Event.schemaVersion, id: String, device: String, seq: Int, lamport: Int, ts: Date,
                type: String, session: String, payload: JSONValue = .object([:]), extra: [String: JSONValue] = [:]) {
        self.v = v
        self.id = id
        self.device = device
        self.seq = seq
        self.lamport = lamport
        self.ts = ts
        self.type = type
        self.session = session
        self.payload = payload
        self.extra = extra
    }
}

/// Event types (R-35).
public enum EventType {
    public static let sessionCreated = "session.created"
    public static let sessionUpdated = "session.updated"
    public static let sessionDeleted = "session.deleted"
    public static let sessionEnded = "session.ended"
    public static let sessionResumed = "session.resumed"
    public static let messageCreated = "message.created"
    public static let messageEdited = "message.edited"
    public static let messageInterrupted = "message.interrupted"
    public static let summaryUpdated = "summary.updated"
    public static let fixRecorded = "fix.recorded"
    public static let hintAdded = "hint.added"
    public static let phraseStarred = "phrase.starred"
    public static let phraseUnstarred = "phrase.unstarred"

    public static let all: Set<String> = [sessionCreated, sessionUpdated, sessionDeleted, sessionEnded, sessionResumed,
                                         messageCreated, messageEdited, messageInterrupted, summaryUpdated, fixRecorded,
                                         hintAdded, phraseStarred, phraseUnstarred]
}

// MARK: - JSON Lines row

extension Event {
    private static let known: Set<String> = ["v", "id", "device", "seq", "lamport", "ts", "type", "session", "payload"]

    /// Time — ISO 8601 UTC with milliseconds: "2026-10-25T13:01:02.123Z".
    public static func formatTS(_ d: Date) -> String {
        d.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt))
    }

    public static func parseTS(_ s: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .gmt).parse(s))
            ?? (try? Date.ISO8601FormatStyle(timeZone: .gmt).parse(s))
    }

    /// Milliseconds are the ordering unit (R-37); time is rounded on write so ordering does not depend on Double precision.
    public var tsMillis: Int64 { Int64((ts.timeIntervalSince1970 * 1000).rounded()) }

    public func jsonObject() -> [String: JSONValue] {
        var o = extra
        o["v"] = .number(Double(v))
        o["id"] = .string(id)
        o["device"] = .string(device)
        o["seq"] = .number(Double(seq))
        o["lamport"] = .number(Double(lamport))
        o["ts"] = .string(Event.formatTS(ts))
        o["type"] = .string(type)
        o["session"] = .string(session)
        o["payload"] = payload
        return o
    }

    /// One line without a newline, keys sorted (stable output).
    public func line() throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: try enc.encode(JSONValue.object(jsonObject())), as: UTF8.self)
    }

    public enum ParseError: Error, Equatable { case notObject, missingField(String) }

    public init(line: Substring) throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(line.utf8))
        guard case .object(let o) = value else { throw ParseError.notObject }
        func req<T>(_ k: String, _ f: (JSONValue) -> T?) throws -> T {
            guard let raw = o[k], let x = f(raw) else { throw ParseError.missingField(k) }
            return x
        }
        v = try req("v") { $0.int }
        id = try req("id") { $0.string }
        device = try req("device") { $0.string }
        seq = try req("seq") { $0.int }
        lamport = try req("lamport") { $0.int }
        ts = try req("ts") { $0.string.flatMap(Event.parseTS) }
        type = try req("type") { $0.string }
        session = o["session"]?.string ?? ""
        payload = o["payload"] ?? .object([:])
        extra = o.filter { !Event.known.contains($0.key) }
    }
}
