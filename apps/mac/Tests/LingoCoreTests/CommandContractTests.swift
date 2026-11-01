import Foundation
import Testing
@testable import LingoCore

/// Shared command fixtures (LINGO-03 P-07e): the detector vocabulary and the detections of every eval phrase plus edge cases, written
/// by Swift; the TypeScript detector must give the same. Re-record: `LINGO_RECORD_FIXTURES=1 swift test --filter CommandContractTests`.
@Suite struct CommandContractTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/contracts")
    static let extra = ["я повторил урок", "Повтори, что ты сказал!", "ну, как сказать «Feierabend»?", "Как сказал мой друг, всё хорошо",
                        "почему ты так думаешь о фильмах", "объясни мне пожалуйста разницу между словами das und dass", "  ", "...",
                        "Wie sagt man „Schlüssel“?", "What does “spot on” mean?", "nochmall", "slowwer", "das war’s", "I think that's all",
                        // NFD input (decomposed umlaut and ё) and distance ties between kinds, decided by `CommandKind.allCases` order.
                        "Erkla\u{308}r mir den Unterschied", "е\u{308}ще раз", "Ko\u{308}nnen Sie langsamer sprechen", "lets soon", "eier bitte"]

    static func encode(_ value: JSONValue) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        return String(decoding: try enc.encode(value), as: UTF8.self) + "\n"
    }

    static func phrases() throws -> [String] {
        let dir = root.appendingPathComponent("evals/commands")
        var out: [String] = []
        for f in try FileManager.default.contentsOfDirectory(atPath: dir.path).filter({ $0.hasSuffix(".yaml") }).sorted() {
            for line in try String(contentsOf: dir.appendingPathComponent(f), encoding: .utf8).split(separator: "\n") {
                // `- { text: "…", expect: … }`: the text is the first quoted string.
                guard let a = line.range(of: "text: \""), let b = line[a.upperBound...].range(of: "\", expect") else { continue }
                out.append(String(line[a.upperBound..<b.lowerBound]).replacingOccurrences(of: "\\\"", with: "\""))
            }
        }
        return out + extra
    }

    @Test func fixtures() throws {
        let vocabulary = JSONValue.object([
            "exact": .object(Dictionary(uniqueKeysWithValues: CommandDetector.exact.map { ($0.key.rawValue, JSONValue.array($0.value.map(JSONValue.string))) })),
            "prefixes": .array(CommandDetector.prefixes.map { .array([.string($0.0.rawValue), .string($0.1)]) }),
            "fillers": .array(CommandDetector.fillers.sorted().map(JSONValue.string)),
        ])
        let detections = JSONValue.array(try Self.phrases().map { t in
            let m = CommandDetector.detect(t)
            return .object(["text": .string(t), "kind": m.map { .string($0.kind.rawValue) } ?? .null, "argument": m?.argument.map(JSONValue.string) ?? .null])
        })
        let files = ["fixtures/commands/vocabulary.json": try Self.encode(vocabulary), "fixtures/commands/detect.json": try Self.encode(detections)]
        for (path, text) in files {
            let url = Self.root.appendingPathComponent(path)
            if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" { try text.write(to: url, atomically: true, encoding: .utf8) }
            else { #expect(try String(contentsOf: url, encoding: .utf8) == text, "\(path) changed") }
        }
    }
}
