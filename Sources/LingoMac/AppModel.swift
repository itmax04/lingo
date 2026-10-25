import Foundation
import LingoCore
import Observation

/// Состояние окна. В P-01 заполняется фикстурами (`Fixtures`); с P-06 — из журнала.
@MainActor
@Observable
final class AppModel {
    var sessions: [Session] = []
    var selectedSessionID: String?
    var langFilter: Lang = .en
    var messages: [ChatMessage] = []
    var phrases: [Phrase] = []
    var starred: Set<String> = []
    var voiceState: VoiceState = .idle
    /// Уровни звука для волны, 0…1 (R-42).
    var levels: [Float] = []
    var sourceLabel = "Нет сети"
    var online = false
    var syncStatus = "Не настроена"
    var draft = ""
    var hintsVisible = true

    var selectedSession: Session? { sessions.first { $0.id == selectedSessionID } }

    /// Сессии выбранного языка, по последней активности (R-05).
    var visibleSessions: [Session] {
        sessions.filter { !$0.deleted && $0.settings.lang == langFilter }
            .sorted { $0.lastActivity > $1.lastActivity }
    }
}
