import Foundation
import LingoCore
import Observation

/// Window state. In P-01 it was filled from fixtures (`Fixtures`); since P-06 — from the journal.
@MainActor
@Observable
final class AppModel {
    enum GoetheTab: String { case mock, training, debriefs }
    var section: AppSection = .conversations
    var sessionSearch = ""
    var sessions: [Session] = []
    var selectedSessionID: String? {
        didSet { if selectedSessionID != oldValue { services?.examSelectionChanged(automatic: selectingAutomatically) } }
    }
    /// True only while `apply` picks a session because none (or a deleted one) was selected: not the learner's navigation.
    @ObservationIgnored private var selectingAutomatically = false
    var startingExam = false
    /// The daily reminder's state for Settings (GR-08).
    var reminderStatus: ReminderStatus = .off
    var liveExamSessionID: String?
    var examRun: ExamRun?
    var examBusy = false
    var examInputAllowed = false
    var examFollowUp = false
    /// LINGO-10 BR-23: who the app is speaking as in a Goethe run with a format.
    var examSpeaker: ExamSpeaker?
    /// LINGO-10 BR-33…BR-36: the Goethe screen opens from the Teacher card; its state lives only in memory.
    var showGoethe = false
    var goetheTab: GoetheTab = .training
    /// LINGO-10 BR-08a: the Mock preparation. It exists before any session does (A-01) and only in memory; nil when no Mock is being prepared.
    struct MockPrep: Equatable {
        var draw: GoetheHub.MockDraw
        var startedAt: Date
        /// Done or the timer has ended the preparation and the session is being created.
        var ended = false
        /// The session could not be created: the screen stays in preparation with its notes until Retry succeeds or the learner leaves.
        var failed = false
        static let duration = ExamPhase.goethePrep.seconds
        func remaining(now: Date) -> Int { max(0, Int(ceil(Double(Self.duration) - now.timeIntervalSince(startedAt)))) }
    }
    var mockPrep: MockPrep?
    /// BR-37: from the start of preparation to the end of the run the other tabs and every Start control are disabled.
    var mockActive: Bool { mockPrep != nil || (examRun?.format == .mock && examRun?.finished == false) }
    /// BR-20: no Hints column, no Translate, no In Russian (button and ⌥R), no typing while a Mock is active.
    var mockAidsOff: Bool { mockActive }
    /// F2 (G-5a review): a live Training would be stopped silently by another start or by opening a debrief.
    var trainingLive: Bool { examRun?.format == .training && examRun?.finished == false }
    var goetheLocked: Bool { mockActive || trainingLive || startingExam }
    var goetheTeil = 1
    var goetheCategory: ExamCategory?
    var goetheTask: String?
    /// LINGO-10 BR-22: "My presentation plan" / "My notes". Memory only for one run; never sent to a model, the journal, a file or a log.
    var goetheNotes = ""
    static let notesLimit = 2_000
    var isExam: Bool { selectedSession?.settings.activity?.kind == .exam }
    var canContinue: Bool { !isExam }
    /// Exam sessions whose debrief request is running (memory only; a stored debrief is a `summary` message in the journal).
    var debriefRunning: Set<String> = []
    enum DebriefCard { case running, unavailable, nothingToAssess }
    /// LINGO-10 BR-26, BR-31: what a Goethe session with a format would ask about, from the stored journal. Nil for every other session.
    var goethePlan: GoetheDebrief.Plan? {
        guard let s = selectedSession, s.settings.activity?.format != nil else { return nil }
        return GoetheDebrief.plan(settings: s.settings, parts: history.examParts[s.id] ?? [], messages: messages, messageParts: history.examMessageParts)
    }
    /// LINGO-10 BR-30: the stored debrief of a Goethe session parsed for the card (nil when none is stored or the session is not Goethe).
    var goetheCard: GoetheDebrief.Card? {
        guard let plan = goethePlan, let summary = messages.last(where: { $0.kind == .summary }) else { return nil }
        return GoetheDebrief.card(text: summary.text, plan: plan)
    }
    /// XR-03: the card under a finished exam. Nil while the exam is live, without learner turns, or once the debrief is stored.
    /// BR-31: a Goethe run with nothing finished to assess says so instead of offering a Retry that would send nothing.
    var debriefCard: DebriefCard? {
        guard isExam, let sid = selectedSessionID, selectedSession?.state == .ended, liveExamSessionID != sid,
              !messages.contains(where: { $0.kind == .summary }) else { return nil }
        if selectedSession?.settings.activity?.format != nil {
            if goethePlan?.nothingToAssess != false { return .nothingToAssess }
        } else if !messages.contains(where: { $0.role == .user && $0.kind == .normal }) { return nil }
        return debriefRunning.contains(sid) ? .running : .unavailable
    }
    /// The Teil of a Goethe Training session, for its Hints column (BR-19).
    var trainingTeil: Int? {
        guard let a = selectedSession?.settings.activity, a.kind == .exam, a.format == .training else { return nil }
        return a.teil
    }
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
    /// The weekly advice request is running / the last one gave nothing (memory only; the advice itself is a `report.weekly` event).
    var weeklyRunning = false
    var weeklyFailed = false
    var readOnly = false
    var memoryNote: String?
    var showNewSession = false
    /// The scenario picker (LINGO-05 SR-01); `scenarioTabMine` opens it on the learner's own scenarios.
    var showScenarios = false
    var scenarioTabMine = false
    /// The learner's own scenarios (a mirror of the settings, which the views cannot observe).
    var customScenarios: [CustomScenario] = []
    /// "What Lingo knows about me" (GR-06) is open.
    var showMemory = false
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
            selectingAutomatically = true
            selectedSessionID = visibleSessions.first?.id
            selectingAutomatically = false
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
