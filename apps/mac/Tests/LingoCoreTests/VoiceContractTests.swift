import Foundation
import Testing
@testable import LingoCore

/// Shared voice-loop fixture (LINGO-03 P-07f): utterances of every `evals/turn` timeline, segmenter event traces and VAD transitions on
/// deterministic constant-level frames, written by Swift. Re-record: `LINGO_RECORD_FIXTURES=1 swift test --filter VoiceContractTests`.
@Suite struct VoiceContractTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("packages/contracts")

    /// `evals/turn/timelines.yaml` rows: id, timeline, optional assistant_at, silence, merge (a tiny reader for this one flow format).
    static func timelines() throws -> [(id: String, pieces: [TurnTimeline.Piece], assistant: [Int], silence: Double, merge: Double)] {
        let text = try String(contentsOf: root.appendingPathComponent("evals/turn/timelines.yaml"), encoding: .utf8)
        func list(_ line: Substring, _ key: String) -> String? {
            guard let a = line.range(of: key + ": [") else { return nil }
            var depth = 1, i = a.upperBound
            while i < line.endIndex, depth > 0 { if line[i] == "[" { depth += 1 } else if line[i] == "]" { depth -= 1 }; i = line.index(after: i) }
            return String(line[a.upperBound..<line.index(before: i)])
        }
        func number(_ line: Substring, _ key: String) -> Double? {
            guard let a = line.range(of: " " + key + ": ") else { return nil }
            return Double(line[a.upperBound...].prefix { $0.isNumber || $0 == "." })
        }
        return text.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("- {"), let idr = line.range(of: "id: "), let tl = list(line, "timeline") else { return nil }
            let id = String(line[idr.upperBound...].prefix { $0 != "," })
            let pieces: [TurnTimeline.Piece] = tl.split(separator: ",").compactMap { p in
                let w = p.split(separator: " ")
                guard w.count == 2, let ms = Int(w[1]) else { return nil }
                return w[0] == "speech" ? .speech(ms) : .silence(ms)
            }
            let assistant = list(line, "assistant_at").map { $0.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } } ?? []
            return (id, pieces, assistant, number(line, "silence") ?? 1.5, number(line, "merge") ?? 2.0)
        }
    }

    static func ms(_ s: TurnSegmenter.Span) -> JSONValue { .array([.number((s.start * 1000).rounded()), .number((s.end * 1000).rounded())]) }

    static func events(_ ev: [TurnSegmenter.Event]) -> [JSONValue] {
        ev.map { e in
            switch e {
            case .speechBegan(let at, let m): .object(["speechBegan": .number((at * 1000).rounded()), "merges": .bool(m)])
            case .utterance(let s): .object(["utterance": ms(s)])
            case .merged(let p, let s): .object(["merged": ms(s), "previous": ms(p)])
            case .discarded(let s): .object(["discarded": ms(s)])
            }
        }
    }

    /// Scripted segmenter calls: [op, ms] with op speech | silence | advance | assistant | flush.
    static let scripts: [(String, [(String, Int)])] = [
        ("discard short noise", [("speech", 0), ("silence", 150), ("advance", 2000)]),
        ("merge within G", [("speech", 0), ("silence", 1000), ("advance", 2500), ("speech", 3000), ("silence", 3600), ("advance", 5100)]),
        ("no merge beyond G", [("speech", 0), ("silence", 1000), ("advance", 2500), ("speech", 3500), ("silence", 4000), ("advance", 5600)]),
        ("assistant starts while an utterance is open", [("speech", 0), ("silence", 1000), ("assistant", 1500), ("advance", 2500), ("speech", 3000), ("silence", 3600), ("advance", 5100)]),
        ("assistant blocks a merge", [("speech", 0), ("silence", 1000), ("advance", 2500), ("assistant", 2600), ("speech", 3000), ("silence", 3500), ("advance", 5100)]),
        ("flush ends at once", [("speech", 0), ("flush", 800)]),
        ("double start and end are ignored", [("speech", 0), ("speech", 100), ("silence", 900), ("silence", 950), ("advance", 2399), ("advance", 2400)]),
    ]

    /// VAD input: runs of constant-amplitude 20 ms frames [amplitude, frames]; constant frames have an exact level, so Swift and TS agree.
    static let vadRuns: [(String, [(Float, Int)])] = [
        ("speech after quiet noise", [(0.0025, 60), (0.1, 30), (0.0025, 40)]),
        ("short burst under attack", [(0.0025, 60), (0.1, 2), (0.0025, 20)]),
        ("fan noise raises the floor", [(0.02, 200), (0.03, 30), (0.2, 30), (0.02, 50)]),
        ("silence is not speech", [(0, 50), (0.001, 50)]),
        ("hangover keeps a short dip", [(0.0025, 60), (0.1, 20), (0.0025, 5), (0.1, 20), (0.0025, 30)]),
    ]

    /// Seeded runs with varying levels, odd block sizes and a barge-in margin: a 32-bit LCG (the same in the TS test) gives the samples.
    static let randomRuns: [(name: String, seed: UInt32, frames: Int, blocks: [Int], extraDB: Float)] = [
        ("random levels in odd blocks", 7, 300, [37, 320, 1000, 5], 0),
        ("random levels with a barge-in margin", 2026, 300, [160, 700, 333], 6),
    ]

    static func lcg(_ x: inout UInt32) -> Float {
        x = x &* 1_664_525 &+ 1_013_904_223
        return Float(x >> 8) / Float(1 << 24)
    }

    /// Frame levels from the LCG: quiet noise, louder stretches and silence, sample by sample.
    static func randomSamples(seed: UInt32, frames: Int, frameSize: Int) -> [Float] {
        var x = seed
        var out: [Float] = []
        for f in 0..<frames {
            let level: Float = (f / 25) % 3 == 1 ? 0.12 : ((f / 25) % 3 == 2 ? 0.0004 : 0.004)
            for _ in 0..<frameSize { out.append((lcg(&x) * 2 - 1) * level) }
        }
        return out
    }

    @Test func fixture() throws {
        let turns = JSONValue.array(try Self.timelines().map { c in
            let cfg = TurnConfig(silence: c.silence, mergeGap: c.merge)
            return .object(["id": .string(c.id), "spans": .array(TurnTimeline.run(c.pieces, config: cfg, assistantAt: c.assistant).map(Self.ms))])
        })
        let scripts = JSONValue.array(Self.scripts.map { name, ops in
            var seg = TurnSegmenter()
            var out: [JSONValue] = []
            for (op, t) in ops {
                let s = Double(t) / 1000
                switch op {
                case "speech": out += Self.events(seg.speechStarted(at: s))
                case "silence": out += Self.events(seg.speechEnded(at: s))
                case "advance": out += Self.events(seg.advance(to: s))
                case "assistant": seg.assistantStartedSpeaking()
                default: out += Self.events(seg.flush(at: s))
                }
            }
            return .object(["name": .string(name), "ops": .array(ops.map { .array([.string($0.0), .number(Double($0.1))]) }), "events": .array(out)])
        })
        let vad = JSONValue.array(Self.vadRuns.map { name, runs in
            var v = EnergyVAD(config: VoiceDefaults.vad)
            var events: [JSONValue] = []
            var offset = 0
            for (a, frames) in runs {
                for _ in 0..<frames {
                    for e in v.processEvents([Float](repeating: a, count: v.frameSize)) {
                        events.append(.array([.bool(e.isSpeech), .number(Double(offset + e.sampleOffset))]))
                    }
                    offset += v.frameSize
                }
            }
            return .object(["name": .string(name), "runs": .array(runs.map { .array([.number(Double($0.0)), .number(Double($0.1))]) }), "events": .array(events)])
        })
        let randomVAD = JSONValue.array(Self.randomRuns.map { r in
            var v = EnergyVAD(config: VoiceDefaults.vad)
            v.extraMarginDB = r.extraDB
            let samples = Self.randomSamples(seed: r.seed, frames: r.frames, frameSize: v.frameSize)
            var events: [JSONValue] = []
            var i = 0, b = 0
            while i < samples.count {
                let n = min(r.blocks[b % r.blocks.count], samples.count - i)
                for e in v.processEvents(Array(samples[i..<(i + n)])) { events.append(.array([.bool(e.isSpeech), .number(Double(i + e.sampleOffset))])) }
                i += n; b += 1
            }
            return .object(["name": .string(r.name), "seed": .number(Double(r.seed)), "frames": .number(Double(r.frames)),
                            "blocks": .array(r.blocks.map { .number(Double($0)) }), "extraMarginDB": .number(Double(r.extraDB)),
                            "events": .array(events), "noiseFloorDB": .number(Double(v.noiseFloorDB))])
        })
        let file = JSONValue.object(["rule": .string("R-10, R-11 (TurnSegmenter, TurnTimeline) and ADR-0001 §8 (EnergyVAD with VoiceDefaults.vad); written by Swift VoiceContractTests."),
                                     "turns": turns, "scripts": scripts, "vad": vad, "randomVAD": randomVAD])
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
        let text = String(decoding: try enc.encode(file), as: UTF8.self) + "\n"
        let url = Self.root.appendingPathComponent("fixtures/voice/turns.json")
        if ProcessInfo.processInfo.environment["LINGO_RECORD_FIXTURES"] == "1" { try text.write(to: url, atomically: true, encoding: .utf8) }
        else { #expect(try String(contentsOf: url, encoding: .utf8) == text) }
    }
}
