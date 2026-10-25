import Foundation

/// Состояние голосовой панели (R-07, R-42).
public enum VoiceState: String, Sendable, Hashable {
    /// Голосовой режим выключен: панель показывает кнопку микрофона.
    case idle
    /// Запись по кнопке или пробелу (R-06).
    case recording
    /// Непрерывный режим: ждём речь.
    case listening
    /// Распознавание и запрос к модели.
    case thinking
    /// Озвучка ответа.
    case speaking
    /// «Пауза» в непрерывном режиме.
    case paused

    public var title: String {
        switch self {
        case .idle: "Нажмите и говорите"
        case .recording: "Запись"
        case .listening: "Слушаю"
        case .thinking: "Думаю…"
        case .speaking: "Говорю"
        case .paused: "Пауза"
        }
    }
}
