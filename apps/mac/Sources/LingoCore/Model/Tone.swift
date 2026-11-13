import Foundation

/// LINGO-09 MR-01: the tone of a session. Harshness is the tutor's, hostility the character's, both 0…5.
/// A tone is stored only when its level is at least 1; missing means 0/0/off.
public struct Tone: Codable, Sendable, Hashable {
    public var harshness: Int
    public var hostility: Int
    public var profanity: Bool

    public init(harshness: Int, hostility: Int, profanity: Bool = false) {
        self.harshness = harshness
        self.hostility = hostility
        self.profanity = profanity
    }

    /// L = max(harshness, hostility); a tone session has L ≥ 1.
    public var level: Int { max(harshness, hostility) }
    public var isActive: Bool { level >= 1 }

    /// MR-03 presets (constants). Profanity is a separate switch and stays off.
    public static let off = Tone(harshness: 0, hostility: 0)
    public static let strictTeacher = Tone(harshness: 3, hostility: 0)
    public static let conflict = Tone(harshness: 0, hostility: 3)
    public static let combined = Tone(harshness: 3, hostility: 3)

    /// A value out of 0…5 or a field of the wrong type throws, so `SessionSettings` decodes it as no tone (MR-01).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        harshness = try c.decode(Int.self, forKey: .harshness)
        hostility = try c.decode(Int.self, forKey: .hostility)
        profanity = try c.decode(Bool.self, forKey: .profanity)
        guard (0...5).contains(harshness), (0...5).contains(hostility) else {
            throw DecodingError.dataCorruptedError(forKey: .harshness, in: c, debugDescription: "tone level out of range")
        }
    }

    enum CodingKeys: String, CodingKey { case harshness, hostility, profanity }
}
