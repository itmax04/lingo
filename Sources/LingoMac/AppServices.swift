import AppKit
import Foundation
import LingoCore

/// Службы приложения: журнал (R-34), диалог (R-01…R-25), синхронизация (R-38), настройки (R-44). Обновляют `AppModel` на главном потоке.
@MainActor
final class AppServices {
    let model: AppModel
    let store: JournalStore
    let engine: DialogEngine
    let settingsStore: SettingsStore
    var settings: AppSettings
    let secrets: SecretStore
    private var observer: UUID?
    private var turnTask: Task<Void, Never>?
    var whisper: WhisperEngine?
    var voiceReady: Task<Bool, Never>?
    var voiceIO: VoiceIO?
    var turn: TurnController?
    var memoryTimer: Task<Void, Never>?

    init(model: AppModel, settingsStore: SettingsStore = SettingsStore(), secrets: SecretStore = KeychainStore(), base: URL? = nil) throws {
        self.model = model
        self.settingsStore = settingsStore
        self.secrets = secrets
        let s = settingsStore.load()
        settings = s
        let dir = base ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lingo", isDirectory: true)
        store = try JournalStore(base: dir, deviceName: Host.current().localizedName ?? "Mac")
        let secretsRef = secrets
        let settingsRef = SettingsRef(s)
        self.settingsRef = settingsRef
        engine = DialogEngine(store: store, policy: s.context) {
            // Ключи читаются не на главном потоке (D-11).
            ChainFactory.chain(settings: settingsRef.value.llm, secrets: secretsRef)
        }
        model.langFilter = s.lastLang
        model.sourceLabel = s.llm.primaryLabel ?? "Нет ключа"
        model.online = s.llm.hasUsableKey
        model.memoryNote = s.context.memoryNote()
    }

    let settingsRef: SettingsRef

    func updateSettings(_ f: (inout AppSettings) -> Void) {
        f(&settings)
        settingsStore.save(settings)
        settingsRef.value = settings
        model.sourceLabel = settings.llm.primaryLabel ?? "Нет ключа"
        model.online = settings.llm.hasUsableKey
    }

    func start() async {
        let m = model
        observer = await store.observe { st in
            Task { @MainActor in m.apply(st) }
        }
        model.readOnly = await store.isReadOnly
        if Permissions.microphone == .granted { prepareVoice() }
    }

    // MARK: Сессии

    func createSession(_ s: SessionSettings, title: String?) {
        updateSettings { $0.lastCorrections = s.corrections; $0.lastLang = s.lang }
        Task {
            do {
                let id = try await engine.createSession(s, title: title)
                model.langFilter = s.lang
                model.selectedSessionID = id
                if s.starter == .assistant { run(engine.respond(session: id)) }
            } catch { model.banner = "Не удалось создать сессию: \(error)" }
        }
    }

    func rename(_ id: String, _ title: String) { Task { try? await engine.rename(id, to: title) } }
    func delete(_ id: String) {
        Task {
            try? await engine.delete(id)
            if model.selectedSessionID == id { model.selectedSessionID = model.visibleSessions.first?.id }
        }
    }

    func select(_ id: String) {
        model.selectedSessionID = id
        model.refreshSelection()
    }

    func revealJournal() {
        NSWorkspace.shared.activateFileViewerSelecting([store.ownDir])
    }

    /// Клик по пузырю (R-41): пользователь — правка (R-09), помощник — повтор озвучки (P-07).
    func tapped(_ m: ChatMessage) {
        if m.role == .user { model.editing = m } else if m.kind == .normal { replay(m) }
    }

    // MARK: Ход текстом (R-43)

    func sendText() {
        let text = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let sid = model.selectedSessionID, let s = model.selectedSession else { return }
        model.draft = ""
        let lang = WhisperEngine.scriptLang(text, candidates: [s.settings.lang, .ru]) ?? s.settings.lang
        let cmd = CommandDetector.detect(text)?.kind
        Task {
            if s.state == .ended { try? await engine.resume(sid) }
            run(engine.send(session: sid, text: text, lang: lang, command: cmd))
        }
    }

    /// «Ответить заново» (R-09): новый ответ на реплику пользователя.
    func regenerate(userMessageID: String) {
        guard let sid = model.selectedSessionID else { return }
        run(engine.respond(session: sid, replyTo: userMessageID))
    }

    func editMessage(_ id: String, text: String) {
        guard let sid = model.selectedSessionID else { return }
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

/// Текущие настройки для замыканий вне главного потока.
final class SettingsRef: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: AppSettings
    init(_ v: AppSettings) { _value = v }
    var value: AppSettings {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
