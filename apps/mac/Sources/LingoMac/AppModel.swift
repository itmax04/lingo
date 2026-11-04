import Foundation
import LingoCore
import Observation

/// Window state. In P-01 it was filled from fixtures (`Fixtures`); since P-06 — from the journal.
@MainActor
@Observable
final class AppModel {
    var section: AppSection = .conversations
    var sessionSearch = ""
    var sessions: [Session] = []
    var selectedSessionID: String? {
        didSet { if selectedSessionID != oldValue { services?.examSelectionChanged() } }
    }
    var startingExam = false
    var liveExamSessionID: String?
    var examRun: ExamRun?
    var examBusy = false
    var examInputAllowed = false
    var examFollowUp = false
    var isExam: Bool { selectedSession?.settings.activity?.kind == .exam }
    var canContinue: Bool { !isExam }
    var examReadOnly: Bool { isExam && (liveExamSessionID != selectedSessionID || examRun?.finished == true) }
    var langFilter: Lang = .en
    var messages: [ChatMessage] = []
    var phrases: [Phrase] = []
    var starred: Set<String> = []
    var voiceState: VoiceState = .idle
    /// Sound levels for the waveform, 0…1 (R-42).
    var levels: [Float] = []
    var sourceLabel = String(localized: "Offline")
    var online = false
    var syncStatus = String(localized: "Not set up")
    var draft = ""
    var hintsVisible = true
    /// The assistant's reply as it is generated (R-13) and the step label.
    var streaming: String? {
        didSet { if oldValue == nil && streaming != nil { streamingCreatedAt = Date() } }
    }
    private var streamingCreatedAt = Date()
    var streamingSource: String?
    var thinking = false
    /// "Translate to Russian" results by message id (memory only: not part of the journal).
    var translations: [String: MessageTranslation] = [:]
    var banner: String?
    /// Languages whose warm-up is being started (a repeated click is ignored).
    var startingWarmup: Set<Lang> = []
    var startingScenario = false
    var readOnly = false
    var memoryNote: String?
    var showNewSession = false
    /// The scenario picker (LINGO-05 SR-01).
    var showScenarios = false
    var continuous = false
    var networkUp = true
    var hasKey = false
    var syncState: SyncStatus = .notConfigured
    var syncFolderPath: String?
    /// Daily backup (MR-04): the chosen folder and the last result shown in Settings → Data.
    var backupFolderPath: String?
    var backupStatus = ""
    var backupRunning = false
    var backupFailed = false
    var russianOnce = false
    var slowPace = false
    /// Transcript edit (R-09).
    var editing: ChatMessage?
    /// Full journal state (to select a session without another request).
    private(set) var history = HistoryState()
    /// Vocabulary ★ (R-28).
    var dictionary: [Phrase] = []
    /// My vocabulary (LINGO-08): own items and ★ phrases of every language, with statistics.
    var vocabulary: [VocabItem] = []
    var profile = LearnerProfile()
    /// The Vocabulary screen: language filter (nil = all), search and the result of the last add.
    var vocabularyFilter: Lang? = .de
    var vocabularySearch = ""
    var vocabularyNote: String?
    /// The "Corrections" section (R-27) — from the session's `@fix` records.
    var corrections: [Phrase] = []
    weak var services: AppServices?

    /// New journal state (R-34, R-37).
    func apply(_ st: HistoryState) {
        history = st
        sessions = Array(st.sessions.values)
        starred = Set(st.starred.keys)
        dictionary = st.starred.values.sorted { $0.text < $1.text }
        vocabulary = st.vocabulary()
        profile = st.profile
        if selectedSessionID == nil || st.sessions[selectedSessionID!]?.deleted == true {
            selectedSessionID = visibleSessions.first?.id
        }
        refreshSelection()
    }

    /// The feed with the assistant's unfinished reply (R-13: text appears as it is generated).
    var displayMessages: [ChatMessage] {
        guard let t = streaming, !t.isEmpty, let sid = selectedSessionID, let s = selectedSession else { return messages }
        let parsed = ReplyProtocol.parse(t, studyLang: s.settings.lang)
        return messages + [ChatMessage(id: "streaming", session: sid, role: .assistant, text: t, lang: s.settings.lang,
                                       segments: parsed.segments, createdAt: streamingCreatedAt, source: streamingSource)]
    }

    func refreshSelection() {
        guard let id = selectedSessionID else { messages = []; phrases = []; return }
        messages = history.messages[id] ?? []
        phrases = history.hints[id] ?? []
        let lang = history.sessions[id]?.settings.lang ?? langFilter
        corrections = (history.fixes[id] ?? []).map { Phrase(lang: lang, text: $0.fix.corrected, translation: $0.fix.rule, source: .correction) }
    }

    var studyLanguage: Lang { selectedSession?.settings.lang ?? langFilter }

    var selectedSession: Session? { sessions.first { $0.id == selectedSessionID } }

    /// Voice and input are available only with a network and a working key (S-17, R-45).
    func recomputeOnline() {
        online = networkUp && hasKey
        if !networkUp { sourceLabel = String(localized: "Offline") }
        else if let l = services?.settings.llm.primaryLabel { sourceLabel = l }
    }

    /// Why voice and input are inactive (R-33, S-01).
    var disabledReason: String {
        if readOnly { return String(localized: "Journal from a newer version — read-only") }
        if !networkUp { return String(localized: "Offline: model replies are unavailable") }
        if !hasKey { return String(localized: "No key: Settings → Keys and models") }
        if selectedSession == nil { return String(localized: "Create a session") }
        if examReadOnly { return String(localized: "Exam transcript — start a new exam from Teacher.") }
        if isExam && !examInputAllowed { return String(localized: "Preparation — microphone off") }
        // A finished session takes no input until the learner explicitly continues it (the "Session finished" card).
        if selectedSession?.state == .ended { return String(localized: "The session is finished") }
        return ""
    }

    /// Presentation status comes from actual availability, never from a dismissible notice.
    func voiceUnavailableReason(now: Date = Date()) -> String? {
        if !networkUp { return String(localized: "Offline: model replies are unavailable") }
        if !hasKey { return String(localized: "No key: Settings → Keys and models") }
        if let settings = services?.settings.llm,
           VoiceAvailability.quotaExhausted(settings: settings, now: now) {
            return String(localized: "Quota exhausted")
        }
        return nil
    }

    /// Sessions of the selected language, by last activity (R-05).
    var visibleSessions: [Session] {
        sessions.filter { !$0.deleted && $0.settings.lang == langFilter }
            .sorted { $0.lastActivity > $1.lastActivity }
    }
}

/// Reads existing provider health without changing routing, budgets or retry behavior.
enum VoiceAvailability {
    static func quotaExhausted(settings: LLMSettings, health: ProviderHealth = .shared, now: Date = Date()) -> Bool {
        let steps = settings.chain.filter { $0.enabled && (settings.pinnedEntryID == nil || $0.id == settings.pinnedEntryID) }
            .flatMap { entry in
                settings.keys(for: entry.provider).filter { !$0.invalid }.map {
                    settings.stepInfo(provider: entry.provider, model: entry.model, key: $0)
                }
            }
        return !steps.isEmpty && steps.allSatisfy { health.pause(for: $0, now: now)?.error.status == 429 }
    }
}
