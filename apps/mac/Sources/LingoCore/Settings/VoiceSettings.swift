import Foundation

/// Voice and the voice loop (R-10, R-11, R-13, R-15, R-44 "Voice").
public struct VoiceSettings: Codable, Sendable, Hashable {
    /// Voice per language: an `AVSpeechSynthesisVoice` identifier (nil — the best installed one).
    public var voiceIDs: [Lang: String] = [:]
    /// Base rate (fraction of the standard rate).
    public var pace: Double = 1.0
    /// T and G.
    public var turn = TurnConfig()
    /// VAD margin above noise while the assistant speaks — against false barge-in from its own echo (R-12), dB.
    public var bargeInMarginDB: Float = 6
    /// Voice-processing echo cancellation.
    public var voiceProcessing = true

    public init() {}

    enum CodingKeys: String, CodingKey { case voiceIDs, pace, turn, bargeInMarginDB, voiceProcessing }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        voiceIDs = (try? c.decodeIfPresent([Lang: String].self, forKey: .voiceIDs)) ?? [:]
        pace = (try? c.decodeIfPresent(Double.self, forKey: .pace)) ?? 1.0
        turn = (try? c.decodeIfPresent(TurnConfig.self, forKey: .turn)) ?? TurnConfig()
        bargeInMarginDB = (try? c.decodeIfPresent(Float.self, forKey: .bargeInMarginDB)) ?? 6
        voiceProcessing = (try? c.decodeIfPresent(Bool.self, forKey: .voiceProcessing)) ?? true
    }
}
