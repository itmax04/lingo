import Foundation
import LingoCore

/// Eval `turn` (R-10, R-11): обрыв реплики ≤ 10%, ложная склейка ≤ 5% при T = 1,5 с, G = 2,0 с.
/// Таймлайн — строки «speech 1200» / «silence 800» (мс). `expect` — ожидаемые реплики [начало, конец] в мс после склеек.
/// `vad: true` — таймлайн дополнительно синтезируется в звук (тон на шуме) и проходит через EnergyVAD.
enum TurnEval {
    struct Case: Decodable {
        var id: String
        var timeline: [String]
        var expect: [[Int]]
        var assistant_at: [Int]?
        var silence: Double?
        var merge: Double?
    }
    struct Row: Encodable { var id: String; var mode: String; var expected: Int; var got: [[Int]]; var cuts: Int; var falseMerges: Int; var ok: Bool }
    struct Report: Encodable { var utterances: Int; var cuts: Int; var falseMerges: Int; var cutRate: Double; var mergeRate: Double; var rows: [Row] }

    static func parse(_ s: [String]) -> [TurnTimeline.Piece] {
        s.compactMap { line in
            let p = line.split(separator: " ")
            guard p.count == 2, let ms = Int(p[1]) else { return nil }
            return p[0] == "speech" ? .speech(ms) : .silence(ms)
        }
    }

    /// Обрыв — ожидаемая реплика разбита на несколько; ложная склейка — несколько ожидаемых в одной.
    static func score(expected: [[Int]], got: [TurnSegmenter.Span]) -> (cuts: Int, merges: Int) {
        let g = got.map { (Int(($0.start * 1000).rounded()), Int(($0.end * 1000).rounded())) }
        var cuts = 0, merges = 0
        for e in expected {
            let overlapping = g.filter { $0.0 < e[1] + 50 && $0.1 > e[0] - 50 }
            if overlapping.count > 1 { cuts += 1 }
        }
        for x in g {
            let inside = expected.filter { x.0 < $0[1] + 50 && x.1 > $0[0] - 50 }
            if inside.count > 1 { merges += inside.count - 1 }
        }
        return (cuts, merges)
    }

    static func run(set: String) throws -> Int32 {
        var rows: [Row] = []
        for f in try EvalIO.yamlFiles(set) {
            for c in try EvalIO.load([Case].self, from: f) {
                let cfg = TurnConfig(silence: c.silence ?? 1.5, mergeGap: c.merge ?? 2.0)
                let pieces = parse(c.timeline)
                for mode in ["timeline", "vad"] {
                    let spans = mode == "timeline"
                        ? TurnTimeline.run(pieces, config: cfg, assistantAt: c.assistant_at ?? [])
                        : runThroughVAD(pieces, config: cfg, assistantAt: c.assistant_at ?? [])
                    let (cuts, merges) = score(expected: c.expect, got: spans)
                    let got = spans.map { [Int(($0.start * 1000).rounded()), Int(($0.end * 1000).rounded())] }
                    rows.append(Row(id: c.id, mode: mode, expected: c.expect.count, got: got, cuts: cuts, falseMerges: merges,
                                    ok: cuts == 0 && merges == 0 && got.count == c.expect.count))
                }
            }
        }
        var allOK = true
        for mode in ["timeline", "vad"] {
            let r = rows.filter { $0.mode == mode }
            let n = r.reduce(0) { $0 + $1.expected }
            let cuts = r.reduce(0) { $0 + $1.cuts }, merges = r.reduce(0) { $0 + $1.falseMerges }
            let pass = Double(cuts) / Double(max(1, n)) <= 0.10 && Double(merges) / Double(max(1, n)) <= 0.05
            allOK = allOK && pass
            for x in r where !x.ok { print("MISS [\(mode)] \(x.id): expected \(x.expected), got \(x.got)") }
            print("turn [\(mode)]: реплик \(n), обрывов \(cuts) = \(EvalIO.pct(cuts, n)) (≤ 10%), ложных склеек \(merges) = \(EvalIO.pct(merges, n)) (≤ 5%) → \(pass ? "PASS" : "FAIL")")
        }
        let n = rows.reduce(0) { $0 + $1.expected }
        let path = try EvalIO.writeOut("turn.json", Report(utterances: n, cuts: rows.reduce(0) { $0 + $1.cuts },
                                                           falseMerges: rows.reduce(0) { $0 + $1.falseMerges },
                                                           cutRate: 0, mergeRate: 0, rows: rows))
        print("out: \(path)")
        return allOK ? 0 : 1
    }

    /// Синтез: речь — тон 220 Гц с огибающей слогов (-20 dBFS), тишина — шум -55 dBFS; кадры по 20 мс через EnergyVAD.
    static func runThroughVAD(_ pieces: [TurnTimeline.Piece], config: TurnConfig, assistantAt: [Int]) -> [TurnSegmenter.Span] {
        var vad = EnergyVAD(config: VoiceDefaults.vad)
        var seg = TurnSegmenter(config: config)
        var spans: [TurnSegmenter.Span] = []
        var rng = SystemRandomNumberGenerator()
        var t = 0 // сэмплы
        var pending = assistantAt.sorted()
        func apply(_ ev: [TurnSegmenter.Event]) {
            for e in ev {
                switch e {
                case .utterance(let s): spans.append(s)
                case .merged(_, let s): if !spans.isEmpty { spans.removeLast() }; spans.append(s)
                default: break
                }
            }
        }
        // Тишина в начале — VAD узнаёт уровень шума.
        let lead = 1000
        let all: [TurnTimeline.Piece] = [.silence(lead)] + pieces + [.silence(4000)]
        for p in all {
            let (speech, ms) = { switch p { case .speech(let m): return (true, m); case .silence(let m): return (false, m) } }()
            let n = ms * 16
            var block = [Float](repeating: 0, count: 320)
            var k = 0
            while k < n {
                for i in 0..<320 {
                    let s = t + i
                    let noise = Float.random(in: -1...1, using: &rng) * 0.0025
                    if speech {
                        let syll = 0.55 + 0.45 * sin(Float(s) / 16_000 * 2 * .pi * 4)
                        block[i] = 0.1 * syll * sin(Float(s) / 16_000 * 2 * .pi * 220) + noise
                    } else {
                        block[i] = noise
                    }
                }
                for e in vad.processEvents(block) {
                    let sec = Double(t + e.sampleOffset) / 16_000 - Double(lead) / 1000
                    // VAD отмечает конец речи после hangover; реальный конец — раньше на hangover.
                    apply(e.isSpeech ? seg.speechStarted(at: sec - Double(VoiceDefaults.vad.attackFrames * VoiceDefaults.vad.frameMs) / 1000)
                                     : seg.speechEnded(at: sec - Double(VoiceDefaults.vad.hangoverMs) / 1000))
                }
                t += 320
                k += 320
                let nowMs = t / 16 - lead
                while let a = pending.first, a <= nowMs { seg.assistantStartedSpeaking(); pending.removeFirst() }
                apply(seg.advance(to: Double(nowMs) / 1000))
            }
        }
        return spans
    }
}
