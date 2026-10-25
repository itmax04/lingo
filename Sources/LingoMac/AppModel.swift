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
    /// Ответ помощника по мере генерации (R-13) и метка шага.
    var streaming: String?
    var streamingSource: String?
    var thinking = false
    var banner: String?
    var readOnly = false
    var memoryNote: String?
    var showNewSession = false
    var continuous = false
    var networkUp = true
    var hasKey = false
    var syncState: SyncStatus = .notConfigured
    var syncFolderPath: String?
    var russianOnce = false
    var slowPace = false
    /// Правка расшифровки (R-09).
    var editing: ChatMessage?
    /// Полное состояние журнала (для выбора сессии без повторного запроса).
    private(set) var history = HistoryState()
    /// Словарь ★ (R-28).
    var dictionary: [Phrase] = []
    /// Раздел «Исправления» (R-27) — из `@fix` сессии.
    var corrections: [Phrase] = []
    weak var services: AppServices?

    /// Новое состояние журнала (R-34, R-37).
    func apply(_ st: HistoryState) {
        history = st
        sessions = Array(st.sessions.values)
        starred = Set(st.starred.keys)
        dictionary = st.starred.values.sorted { $0.text < $1.text }
        if selectedSessionID == nil || st.sessions[selectedSessionID!]?.deleted == true {
            selectedSessionID = visibleSessions.first?.id
        }
        refreshSelection()
    }

    /// Лента с незаконченным ответом помощника (R-13: текст появляется по мере генерации).
    var displayMessages: [ChatMessage] {
        guard let t = streaming, !t.isEmpty, let sid = selectedSessionID, let s = selectedSession else { return messages }
        let parsed = ReplyProtocol.parse(t, studyLang: s.settings.lang)
        return messages + [ChatMessage(id: "streaming", session: sid, role: .assistant, text: t, lang: s.settings.lang,
                                       segments: parsed.segments, createdAt: Date(), source: streamingSource)]
    }

    func refreshSelection() {
        guard let id = selectedSessionID else { messages = []; phrases = []; return }
        messages = history.messages[id] ?? []
        phrases = history.hints[id] ?? []
        let lang = history.sessions[id]?.settings.lang ?? langFilter
        corrections = (history.fixes[id] ?? []).map { Phrase(lang: lang, text: $0.fix.corrected, translation: $0.fix.rule, source: .correction) }
    }

    var selectedSession: Session? { sessions.first { $0.id == selectedSessionID } }

    /// Голос и ввод доступны, только если есть сеть и действующий ключ (S-17, R-45).
    func recomputeOnline() {
        online = networkUp && hasKey
        if !networkUp { sourceLabel = "Нет сети" }
        else if let l = services?.settings.llm.primaryLabel { sourceLabel = l }
    }

    /// Причина, почему голос и ввод неактивны (R-33, S-01).
    var disabledReason: String {
        if readOnly { return "Журнал новой версии — только чтение" }
        if !networkUp { return "Нет сети: ответы модели недоступны" }
        if !hasKey { return "Нет ключа: Настройки → Ключи и модели" }
        if selectedSession == nil { return "Создайте сессию" }
        return ""
    }

    /// Сессии выбранного языка, по последней активности (R-05).
    var visibleSessions: [Session] {
        sessions.filter { !$0.deleted && $0.settings.lang == langFilter }
            .sorted { $0.lastActivity > $1.lastActivity }
    }
}
