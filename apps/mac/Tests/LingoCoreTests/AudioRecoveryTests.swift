import AVFoundation
import Testing
@testable import LingoCore

@Suite struct AudioRecoveryTests {
    @Test func continuousWatchdogPollingDoesNotExtendCooldown() {
        var limiter = AudioRestartLimiter()
        var accepted: [Int] = []
        for second in 0..<181 {
            if limiter.allow(at: Double(second)) { accepted.append(second) }
        }
        #expect(Array(accepted.prefix(10)) == [0, 1, 2, 3, 4, 60, 61, 62, 63, 64])
        #expect(accepted.contains(120))
        #expect(accepted.contains(180))
    }

    @Test func rejectedAttemptsDoNotConsumeBudget() {
        var limiter = AudioRestartLimiter(maximumAttempts: 2, window: 10)
        let first = limiter.allow(at: 0)
        let second = limiter.allow(at: 1)
        #expect(first && second)
        for second in 2..<10 {
            let allowed = limiter.allow(at: Double(second))
            #expect(!allowed)
        }
        #expect(limiter.attempts == [0, 1])
        let afterWindow = limiter.allow(at: 10)
        let afterSecond = limiter.allow(at: 11)
        #expect(afterWindow && afterSecond)
    }
}

@Suite struct SpeechBufferJoinerTests {
    private func sine(frames: Int, from start: Int, rate: Double) -> AVAudioPCMBuffer {
        let f = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)!
        let b = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: AVAudioFrameCount(frames))!
        b.frameLength = AVAudioFrameCount(frames)
        for i in 0..<frames { b.floatChannelData![0][i] = Float(0.5 * sin(2 * Double.pi * 440 * Double(start + i) / rate)) }
        return b
    }
    private func resample(_ bufs: [AVAudioPCMBuffer], to rate: Double) -> [Float] {
        let f = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false)!
        var all: [Float] = []
        for b in bufs {
            let conv = AVAudioConverter(from: b.format, to: f)!
            let out = AVAudioPCMBuffer(pcmFormat: f, frameCapacity: AVAudioFrameCount(Double(b.frameLength) * rate / b.format.sampleRate + 64))!
            var used = false
            var err: NSError?
            _ = conv.convert(to: out, error: &err) { _, st in if used { st.pointee = .endOfStream; return nil }; used = true; st.pointee = .haveData; return b }
            all += Array(UnsafeBufferPointer(start: out.floatChannelData![0], count: Int(out.frameLength)))
        }
        return all
    }
    private func worstKink(_ x: [Float]) -> Float {
        var m: Float = 0
        for i in 1..<(x.count - 1) { m = max(m, abs(x[i - 1] - 2 * x[i] + x[i + 1])) }
        return m
    }

    @Test func joinKeepsEverySampleInOrder() throws {
        let chunks = (0..<10).map { sine(frames: 256, from: $0 * 256, rate: 22_050) }
        let joined = try #require(SpeechBufferJoiner.join(chunks))
        #expect(joined.frameLength == 2560)
        let whole = sine(frames: 2560, from: 0, rate: 22_050)
        for i in stride(from: 0, to: 2560, by: 97) { #expect(joined.floatChannelData![0][i] == whole.floatChannelData![0][i]) }
        #expect(SpeechBufferJoiner.join([]) == nil)
    }

    /// The crackle: converting chunk by chunk with a fresh converter leaves a kink at every chunk boundary; one pass does not.
    @Test func joinedConversionHasNoChunkBoundaryClicks() throws {
        let chunks = (0..<60).map { sine(frames: 256, from: $0 * 256, rate: 22_050) }
        let perChunk = resample(chunks, to: 48_000)
        let once = resample([try #require(SpeechBufferJoiner.join(chunks))], to: 48_000)
        #expect(worstKink(once) < 0.05)
        #expect(worstKink(perChunk) > 2 * worstKink(once))
    }
}
