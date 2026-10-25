import Foundation

/// Параметры VAD для голосового цикла (ADR-0001 п. 8). Hangover короткий: длину паузы T меряет `TurnSegmenter`.
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
