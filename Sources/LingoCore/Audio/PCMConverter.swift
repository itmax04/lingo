// Перенесено из Interview Copilot (`Sources/CopilotCore/Audio/PCMConverter.swift`, коммит cf0e764), без ScreenCaptureKit.
@preconcurrency import AVFoundation

/// Приводит звук к 16 кГц, моно, Float32 — формат для whisper и VAD.
public final class PCMConverter: @unchecked Sendable {
    public static let targetSampleRate: Double = 16_000
    public static let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate,
                                                   channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private var sourceFormat: AVAudioFormat?
    public private(set) var lastError = ""

    public init() {}

    public func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
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

    /// 16 кГц моно → буфер AVAudio (для Apple Speech).
    public static func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let b = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in b.floatChannelData![0].update(from: src.baseAddress!, count: samples.count) }
        return b
    }
}

/// Чтение аудиофайла в 16 кГц моно (evals: синтетические записи `say`).
public enum AudioFileReader {
    public static func read(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return [] }
        try file.read(into: buf)
        return PCMConverter().convert(buf)
    }
}
