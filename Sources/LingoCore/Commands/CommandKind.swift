import Foundation

/// Commands R-14…R-22.
public enum CommandKind: String, Codable, Sendable, CaseIterable, Hashable {
    case repeatLast = "repeat"
    case slower
    case howToSay = "how_to_say"
    case explain
    case continuePractice = "continue"
    case mistakes
    case finish

    /// Executed locally, without the model (R-14, R-15, R-22).
    public var isLocal: Bool { self == .repeatLast || self == .slower }
}
