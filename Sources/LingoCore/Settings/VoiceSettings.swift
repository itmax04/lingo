import Foundation

/// Голос и голосовой цикл (R-10, R-11, R-13, R-15, R-44 «Голос»).
public struct VoiceSettings: Codable, Sendable, Hashable {
    /// Голос по языку: идентификатор `AVSpeechSynthesisVoice` (nil — лучший установленный).
    public var voiceIDs: [Lang: String] = [:]
    /// Базовый темп (доля от стандартного).
    public var pace: Double = 1.0
    /// T и G.
    public var turn = TurnConfig()
    /// Запас VAD над шумом во время озвучки помощника — против ложного перебивания своим эхом (R-12), dB.
    public var bargeInMarginDB: Float = 6
    /// Эхоподавление voice processing.
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
