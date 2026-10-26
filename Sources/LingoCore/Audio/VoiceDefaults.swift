import Foundation

/// VAD parameters for the voice loop (ADR-0001 §8). Short hangover: the pause length T is measured by `TurnSegmenter`.
public enum VoiceDefaults {
    public static var vad: EnergyVAD.Config {
        var c = EnergyVAD.Config()
        c.hangoverMs = 200
        c.attackFrames = 3
        c.marginDB = 10
        c.minSpeechDB = -50
        return c
    }
}
