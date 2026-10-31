@preconcurrency import AVFoundation
import Foundation
import LingoCore

/// Synthesis time to the first buffer and in total (no audio output) — for R-13 and R-14 (≤ 0.3 s until "repeat" is heard).
enum TTSBench {
    static func run() -> Int32 {
        let synth = AVSpeechSynthesizer()
        let samples: [(Lang, String)] = [(.de, "Sag das bitte noch einmal. Wie gefällt Ihnen Hamburg?"),
                                         (.en, "You can say: Hi, I'm Alex. Nice to meet you."),
                                         (.ru, "Конечно. Повторим по частям.")]
        for l in Lang.allCases {
            let v = Voices.available(l)
            print("\(l.rawValue): voices \(v.count); best: \(v.first.map { "\($0.name) (\($0.language), \($0.qualityTitle))" } ?? "none"); needs a better one: \(Voices.needsBetterVoice(l))")
        }
        for (l, text) in samples {
            for run in 0..<2 {
                let u = AVSpeechUtterance(string: text)
                u.voice = Voices.voice(for: l, preferred: nil)
                let t0 = DispatchTime.now().uptimeNanoseconds
                var first: UInt64 = 0
                var frames: AVAudioFrameCount = 0
                var rate = 0.0
                var markers = 0
                let done = DispatchSemaphore(value: 0)
                synth.write(u, toBufferCallback: { b in
                    guard let p = b as? AVAudioPCMBuffer else { return }
                    if p.frameLength == 0 { done.signal(); return }
                    if first == 0 { first = DispatchTime.now().uptimeNanoseconds }
                    frames += p.frameLength
                    rate = p.format.sampleRate
                }, toMarkerCallback: { m in markers += m.count })
                while done.wait(timeout: .now() + 0.01) == .timedOut { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
                let total = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1e6
                print(String(format: "%@ run%d: first buffer %.0f ms, synthesis %.0f ms, audio %.1f s @%.0f Hz, markers %d", l.rawValue, run,
                             Double(first - t0) / 1e6, total, Double(frames) / max(1, rate), rate, markers))
            }
        }
        print("slow chunks: " + SlowChunks.split("Ich wohne seit zwei Jahren in Hamburg, und am Wochenende gehe ich gern am Meer spazieren.").joined(separator: " | "))
        return 0
    }
}
