@preconcurrency import AVFoundation

/// Joins the many small buffers that `AVSpeechSynthesizer.write` produces for one phrase into one buffer of the same format,
/// so that a sample-rate converter sees the phrase as a continuous signal (no click at every chunk boundary).
public enum SpeechBufferJoiner {
    public static func join(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let first = buffers.first else { return nil }
        let format = first.format
        guard !format.isInterleaved || format.channelCount == 1 else { return nil }
        let usable = buffers.filter { $0.format == format && $0.frameLength > 0 }
        guard !usable.isEmpty else { return nil }
        let total = usable.reduce(0) { $0 + Int($1.frameLength) }
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)) else { return nil }
        var position = 0
        for b in usable {
            let n = Int(b.frameLength)
            if let src = b.floatChannelData, let dst = out.floatChannelData {
                for c in 0..<Int(format.channelCount) { dst[c].advanced(by: position).update(from: src[c], count: n) }
            } else if let src = b.int16ChannelData, let dst = out.int16ChannelData {
                for c in 0..<Int(format.channelCount) { dst[c].advanced(by: position).update(from: src[c], count: n) }
            } else { return nil }
            position += n
        }
        out.frameLength = AVAudioFrameCount(total)
        return out
    }
}
