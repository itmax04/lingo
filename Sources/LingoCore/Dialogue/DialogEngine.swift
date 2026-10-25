import Foundation

/// События хода (для интерфейса и голосового цикла).
public enum TurnEvent: Sendable, Equatable {
    /// Реплика пользователя записана в журнал (✓, R-38).
    case userSaved(messageID: String)
    case attempt(StepInfo)
    case firstToken(afterMs: Double)
    /// Законченное предложение `@say` — можно озвучивать (R-13).
    case speak(Lang, String)
    /// Частичный текст ответа для показа по мере генерации.
    case partial(String)
    /// Ответ начат заново на другом шаге цепочки: показанное и озвученное — сбросить.
    case restart
    case keyInvalid(keyID: String, reason: String)
    /// Ответ записан. `label` — «провайдер · модель» (R-29).
    case finished(messageID: String, label: String, segments: [ReplySegment], violations: Int)
    /// Цепочка исчерпана (S-18): реплика пользователя сохранена, «Ответить заново» доступна.
    case failed(reason: String, retryAfter: TimeInterval?)
    case cancelled
}

/// Диалог поверх журнала (R-01…R-04, R-09, R-20, R-22…R-25): все изменения — события `JournalStore`, ответы — через `ProviderChain`.
public actor DialogEngine {
    public let store: JournalStore
    private let makeChain: @Sendable () async -> ProviderChain
    public var policy: ContextPolicy
    private var summarizing: Set<String> = []

    public init(store: JournalStore, policy: ContextPolicy = ContextPolicy(), chain: @escaping @Sendable () async -> ProviderChain) {
        self.store = store
        self.policy = policy
        self.makeChain = chain
    }

    public func setPolicy(_ p: ContextPolicy) { policy = p }

    // MARK: Сессии (R-01, R-05)

    @discardableResult
    public func createSession(_ settings: SessionSettings, title: String? = nil) async throws -> String {
        let id = ULID.make().lowercased()
        let t = (title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? settings.defaultTitle
        try await store.append(EventType.sessionCreated, session: id, Payload.SessionCreated(title: t, settings: settings))
        return id
    }

    public func rename(_ session: String, to title: String) async throws {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        try await store.append(EventType.sessionUpdated, session: session, Payload.SessionUpdated(title: t))
    }

    public func updateSettings(_ session: String, _ settings: SessionSettings) async throws {
        try await store.append(EventType.sessionUpdated, session: session, Payload.SessionUpdated(settings: settings))
    }

    /// Удаление — событие-надгробие (R-05), синхронизируется.
    public func delete(_ session: String) async throws {
        try await store.append(EventType.sessionDeleted, session: session, payload: .object([:]))
    }

    public func resume(_ session: String) async throws {
        guard await store.state.sessions[session]?.state == .ended else { return }
        try await store.append(EventType.sessionResumed, session: session, payload: .object([:]))
    }

    /// Правка расшифровки (R-09) — событие `message.edited`.
    public func edit(_ messageID: String, session: String, text: String) async throws {
        try await store.append(EventType.messageEdited, session: session, Payload.MessageEdited(message: messageID, text: text))
    }

    /// Озвучка прервана (R-12): позиция в символах текста `@say`.
    public func markInterrupted(_ messageID: String, session: String, at: Int) async throws {
        try await store.append(EventType.messageInterrupted, session: session, Payload.MessageInterrupted(message: messageID, at: at))
    }

    /// Реплика-команда без ответа модели («повтори», «медленнее»): сохраняется в истории (R-14, R-15).
    @discardableResult
    public func recordUser(session: String, text: String, lang: Lang) async throws -> String {
        try await store.append(EventType.messageCreated, session: session, Payload.MessageCreated(role: .user, text: text, lang: lang)).id
    }

    // MARK: Ход

    /// Реплика пользователя → ответ помощника. `command` — локальный детектор (R-14…R-22).
    public nonisolated func send(session: String, text: String, lang: Lang, command: CommandKind? = nil) -> AsyncStream<TurnEvent> {
        AsyncStream { cont in
            let task = Task {
                do {
                    let ev = try await self.store.append(EventType.messageCreated, session: session,
                                                         Payload.MessageCreated(role: .user, text: text, lang: lang))
                    cont.yield(.userSaved(messageID: ev.id))
                    await self.reply(session: session, replyTo: ev.id, command: command, cont: cont)
                } catch {
                    cont.yield(.failed(reason: "\(error)", retryAfter: nil))
                }
                cont.finish()
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    /// Первая реплика помощника, если начинает он (S-01), или «Ответить заново» (R-09) без новой реплики пользователя.
    public nonisolated func respond(session: String, replyTo: String? = nil, command: CommandKind? = nil) -> AsyncStream<TurnEvent> {
        AsyncStream { cont in
            let task = Task {
                await self.reply(session: session, replyTo: replyTo, command: command, cont: cont)
                cont.finish()
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    private func reply(session: String, replyTo: String?, command: CommandKind?, cont: AsyncStream<TurnEvent>.Continuation) async {
        let st = await store.state
        guard let s = st.sessions[session] else { cont.yield(.failed(reason: "нет сессии", retryAfter: nil)); return }
        var history = st.messages[session] ?? []
        // «Ответить заново»: контекст — до реплики пользователя включительно (старый ответ не учитывается).
        if let r = replyTo, let i = history.firstIndex(where: { $0.id == r }) { history = Array(history[...i]) }
        let req = PromptBuilder.dialogRequest(settings: s.settings, summary: s.summary, messages: history, command: command, policy: policy)
        let chain = await makeChain()
        var parser = ReplyStreamParser(studyLang: s.settings.lang)
        var step: StepInfo?
        var actualModel: String?
        var t0 = Date()
        for await e in chain.run(req) {
            if Task.isCancelled { cont.yield(.cancelled); return }
            switch e {
            case .attempt(let info):
                step = info
                t0 = Date()
                cont.yield(.attempt(info))
            case .firstToken(_, let ms):
                cont.yield(.firstToken(afterMs: ms))
            case .text(let t):
                for item in parser.feed(t) { if case .speak(let l, let x) = item { cont.yield(.speak(l, x)) } }
                cont.yield(.partial(ReplyProtocol.stripThinking(parser.text)))
            case .restart:
                parser = ReplyStreamParser(studyLang: s.settings.lang)
                cont.yield(.restart)
            case .keyInvalid(let id, let err):
                cont.yield(.keyInvalid(keyID: id, reason: err.description))
            case .finished(let info, let model):
                step = info
                actualModel = model
            case .exhausted(let reason, let wait):
                let mins = wait.map { max(1, Int(($0 / 60).rounded(.up))) }
                let text = "Модели недоступны: \(reason)." + (mins.map { " Повторите через \($0) мин." } ?? "")
                _ = try? await store.append(EventType.messageCreated, session: session,
                                            Payload.MessageCreated(role: .assistant, text: text, lang: .ru, kind: .error, replyTo: replyTo))
                cont.yield(.failed(reason: reason, retryAfter: wait))
                return
            case .stepFailed, .usage:
                break
            }
        }
        if Task.isCancelled { cont.yield(.cancelled); return }
        for item in parser.finish() { if case .speak(let l, let x) = item { cont.yield(.speak(l, x)) } }
        let full = ReplyProtocol.parse(parser.text, studyLang: s.settings.lang)
        guard let step else { cont.yield(.failed(reason: "пустой ответ", retryAfter: nil)); return }
        let label = StepInfo(provider: step.provider, model: actualModel ?? step.model, keyID: step.keyID).label
        if full.violations > 0 {
            Log.metrics.notice("metric protocol_violation n=\(full.violations, privacy: .public) model=\(step.model, privacy: .public)")
        }
        Log.metrics.notice("metric llm_reply ms=\(Int(Date().timeIntervalSince(t0) * 1000), privacy: .public) model=\(step.model, privacy: .public)")
        do {
            var items: [(type: String, session: String, payload: JSONValue)] = [
                (EventType.messageCreated, session, try JSONValue.from(Payload.MessageCreated(
                    role: .assistant, text: ReplyProtocol.stripThinking(parser.text), lang: s.settings.lang, segments: full.segments,
                    source: label, replyTo: replyTo))),
            ]
            let events = try await store.appendBatch(items)
            let mid = events[0].id
            // @fix — в журнал для итога R-23 (во всех режимах); @hint — в подсказки (R-27).
            items = []
            for seg in full.segments {
                switch seg {
                case .fix(let f): items.append((EventType.fixRecorded, session, try JSONValue.from(Payload.FixRecorded(message: replyTo ?? mid, fix: f))))
                case .hint(let p): items.append((EventType.hintAdded, session, try JSONValue.from(Payload.HintAdded(phrase: p))))
                default: break
                }
            }
            if !items.isEmpty { try await store.appendBatch(items) }
            cont.yield(.finished(messageID: mid, label: label, segments: full.segments, violations: full.violations))
        } catch {
            cont.yield(.failed(reason: "\(error)", retryAfter: nil))
            return
        }
        await maybeSummarize(session)
    }

    // MARK: Завершение (R-22, R-23)

    /// «Завершить» или «на этом всё»: прощание на изучаемом языке (уже в ответе на команду finish), итог по-русски,
    /// если включён режим «после разговора» (R-23), состояние «завершена», краткое содержание.
    public func end(_ session: String) async {
        let st = await store.state
        guard let s = st.sessions[session], s.state != .ended else { return }
        if s.settings.corrections.contains(.after) {
            await recap(session)
        }
        _ = try? await store.append(EventType.sessionEnded, session: session, payload: .object([:]))
        await maybeSummarize(session, force: true)
    }

    /// Итог сессии (R-23): 3–5 главных ошибок «было → правильно → почему», 3 фразы для повторения, предложение продолжить сложнее.
    /// Сохраняется сообщением-карточкой (kind = summary).
    public func recap(_ session: String) async {
        let st = await store.state
        guard let s = st.sessions[session] else { return }
        let fixes = (st.fixes[session] ?? []).map(\.fix)
        let msgs = (st.messages[session] ?? []).filter { $0.kind == .normal }
        let req = PromptBuilder.recapRequest(settings: s.settings, fixes: fixes, messages: Array(msgs.suffix(40)))
        var text = ""
        for await e in await makeChain().run(req) {
            if case .text(let t) = e { text += t }
            if case .restart = e { text = "" }
            if case .exhausted = e { return }
        }
        let clean = ReplyProtocol.stripThinking(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        _ = try? await store.append(EventType.messageCreated, session: session,
                                    Payload.MessageCreated(role: .assistant, text: clean, lang: .ru, kind: .summary))
    }

    // MARK: Краткое содержание (R-04)

    /// Каждые `summaryEvery` ходов — отдельный запрос, результат — событие `summary.updated`.
    public func maybeSummarize(_ session: String, force: Bool = false) async {
        guard !summarizing.contains(session) else { return }
        let st = await store.state
        guard let s = st.sessions[session], let msgs = st.messages[session], !msgs.isEmpty else { return }
        guard force || policy.needsSummary(msgs, through: s.summaryThrough) else { return }
        summarizing.insert(session)
        defer { summarizing.remove(session) }
        let req = PromptBuilder.summaryRequest(settings: s.settings, previous: s.summary, messages: Array(msgs.suffix(policy.maxTurns * 2 + 2)))
        var text = ""
        for await e in await makeChain().run(req) {
            if case .text(let t) = e { text += t }
            if case .restart = e { text = "" }
            if case .exhausted = e { return }
        }
        let clean = ReplyProtocol.stripThinking(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let last = msgs.last else { return }
        _ = try? await store.append(EventType.summaryUpdated, session: session, Payload.SummaryUpdated(text: clean, through: last.id))
    }
}
