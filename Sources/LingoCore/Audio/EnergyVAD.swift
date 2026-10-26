// Ported from Interview Copilot (`Sources/CopilotCore/Audio/EnergyVAD.swift`, commit cf0e764) without logic changes;
// adds a barge-in threshold (R-12): while the assistant speaks, the user's speech must be clearly louder than residual echo.
import Foundation

/// Energy-based voice activity detector (VAD, ADR-0001 §8) with an adaptive threshold.
/// Works in 20 ms frames. The noise floor is the minimum frame energy over a sliding window: speech always has
/// dips between words, while constant background noise (a fan) raises the minimum and is not treated as speech.
public struct EnergyVAD: Sendable {
    public struct Config: Sendable {
        public var sampleRate = 16_000
        public var frameMs = 20
        /// Absolute minimum speech level, dBFS.
        public var minSpeechDB: Float = -50
        /// How much louder than the noise speech must be, dB.
        public var marginDB: Float = 10
        /// Consecutive frames above the threshold needed to switch to "speaking".
        public var attackFrames = 3
        /// Milliseconds of silence needed to switch "speaking" off.
        public var hangoverMs = 300
        /// Noise estimation window, ms.
        public var noiseWindowMs = 3000
        /// Extra margin above noise while the assistant is speaking (R-12), dB.
        public var bargeInExtraDB: Float = 0

        public init() {}
    }

    public let config: Config
    public private(set) var isSpeech = false
    public private(set) var noiseFloorDB: Float = -60
    public private(set) var lastFrameDB: Float = -120
    private var above = 0
    private var belowMs = 0
    private var pending: [Float] = []
    private var history: [Float] = []
    private var historyIndex = 0
    /// Enabled while the assistant is speaking (R-12).
    public var extraMarginDB: Float = 0

    public init(config: Config = Config()) {
        self.config = config
    }

    public var frameSize: Int { config.sampleRate * config.frameMs / 1000 }

    public static func rmsDB(_ frame: ArraySlice<Float>) -> Float {
        guard !frame.isEmpty else { return -120 }
        var sum: Float = 0
        for s in frame { sum += s * s }
        let rms = (sum / Float(frame.count)).squareRoot()
        return rms > 0 ? max(-120, 20 * log10(rms)) : -120
    }

    /// Feed samples; returns state changes in order (true — speech started, false — speech ended).
    @discardableResult
    public mutating func process(_ samples: [Float]) -> [Bool] {
        processEvents(samples).map(\.isSpeech)
    }

    /// Transition position — end of the processed frame relative to the start of this block.
    public struct Event: Sendable, Equatable {
        public let isSpeech: Bool
        public let sampleOffset: Int
    }

    public mutating func processEvents(_ samples: [Float]) -> [Event] {
        let carried = pending.count
        pending.append(contentsOf: samples)
        var changes: [Event] = []
        let n = frameSize
        var offset = 0
        while pending.count - offset >= n {
            let frame = pending[offset..<(offset + n)]
            offset += n
            if let change = processFrame(Self.rmsDB(frame)) {
                changes.append(Event(isSpeech: change, sampleOffset: offset - carried))
            }
        }
        pending.removeFirst(offset)
        return changes
    }

    private mutating func processFrame(_ db: Float) -> Bool? {
        lastFrameDB = db
        let windowFrames = max(1, config.noiseWindowMs / config.frameMs)
        if history.count < windowFrames {
            history.append(db)
        } else {
            history[historyIndex] = db
            historyIndex = (historyIndex + 1) % windowFrames
        }
        noiseFloorDB = max(-90, history.min() ?? db)
        let threshold = max(config.minSpeechDB, noiseFloorDB + config.marginDB) + extraMarginDB
        let loud = db > threshold
        if loud {
            above += 1
            belowMs = 0
            if !isSpeech && above >= config.attackFrames {
                isSpeech = true
                return true
            }
        } else {
            above = 0
            belowMs += config.frameMs
            if isSpeech && belowMs >= config.hangoverMs {
                isSpeech = false
                return false
            }
        }
        return nil
    }

    public mutating func reset() {
        isSpeech = false
        above = 0
        belowMs = 0
        pending.removeAll()
        history.removeAll()
        historyIndex = 0
    }
}
