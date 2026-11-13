import AppKit
import AVFoundation
import Foundation
import LingoCore

/// App services: journal (R-34), dialogue (R-01…R-25), sync (R-38), settings (R-44). They update `AppModel` on the main thread.
@MainActor
final class AppServices {
    let model: AppModel
    let store: JournalStore
    let engine: DialogEngine
    let settingsStore: SettingsStore
    var settings: AppSettings
    let secrets: SecretStore
    private var observer: UUID?
    var exam: ExamController?
    var examStartID: UUID?
    var examStartTask: Task<Void, Never>?
    var turnTask: Task<Void, Never>?
    /// True while "Finish" is being processed, so a second click does not start a second goodbye.
    var ending = false
    /// Identifies the finish in progress; `releaseFinish` only acts for the current one, so a late task cannot undo a newer finish.
    var finishID: UUID?
    /// The "Finishing the session…" banner of the finish in progress.
    var finishNote: String?
    /// Main-actor watchdog of the finish: unlike the finish task it survives an exception that unwinds that task (H-05).
    var finishWatchdog: Task<Void, Never>?
    var finishTimeout: Duration = .seconds(15)
    /// Test seam: replaces `shutDownVoice` in the finish task (a stand-in that never returns).
    var finishTeardown: (() async -> Void)?
    /// "Continue session" pressed while finishing: resumed right after it.
    var pendingContinue: String?
    /// Speech without the audio engine (replay in a finished session): the microphone stays off.
    let plainSpeech = AVSpeechSynthesizer()
    var whisper: WhisperEngine?
    var voiceReady: Task<Bool, Never>?
    var voiceIO: VoiceIO?
    var turn: TurnController?
    var memoryTimer: Task<Void, Never>?
    var healthTimer: Task<Void, Never>?
    var scheduler: SyncScheduler?
    var backup: BackupScheduler?
    /// What the last reminder sync depended on (goal reached, goal, day), so journal changes re-sync only when it changes.
    var reminderSignature: String?
    /// The last queued reminder sync: syncs run one after another so an older one never overwrites a newer one.
    var reminderSyncTask: Task<Void, Never>?
    var reminderObservers: [NSObjectProtocol] = []
    let reachability = Reachability()

    init(model: AppModel, settingsStore: SettingsStore = SettingsStore(), secrets: SecretStore = KeychainStore(), base: URL? = nil,
         chain: (@Sendable () async -> ProviderChain)? = nil) throws {
        self.model = model
        self.settingsStore = settingsStore
        self.secrets = secrets
        let s = settingsStore.load()
        settings = s
        let dir = base ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lingo", isDirectory: true)
        store = try JournalStore(base: dir, deviceName: Host.current().localizedName ?? "Mac")
        let secretsRef = secrets
        var migrated = s
        if LLMSettings.migrateOrder(&migrated.llm) { settingsStore.save(migrated); settings = migrated }
        if migrated.context.maxTurns == 20 { migrated.context = ContextPolicy(); settingsStore.save(migrated); settings = migrated }
        let settingsRef = SettingsRef(migrated)
        self.settingsRef = settingsRef
        let usage = UsageRecorder(dir: dir.appendingPathComponent("usage", isDirectory: true))
        self.usage = usage
        engine = DialogEngine(store: store, policy: migrated.context, chain: chain ?? {
            // Keys are read off the main thread (D-11). Every attempt writes a usage record (R-52).
            ChainFactory.chain(settings: settingsRef.value.llm, secrets: secretsRef, usage: usage)
        })
        model.langFilter = s.lastLang
        model.customScenarios = s.customScenarios
        model.sourceLabel = s.llm.primaryLabel ?? String(localized: "No key")
        model.hasKey = s.llm.hasUsableKey
        model.recomputeOnline()
        model.memoryNote = s.context.memoryNote()
        model.replyOptionsOn = s.replyOptions
        model.replyCollapsed = s.replyOptionsCollapsed
    }

    let settingsRef: SettingsRef
    let usage: UsageRecorder

    weak var keys: KeysController?

    func updateSettings(_ f: (inout AppSettings) -> Void) {
        f(&settings)
        if keys?.settings != settings.llm { keys?.replace(settings.llm) }
        settingsStore.save(settings)
        settingsRef.value = settings
        model.customScenarios = settings.customScenarios
        model.sourceLabel = settings.llm.primaryLabel ?? String(localized: "No key")
        model.hasKey = settings.llm.hasUsableKey
        model.recomputeOnline()
        turn?.voice = settings.voice
        model.replyOptionsOn = settings.replyOptions
        model.replyCollapsed = settings.replyOptionsCollapsed
        let replyOn = settings.replyOptions
        Task { await engine.setReplyOptions(replyOn) }  // MR-49: applies from the next request
    }

    func start() async {
        let m = model
        observer = await store.observe { [weak self] st in
            Task { @MainActor in m.apply(st); self?.reminderStateChanged(st) }
        }
        model.readOnly = await store.isReadOnly
        await engine.setReplyOptions(settings.replyOptions)
        if Permissions.microphone == .granted { prepareVoice() }
        startSyncAndNetwork()
        if let b = settings.syncBookmark, let f = try? SyncFolder.resolve(bookmark: b) { model.syncFolderPath = f.folder.picked.path }
        startDailyBackup()
        startReminderObservers()
        await syncReminder()
    }

    // MARK: Sessions

    func createSession(_ s: SessionSettings, title: String?) {
        updateSettings { $0.lastCorrections = s.corrections; $0.lastLang = s.lang }
        Task {
            do {
                let id = try await engine.createSession(s, title: title)
                model.langFilter = s.lang
                model.selectedSessionID = id
                // Topic phrases — after the first reply and only with quota to spare (R-52 dispatcher).
                await engine.requestTopicPhrases(id)
                if s.starter == .assistant { run(engine.respond(session: id)) }
            } catch { model.banner = String(localized: "Could not create the session: \(String(describing: error))") }
        }
    }

    func rename(_ id: String, _ title: String) { Task { try? await engine.rename(id, to: title) } }
    func delete(_ id: String) {
        if exam?.sessionID == id { stopExam() }
        Task {
            try? await engine.delete(id)
            await scheduler?.trigger(.manual)
            if model.selectedSessionID == id { model.selectedSessionID = model.visibleSessions.first?.id }
        }
    }

    func select(_ id: String) {
        model.selectedSessionID = id
        model.refreshSelection()
    }

    /// Source badge (R-32).
    func pin(_ entryID: String?) { updateSettings { $0.llm.pinnedEntryID = entryID } }

    /// Correction modes are changed in the session header (R-20); an empty set is not allowed (A-3).
    func toggleCorrection(_ c: CorrectionMode) {
        guard let s = model.selectedSession, !model.isExam else { return }
        var st = s.settings
        if st.corrections.contains(c) { guard st.corrections.count > 1 else { return }; st.corrections.remove(c) } else { st.corrections.insert(c) }
        Task { try? await engine.updateSettings(s.id, st) }
    }

    func revealJournal() {
        NSWorkspace.shared.activateFileViewerSelecting([store.ownDir])
    }

    /// Click on a bubble (R-41): user — edit (R-09), assistant — replay speech (P-07).
    func tapped(_ m: ChatMessage) {
        if model.isExam { if m.role == .assistant && m.kind == .normal { replay(m) }; return }
        if m.role == .user { model.editing = m } else if m.kind == .normal { replay(m) }
    }

    // MARK: Text turn (R-43)

    func sendText() {
        let text = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let sid = model.selectedSessionID, let s = model.selectedSession else { return }
        let examFinish = model.isExam && exam?.sessionID == sid && ExamRun.isFinishCommand(text)
        guard !ending, !model.examReadOnly, !model.isExam || examFinish || exam?.canCapture == true else { return }
        let capture = model.isExam && !examFinish ? exam?.beginCapture() : nil
        model.draft = ""
        let lang = WhisperEngine.scriptLang(text, candidates: [s.settings.lang, .ru]) ?? s.settings.lang
        let cmd = CommandDetector.detect(text)?.kind
        if examFinish {
            // R-22 in an exam (F-2): stop the runner first so no timer, transition or reply runs during the journal write.
            stopExam()
            Task {
                _ = try? await engine.recordUser(session: sid, text: text, lang: lang)
                finishSession(sid)
            }
            return
        }
        if model.isExam {
            if let exam, let capture { Task { await exam.endCapture(capture, text: text, lang: lang) } }
            return
        }
        Task {
            if cmd == .finish, s.state != .ended {
                // "that's all" typed behaves like the button and the voice command (R-22): save the line, say goodbye, end the session.
                _ = try? await engine.recordUser(session: sid, text: text, lang: lang)
                finishSession(sid)
                return
            }
            // A finished session is continued only with "Continue session"; the input is disabled there anyway.
            guard s.state != .ended else { model.draft = text; return }
            run(engine.send(session: sid, text: text, lang: lang, command: cmd))
        }
    }

    /// "Reply again" (R-09): a new reply to the user's utterance.
    func regenerate(userMessageID: String) {
        guard let sid = model.selectedSessionID, !model.isExam else { return }
        guard model.selectedSession?.state != .ended else { model.banner = String(localized: "The session is finished"); return }
        run(engine.respond(session: sid, replyTo: userMessageID))
    }

    /// "Translate to Russian" (the button under a message): one small model request, shown under the message. Not saved in the journal.
    func translate(_ m: ChatMessage) {
        if case .loading = model.translations[m.id] { return }
        let text = m.spokenText
        model.translations[m.id] = .loading
        let lang = m.lang
        Task {
            do {
                let t = try await engine.translate(text, from: lang)
                model.translations[m.id] = .done(t)
            } catch {
                let reason: String
                switch error {
                case DialogEngine.TranslationError.unavailable(let r): reason = r
                case DialogEngine.TranslationError.empty: reason = String(localized: "empty answer")
                default: reason = error.localizedDescription
                }
                model.translations[m.id] = .failed(reason)
            }
        }
    }

    func hideTranslation(_ id: String) { model.translations[id] = nil }

    func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func editMessage(_ id: String, text: String) {
        guard !model.isExam else { return }
        guard let sid = model.selectedSessionID else { return }
        model.translations[id] = nil  // the old translation no longer matches the text
        Task { try? await engine.edit(id, session: sid, text: text) }
    }

    func run(_ stream: AsyncStream<TurnEvent>) {
        turnTask?.cancel()
        model.thinking = true
        model.streaming = ""
        turnTask = Task {
            for await e in stream {
                switch e {
                case .partial(let t): model.streaming = t
                case .restart: model.streaming = ""
                case .attempt(let s): model.streamingSource = s.label
                case .keyInvalid(let id, let reason):
                    updateSettings { $0.llm.markInvalid(keyID: id, reason: reason) }
                case .finished, .failed, .cancelled:
                    model.streaming = nil
                default: break
                }
            }
            model.thinking = false
            model.streaming = nil
        }
    }
}

/// Current settings for closures off the main thread.
final class SettingsRef: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: AppSettings
    init(_ v: AppSettings) { _value = v }
    var value: AppSettings {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
