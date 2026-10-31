import Foundation

/// Voice panel state (R-07, R-42).
public enum VoiceState: String, Sendable, Hashable {
    /// Voice mode is off: the panel shows the microphone button.
    case idle
    /// Recording with the button or space (R-06).
    case recording
    /// Continuous mode: waiting for speech.
    case listening
    /// Recognition and the model request.
    case thinking
    /// Speaking the reply.
    case speaking
    /// "Pause" in continuous mode.
    case paused

    public var title: String {
        switch self {
        case .idle: String(localized: "Press and speak")
        case .recording: String(localized: "Recording")
        case .listening: String(localized: "Listening")
        case .thinking: String(localized: "Thinking…")
        case .speaking: String(localized: "Speaking")
        case .paused: String(localized: "Paused")
        }
    }
}
