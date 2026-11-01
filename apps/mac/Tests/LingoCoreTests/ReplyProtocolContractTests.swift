import Foundation
import Testing
@testable import LingoCore

/// Shared reply-protocol fixture (LINGO-03 P-07d): parse, streaming items, spoken text and interruption prefixes. The TypeScript
/// parser is checked against the same file. Re-record the expected fields: `LINGO_RECORD_FIXTURES=1 swift test --filter ReplyProtocolContract`.
@Suite struct ReplyProtocolContractTests {
    static let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("packages/contracts/fixtures/protocol/replies.json")

    static func items(_ chunks: [String], _ lang: Lang) -> [ReplyStreamParser.Item] {
        var p = ReplyStreamParser(studyLang: lang)
        var out: [ReplyStreamParser.Item] = []
        for c in chunks { out += p.feed(c) }
        return out + p.finish()
    }

    static func encode(_ items: [ReplyStreamParser.Item]) throws -> JSONValue {
        .array(try items.map { item in
            switch item {
            case .speak(let l, let t): .object(["speak": .array([.string(l.rawValue), .string(t)])])
            case .segment(let s): .object(["segment": try JSONValue.from(s)])
            }
        })
    }

    @Test func fixture() throws {
        guard case .object(var file) = try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: Self.url)),
              case .array(let cases) = file["cases"] else { Issue.record("bad fixture"); return }
        let record = ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1"
        var out: [JSONValue] = []
        for c in cases {
            guard case .object(var o) = c, let text = o["text"]?.string, let lang = o["studyLang"]?.string.flatMap(Lang.init) else {
                Issue.record("malformed case \(c)"); out.append(c); continue
            }
            let parsed = ReplyProtocol.parse(text, studyLang: lang)
            let whole = Self.items([text], lang)
            // Chunk boundaries never change the result: every two-way split and one character at a time.
            let chars = Array(text)
            for i in 0...chars.count {
                #expect(Self.items([String(chars[..<i]), String(chars[i...])], lang) == whole, "\(o["name"]?.string ?? "") split at \(i)")
            }
            #expect(Self.items(chars.map { String($0) }, lang) == whole)
            var stream = ReplyStreamParser(studyLang: lang)
            _ = stream.feed(text); _ = stream.finish()
            #expect(stream.violations == parsed.violations, "\(o["name"]?.string ?? ""): streamed violations")
            // Speech comes only from @say segments: the spoken parts before each say segment join to its text.
            var parts: [String] = []
            for item in whole {
                switch item {
                case .speak(_, let t): parts.append(t)
                case .segment(let s):
                    if case .say(_, let t) = s { #expect(parts.joined(separator: " ") == t, "\(o["name"]?.string ?? ""): spoken \(parts)") }
                    else { #expect(parts.isEmpty, "\(o["name"]?.string ?? ""): speech before a non-say segment") }
                    parts = []
                }
            }
            let message = ChatMessage(id: "m", session: "s", role: .assistant, text: text, lang: lang, segments: parsed.segments, createdAt: Date())
            var expected: [String: JSONValue] = ["segments": try JSONValue.from(parsed.segments), "violations": .number(Double(parsed.violations)),
                                                 "items": try Self.encode(whole), "spokenText": .string(message.spokenText)]
            if let at = o["interruptedAt"]?.int { expected["spokenPrefix"] = .string(String(message.spokenText.prefix(at))) }
            if record {
                for (k, v) in expected { o[k] = v }
            } else {
                for (k, v) in expected { #expect(o[k] == v, "\(o["name"]?.string ?? ""): \(k)") }
            }
            out.append(.object(o))
        }
        if record {
            file["cases"] = .array(out)
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
            try (String(decoding: try enc.encode(JSONValue.object(file)), as: UTF8.self) + "\n").write(to: Self.url, atomically: true, encoding: .utf8)
        }
    }
}
