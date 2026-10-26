import AVFoundation
import Foundation
import LingoCore

/// `Lingo --audio-diag <file>`: tries audio configurations (echo cancellation on/off, with and without output), 1.5 s of recording each;
/// writes the device, formats, start result and signal level (no audio) to the file. For analysing H-2 errors.
@MainActor
enum AudioDiag {
    /// Real-device capture and restart check. Records counters only, never microphone audio or API calls.
    static func stability(to path: String) -> Int32 {
        final class Counter: @unchecked Sendable {
            let lock = NSLock()
            var samples = 0
            var restarts = 0
            var failures = 0
        }
        let counter = Counter()
        let voice = VoiceIO()
        var lines = ["audio-stability \(Date())", "mic permission: \(Permissions.microphone.rawValue)"]
        voice.onSamples = { samples in counter.lock.withLock { counter.samples += samples.count } }
        voice.onRestart = { _, _ in counter.lock.withLock { counter.restarts += 1 } }
        voice.onCaptureFailure = { _ in counter.lock.withLock { counter.failures += 1 } }
        var passed = true
        do {
            try voice.start(voiceProcessing: true, output: true)
            // Let the I/O unit settle, processing configuration notifications and the same watchdog as the app.
            for _ in 0..<6 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.5))
                voice.checkHealth()
            }
            for second in 1...20 {
                let before = counter.lock.withLock { counter.samples }
                if second == 11 { voice.restart(reason: "stability test") }
                RunLoop.main.run(until: Date().addingTimeInterval(1))
                voice.checkHealth()
                let delta = counter.lock.withLock { counter.samples - before }
                let good = delta > 8_000 && voice.isCapturing
                passed = passed && good
                lines.append("second=\(second) samples=\(delta) capturing=\(voice.isCapturing) vp=\(voice.voiceProcessing) result=\(good ? "PASS" : "FAIL")")
            }
            lines.append("input: \(voice.inputFormatDescription)")
            lines.append(counter.lock.withLock { "restarts=\(counter.restarts) capture_failures=\(counter.failures) samples=\(counter.samples)" })
        } catch {
            passed = false
            lines.append("start: FAIL \(error)")
        }
        voice.stop()
        // An intentional stop must stay stopped despite future watchdog checks or delayed notifications.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        voice.checkHealth()
        passed = passed && !voice.running
        lines.append("stop stays stopped: \(!voice.running)")
        lines.append("audio-stability: \(passed ? "PASS" : "FAIL")")
        let text = lines.joined(separator: "\n") + "\n"
        do { try text.write(toFile: path, atomically: true, encoding: .utf8) }
        catch { print("cannot write diagnostics: \(error)"); return 1 }
        print(text)
        return passed ? 0 : 1
    }

    static func step(_ path: String, _ s: String) {
        let line = "\(Date()) \(s)\n"
        if let h = FileHandle(forWritingAtPath: path + ".log") { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { FileManager.default.createFile(atPath: path + ".log", contents: Data(line.utf8)) }
    }

    static func run(to path: String) -> Int32 {
        step(path, "start")
        var lines: [String] = ["audio-diag \(Date())", "mic permission: \(Permissions.microphone.rawValue), speech: \(Permissions.speech.rawValue)"]
        let probe = AVAudioEngine()
        let inFmt = probe.inputNode.inputFormat(forBus: 0), outFmt = probe.outputNode.outputFormat(forBus: 0)
        lines.append("input hw: \(inFmt.sampleRate) Hz, \(inFmt.channelCount) ch; output hw: \(outFmt.sampleRate) Hz, \(outFmt.channelCount) ch")
        for (vp, out) in [(true, true), (true, false), (false, true), (false, false)] {
            let v = VoiceIO()
            final class Acc: @unchecked Sendable { var n = 0; var peak: Float = 0; let l = NSLock() }
            let acc = Acc()
            v.onSamples = { s in acc.l.withLock { acc.n += s.count; for x in s { acc.peak = max(acc.peak, abs(x)) } } }
            final class Raw: @unchecked Sendable { var p: [Float] = []; let l = NSLock() }
            let raw = Raw()
            v.onRawPeaks = { ps in raw.l.withLock { if raw.p.count < ps.count { raw.p = ps } else { for i in ps.indices { raw.p[i] = max(raw.p[i], ps[i]) } } } }
            step(path, "try vp=\(vp) out=\(out)")
            do {
                try v.start(voiceProcessing: vp, output: out)
                step(path, "started \(v.startLog)")
                var perSec: [String] = []
                for _ in 0..<4 {
                    let before = acc.l.withLock { acc.peak }
                    acc.l.withLock { acc.peak = 0 }
                    RunLoop.main.run(until: Date().addingTimeInterval(1.0))
                    perSec.append(String(format: "%.4f", acc.l.withLock { acc.peak }))
                    acc.l.withLock { acc.peak = max(acc.peak, before) }
                }
                lines.append("  input format: \(v.inputFormatDescription); peaks per second: \(perSec.joined(separator: " ")); raw channel peaks: \(raw.l.withLock { raw.p.map { String(format: "%.4f", $0) } })")
                if out { v.speak("Test.", lang: .en, voiceID: nil, rate: 0.5, tag: 1); RunLoop.main.run(until: Date().addingTimeInterval(1.0)) }
                step(path, "stopping")
                v.stop()
                step(path, "stopped samples=\(acc.n)")
                lines.append("want vp=\(vp) out=\(out): \(v.startLog.joined(separator: " | ")); got vp=\(v.voiceProcessing); samples=\(acc.n) peak=\(String(format: "%.4f", acc.peak))")
            } catch {
                lines.append("want vp=\(vp) out=\(out): FAIL \(v.startLog.joined(separator: " | "))")
            }
        }
        // Restart: after restart() samples flow again (audio configuration change, 2026-10-26).
        do {
            let v = VoiceIO()
            final class N: @unchecked Sendable { var n = 0; let l = NSLock() }
            let cnt = N()
            v.onSamples = { s in cnt.l.withLock { cnt.n += s.count } }
            try v.start(voiceProcessing: true, output: true)
            RunLoop.main.run(until: Date().addingTimeInterval(1.0))
            let before = cnt.l.withLock { cnt.n }
            v.restart(reason: "diag")
            cnt.l.withLock { cnt.n = 0 }
            RunLoop.main.run(until: Date().addingTimeInterval(1.5))
            let after = cnt.l.withLock { cnt.n }
            lines.append("restart: samples before=\(before) after=\(after) vp=\(v.voiceProcessing) since=\(String(format: "%.2f", v.secondsSinceSamples)) s")
            v.stop()
        } catch { lines.append("restart: FAIL \(error)") }
        let text = lines.joined(separator: "\n") + "\n"
        do { try text.write(toFile: path, atomically: true, encoding: .utf8) } catch {
            FileHandle.standardError.write(Data("audio-diag: cannot write \(path): \(error)\n".utf8))
        }
        print(text)
        return 0
    }
}
