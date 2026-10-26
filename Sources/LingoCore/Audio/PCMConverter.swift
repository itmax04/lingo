// Ported from Interview Copilot (`Sources/CopilotCore/Audio/PCMConverter.swift`, commit cf0e764), without ScreenCaptureKit.
@preconcurrency import AVFoundation

/// Converts audio to 16 kHz mono Float32 — the format for whisper and the VAD.
public final class PCMConverter: @unchecked Sendable {
    public static let targetSampleRate: Double = 16_000
    public static let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate,
                                                   channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?
    public private(set) var lastError = ""

    public init() {}

    public func convert(_ input: AVAudioPCMBuffer) -> [Float] {
        // Multichannel input (voice processing on macOS: 48 kHz, 5 channels — H-2 diagnostics): take channel 0,
        // the processed voice. AVAudioConverter downmixes 5 channels without a layout into silence.
        let buffer = input.format.channelCount > 1 ? (Self.firstChannel(input) ?? input) : input
        let format = buffer.format
        if format.sampleRate == Self.targetSampleRate, format.channelCount == 1,
           format.commonFormat == .pcmFormatFloat32, let data = buffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength)))
        }
        if sourceFormat != format {
            converter = AVAudioConverter(from: format, to: Self.targetFormat)
            sourceFormat = format
        }
        guard let converter else {
            lastError = "no converter from \(format)"
            return []
        }
        let ratio = Self.targetSampleRate / format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let out = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity) else { return [] }
        final class Once: @unchecked Sendable { var consumed = false }
        let once = Once()
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            if once.consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            once.consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, let data = out.floatChannelData else {
            lastError = "AVAudioConverter \(error?.localizedDescription ?? "nil") from \(format)"
            return []
        }
        return Array(UnsafeBufferPointer(start: data[0], count: Int(out.frameLength)))
    }

    static func firstChannel(_ b: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let src = b.floatChannelData,
              let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: b.format.sampleRate, channels: 1, interleaved: false),
              let out = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: b.frameLength), let dst = out.floatChannelData else { return nil }
        out.frameLength = b.frameLength
        dst[0].update(from: src[0], count: Int(b.frameLength))
        return out
    }

    /// 16 kHz mono → AVAudio buffer (for Apple Speech).
    public static func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in b.floatChannelData![0].update(from: src.baseAddress!, count: samples.count) }
        return b
    }
}

/// Reads an audio file as 16 kHz mono (evals: synthetic `say` recordings).
public enum AudioFileReader {
    public static func read(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return [] }
        try file.read(into: buf)
        return PCMConverter().convert(buf)
    }
}
