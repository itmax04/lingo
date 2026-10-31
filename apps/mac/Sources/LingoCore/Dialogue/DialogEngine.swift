import Foundation

/// Turn events (for the UI and the voice loop).
public enum TurnEvent: Sendable, Equatable {
    /// The user's utterance has been written to the journal (✓, R-38).
    case userSaved(messageID: String)
    case attempt(StepInfo)
    case firstToken(afterMs: Double)
    /// A finished `@say` sentence — ready to be spoken (R-13).
    case speak(Lang, String)
    /// Partial reply text, shown while it is being generated.
    case partial(String)
    /// The reply restarted on another chain step: discard what was shown and spoken.
    case restart
    case keyInvalid(keyID: String, reason: String)
    /// The reply has been saved. `label` — "provider · model" (R-29).
    case finished(messageID: String, label: String, segments: [ReplySegment], violations: Int)
    /// The chain is exhausted (S-18): the user's utterance is saved and "Reply again" is available.
    case failed(reason: String, retryAfter: TimeInterval?)
    case cancelled
}

/// Dialogue on top of the journal (R-01…R-04, R-09, R-20, R-22…R-25): every change is a `JournalStore` event, replies come through `ProviderChain`.
public actor DialogEngine {
    public let store: JournalStore
    private let makeChain: @Sendable () async -> ProviderChain
    public var policy: ContextPolicy
    private var summarizing: Set<String> = []
    /// Dispatcher (R-52): whether a user turn is in progress; background requests wait for it to finish.
    private var dialogInFlight = 0
    private var pendingTopicPhrases: Set<String> = []
    /// Usage log — for service requests too (passed into the chain from outside).
    public var usage: UsageRecorder?

    public init(store: JournalStore, policy: ContextPolicy = ContextPolicy(), chain: @escaping @Sendable () async -> ProviderChain) {
        self.store = store
        self.policy = policy
        self.makeChain = chain
    }

    public func setPolicy(_ p: ContextPolicy) { policy = p }

    // MARK: Sessions (R-01, R-05)

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

    /// Deletion is a tombstone event (R-05) and is synced.
    public func delete(_ session: String) async throws {
        try await store.append(EventType.sessionDeleted, session: session, payload: .object([:]))
    }

    public func resume(_ session: String) async throws {
        guard await store.state.sessions[session]?.state == .ended else { return }
        try await store.append(EventType.sessionResumed, session: session, payload: .object([:]))
    }

    /// Transcript edit (R-09) — a `message.edited` event.
    public func edit(_ messageID: String, session: String, text: String) async throws {
        try await store.append(EventType.messageEdited, session: session, Payload.MessageEdited(message: messageID, text: text))
    }

    /// Speech was interrupted (R-12): position in characters of the `@say` text.
    public func markInterrupted(_ messageID: String, session: String, at: Int) async throws {
        try await store.append(EventType.messageInterrupted, session: session, Payload.MessageInterrupted(message: messageID, at: at))
    }

    /// A command utterance without a model reply ("repeat", "slower"): kept in the history (R-14, R-15).
    @discardableResult
    public func recordUser(session: String, text: String, lang: Lang) async throws -> String {
        try await store.append(EventType.messageCreated, session: session, Payload.MessageCreated(role: .user, text: text, lang: lang)).id
    }

    // MARK: Turn

    /// User utterance → assistant reply. `command` — from the local detector (R-14…R-22).
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

    /// The assistant's first message if it starts (S-01), or "Reply again" (R-09) without a new user utterance.
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
        dialogInFlight += 1
        defer { dialogInFlight -= 1 }
        await replyInner(session: session, replyTo: replyTo, command: command, cont: cont)
        // Background requests run after the turn and only when there is quota to spare (R-27, R-04, R-52).
        let engine = self
        Task.detached { await engine.runBackground(session) }
    }

    private func replyInner(session: String, replyTo: String?, command: CommandKind?, cont: AsyncStream<TurnEvent>.Continuation) async {
        let st = await store.state
        guard let s = st.sessions[session] else { cont.yield(.failed(reason: String(localized: "no session"), retryAfter: nil)); return }
        var history = st.messages[session] ?? []
        // "Reply again": the context goes up to and including the user's utterance (the old reply is ignored).
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
                // A time only if the provider reported one (R-52).
                let text = String(localized: "Models are unavailable: \(reason).") + " "
                    + (wait.map { String(localized: "Next attempt in \(LLMError.human($0)).") }
                        ?? String(localized: "The provider did not say when it will recover."))
                _ = try? await store.append(EventType.messageCreated, session: session,
                                            Payload.MessageCreated(role: .assistant, text: text, lang: .ru, kind: .error, replyTo: replyTo))
                cont.yield(.failed(reason: reason, retryAfter: wait))
                return
            case .stepFailed, .usage, .rateLimits:
                break
            }
        }
        if Task.isCancelled { cont.yield(.cancelled); return }
        for item in parser.finish() { if case .speak(let l, let x) = item { cont.yield(.speak(l, x)) } }
        let full = ReplyProtocol.parse(parser.text, studyLang: s.settings.lang)
        guard let step else { cont.yield(.failed(reason: String(localized: "empty reply"), retryAfter: nil)); return }
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
            // @fix goes to the journal for the R-23 recap (in every mode); @hint goes to the hints (R-27).
            items = []
            for seg in full.segments {
                switch seg {
                case .fix(let f): items.append((EventType.fixRecorded, session, try JSONValue.from(Payload.FixRecorded(message: replyTo ?? mid, fix: f))))
                case .hint(var p):
                    // Hints section (R-27): the reply to "how to say" goes to "How to say", other @hint lines go to topic phrases.
                    p.source = command == .howToSay ? .howToSay : .topic
                    items.append((EventType.hintAdded, session, try JSONValue.from(Payload.HintAdded(phrase: p))))
                default: break
                }
            }
            if !items.isEmpty { try await store.appendBatch(items) }
            cont.yield(.finished(messageID: mid, label: label, segments: full.segments, violations: full.violations))
        } catch {
            cont.yield(.failed(reason: "\(error)", retryAfter: nil))
            return
        }
    }

    /// Background requests after a turn: topic phrases (once) and the summary (every 10 turns) — if no turn is running and quota allows.
    func runBackground(_ session: String) async {
        guard dialogInFlight == 0, await quotaAllowsBackground() else { return }
        if pendingTopicPhrases.contains(session) {
            pendingTopicPhrases.remove(session)
            await generateTopicPhrases(session)
        }
        guard dialogInFlight == 0, await quotaAllowsBackground() else { return }
        await maybeSummarize(session)
    }

    /// Whether quota allows a service request: the first available step is not paused and its headers show ≥ 3000 tokens per minute.
    func quotaAllowsBackground() async -> Bool {
        let chain = await makeChain()
        let (run, _) = chain.plan(needed: 3000)
        guard let first = run.first else { return false }
        return chain.health.pause(for: first.info) == nil && chain.health.hasRoom(first.info, needed: 3000)
    }

    /// Topic phrases (R-27) are requested after the assistant's first reply, not immediately: the first turn matters more (R-52).
    public func requestTopicPhrases(_ session: String) {
        pendingTopicPhrases.insert(session)
    }

    // MARK: Topic phrases (R-27)

    /// 6–8 topic phrases with translations — a separate background request at session start; the first turn does not wait for it.
    public func generateTopicPhrases(_ session: String) async {
        let st = await store.state
        guard let s = st.sessions[session], (st.hints[session] ?? []).filter({ $0.source == .topic }).count < 6 else { return }
        let req = PromptBuilder.topicPhrasesRequest(settings: s.settings)
        var text = ""
        for await e in await makeChain().run(req) {
            if case .text(let t) = e { text += t }
            if case .restart = e { text = "" }
            if case .exhausted = e { return }
        }
        let phrases = ReplyProtocol.parse(text, studyLang: s.settings.lang).segments.compactMap { seg -> Phrase? in
            guard case .hint(var p) = seg else { return nil }
            p.source = .topic
            return p
        }
        guard !phrases.isEmpty else { return }
        let items = phrases.prefix(8).compactMap { p in
            (try? JSONValue.from(Payload.HintAdded(phrase: p))).map { (type: EventType.hintAdded, session: session, payload: $0) }
        }
        _ = try? await store.appendBatch(Array(items))
    }

    // MARK: Vocabulary ★ (R-28)

    public func star(_ p: Phrase, on: Bool) async throws {
        try await store.append(on ? EventType.phraseStarred : EventType.phraseUnstarred, session: "", Payload.PhraseMark(phrase: p))
    }

    // MARK: Translation of one message (user action)

    public enum TranslationError: Error, Equatable { case unavailable(String), empty }

    /// Translates `text` into Russian with the model chain. Not stored in the journal. Throws when no model answers.
    public func translate(_ text: String, from lang: Lang) async throws -> String {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw TranslationError.empty }
        var out = ""
        for await e in await makeChain().run(PromptBuilder.translateRequest(text: source, from: lang)) {
            switch e {
            case .text(let t): out += t
            case .restart: out = ""
            case .exhausted(let reason, _): throw TranslationError.unavailable(reason)
            default: break
            }
        }
        if Task.isCancelled { throw CancellationError() }
        let clean = ReplyProtocol.stripThinking(out).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw TranslationError.empty }
        return clean
    }

    // MARK: Finishing (R-22, R-23)

    /// "Finish" or "that's all": a goodbye in the target language (already in the reply to the finish command), a recap in Russian
    /// if the "after the conversation" mode is on (R-23), the "finished" state, and a summary.
    public func end(_ session: String) async {
        let st = await store.state
        guard let s = st.sessions[session], s.state != .ended else { return }
        if s.settings.corrections.contains(.after) {
            await recap(session)
        }
        _ = try? await store.append(EventType.sessionEnded, session: session, payload: .object([:]))
        await maybeSummarize(session, force: true)
    }

    /// Session recap (R-23): 3–5 main mistakes "wrong → right → why", 3 phrases to review, a suggestion to continue at a harder level.
    /// Saved as a card message (kind = summary).
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

    // MARK: Summary (R-04)

    /// Every `summaryEvery` turns — a separate request; the result is a `summary.updated` event.
    public func maybeSummarize(_ session: String, force: Bool = false) async {
        guard !summarizing.contains(session) else { return }
        let st = await store.state
        guard let s = st.sessions[session], let msgs = st.messages[session], !msgs.isEmpty else { return }
        guard force || policy.needsSummary(msgs, through: s.summaryThrough) else { return }
        summarizing.insert(session)
        defer { summarizing.remove(session) }
        // Only new turns since the previous summary (+2 for continuity), not the whole window (R-52).
        let req = PromptBuilder.summaryRequest(settings: s.settings, previous: s.summary, messages: Array(msgs.suffix(policy.summaryEvery * 2 + 2)))
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
