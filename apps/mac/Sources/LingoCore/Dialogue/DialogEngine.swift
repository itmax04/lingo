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
    /// The learner profile of each session, computed at its first turn and kept while the app runs (PR-01: the system part stays
    /// identical, cacheable); after a restart it is computed again from the journal as it was before the session started.
    private var frozenProfiles: [String: PromptProfile] = [:]
    /// Usage log — for service requests too (passed into the chain from outside).
    public var usage: UsageRecorder?

    public init(store: JournalStore, policy: ContextPolicy = ContextPolicy(), chain: @escaping @Sendable () async -> ProviderChain) {
        self.store = store
        self.policy = policy
        self.makeChain = chain
    }

    public func setPolicy(_ p: ContextPolicy) { policy = p }

    /// A warm-up and an exam never request a recap or a summary (PX-04).
    static func skipsRecapAndSummary(_ s: SessionSettings) -> Bool { s.activity?.kind == .warmup || s.activity?.kind == .exam }

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

    private func replyInner(session: String, replyTo: String?, command: CommandKind?, followUp: Bool = false,
                            cont: AsyncStream<TurnEvent>.Continuation) async {
        if command == .continuePractice { await skipWarmupCard(session) }  // WR-03: `continue` skips before the request names the next card
        let warmup = await warmupPrompt(session, followUp: followUp)
        let st = await store.state
        guard let s = st.sessions[session] else { cont.yield(.failed(reason: String(localized: "no session"), retryAfter: nil)); return }
        var history = st.messages[session] ?? []
        // "Reply again": the context goes up to and including the user's utterance (the old reply is ignored).
        if let r = replyTo, let i = history.firstIndex(where: { $0.id == r }) { history = Array(history[...i]) }
        // The profile is frozen per session (PR-01); the targets use the statistics from before the session (VR-06).
        let profile = frozenProfiles[session] ?? st.promptProfile(session: session)
        frozenProfiles[session] = profile
        let req = PromptBuilder.dialogRequest(settings: s.settings, summary: s.summary, messages: history, command: command, policy: policy,
                                              profile: profile, vocabulary: st.vocabTargets(session: session), warmup: warmup)
        let chain = await makeChain()
        var parser = ReplyStreamParser(studyLang: s.settings.lang)
        var step: StepInfo?
        var actualModel: String?
        var t0 = Date()
        for await e in chain.run(req) {
            if Task.isCancelled {
                await recordVocabularyUse(session: session, learnerMessage: replyTo, command: command, reply: nil, segments: [])
                cont.yield(.cancelled); return
            }
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
                // The learner's own use still counts when no model answered (VR-07).
                await recordVocabularyUse(session: session, learnerMessage: replyTo, command: command, reply: nil, segments: [])
                cont.yield(.failed(reason: reason, retryAfter: wait))
                return
            case .stepFailed, .usage, .rateLimits:
                break
            }
        }
        if Task.isCancelled {
            await recordVocabularyUse(session: session, learnerMessage: replyTo, command: command, reply: nil, segments: [])
            cont.yield(.cancelled); return
        }
        for item in parser.finish() { if case .speak(let l, let x) = item { cont.yield(.speak(l, x)) } }
        let full = ReplyProtocol.parse(parser.text, studyLang: s.settings.lang)
        guard let step else {
            await recordVocabularyUse(session: session, learnerMessage: replyTo, command: command, reply: nil, segments: [])
            cont.yield(.failed(reason: String(localized: "empty reply"), retryAfter: nil)); return
        }
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
            await recordVocabularyUse(session: session, learnerMessage: replyTo, command: command, reply: mid, segments: full.segments)
            let moved = await rateWarmupCard(session, learnerMessage: replyTo, command: command, reply: parser.text)
            cont.yield(.finished(messageID: mid, label: label, segments: full.segments, violations: full.violations))
            // The engine moved on after the reply was generated: name the new card in one more request, or close (WR-03, WR-04).
            if moved, let w = await warmupPrompt(session, followUp: true) {
                if w.card != nil {
                    await replyInner(session: session, replyTo: nil, command: nil, followUp: true, cont: cont)
                } else if warmup?.next != nil {
                    await sayWarmupClosing(session, cont: cont)
                }
            }
        } catch {
            await recordVocabularyUse(session: session, learnerMessage: replyTo, command: command, reply: nil, segments: [])
            cont.yield(.failed(reason: "\(error)", retryAfter: nil))
            return
        }
    }

    // MARK: Warm-up (LINGO-05 WR-01…WR-04)

    /// A warm-up over today's queue of a language (WR-01): nil when nothing is due or new.
    public func startWarmup(lang: Lang, corrections: Set<CorrectionMode>, level: String = "", now: Date = Date(),
                            calendar: Calendar = .autoupdatingCurrent) async throws -> String? {
        let queue = await store.state.dueCards(lang: lang, now: now, calendar: calendar).prefix(Warmup.maxCards).map(\.id)
        guard !queue.isEmpty else { return nil }
        return try await createSession(Warmup.settings(lang: lang, cards: Array(queue), corrections: corrections, level: level))
    }

    /// The `<card>` / `<next_card>` of the next request; nil outside a warm-up. A card whose source disappeared is skipped.
    func warmupPrompt(_ session: String, followUp: Bool) async -> PromptBuilder.WarmupPrompt? {
        for _ in 0...Warmup.maxCards {
            let st = await store.state
            guard let lang = st.sessions[session]?.settings.lang, let w = st.warmupState(session: session, now: Date()) else { return nil }
            guard let id = w.current else { return PromptBuilder.WarmupPrompt(card: nil, next: nil, followUp: followUp) }
            guard let card = st.card(id, lang: lang) else { await review(session, card: id, .again, message: ""); continue }
            return PromptBuilder.WarmupPrompt(card: card, next: w.next.flatMap { st.card($0, lang: lang) }, followUp: followUp)
        }
        return nil
    }

    /// `continue` in a warm-up: the current card is skipped as `again` (WR-03).
    func skipWarmupCard(_ session: String) async {
        guard let cur = await store.state.warmupState(session: session, now: Date())?.current else { return }
        await review(session, card: cur, .again, message: "")
    }

    /// Rates the current card from the reply (WR-03). Returns true when the engine, not the model, moved on (local match or skip), so
    /// the next card still has to be set up.
    func rateWarmupCard(_ session: String, learnerMessage: String?, command: CommandKind?, reply: String) async -> Bool {
        let st = await store.state
        guard command == nil, let mid = learnerMessage, let s = st.sessions[session], let w = st.warmupState(session: session, now: Date()),
              let cur = w.current, let m = st.messages[session]?.first(where: { $0.id == mid }), m.role == .user, m.lang != .ru,
              CommandDetector.detect(m.text) == nil else { return false }
        let grade = Warmup.grade(in: reply)
        if let g = grade, let r = CardRating(rawValue: g) {
            await review(session, card: cur, Warmup.capped(r, russian: w.russianOnCurrent), message: mid)
            return false
        }
        if grade == "wait" { return false }
        if let card = st.card(cur, lang: s.settings.lang), card.kind == .word,
           VocabularyMatcher.contains(card.front, in: m.text, lang: s.settings.lang) {
            await review(session, card: cur, Warmup.capped(.good, russian: w.russianOnCurrent), message: mid)
            return true
        }
        if w.unratedAnswers >= Warmup.unratedLimit {
            await review(session, card: cur, .again, message: "")
            return true
        }
        return false
    }

    func review(_ session: String, card: String, _ rating: CardRating, message: String) async {
        _ = try? await store.append(EventType.cardReviewed, session: session, Payload.CardReviewed(card: card, rating: rating, message: message))
    }

    /// The fixed closing line when the warm-up ends without a model turn (WR-04).
    func sayWarmupClosing(_ session: String, cont: AsyncStream<TurnEvent>.Continuation) async {
        guard let lang = await store.state.sessions[session]?.settings.lang else { return }
        let line = Warmup.closingLine(lang)
        guard let ev = try? await store.append(EventType.messageCreated, session: session, Payload.MessageCreated(
            role: .assistant, text: "@say \(lang.rawValue): \(line)", lang: lang, segments: [.say(lang, line)])) else { return }
        cont.yield(.speak(lang, line))
        cont.yield(.finished(messageID: ev.id, label: "", segments: [.say(lang, line)], violations: 0))
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
        // Never for a teacher activity (PX-04): a scenario has its own phrases, a warm-up and an exam need none.
        guard let s = st.sessions[session], s.settings.activity == nil, (st.hints[session] ?? []).filter({ $0.source == .topic }).count < 6 else { return }
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

    // MARK: My vocabulary (LINGO-08, VR-03, VR-04) and the learner profile (PR-01)

    /// Adds items; an item whose normalised text already exists in that language is skipped, a text over 120 characters is rejected
    /// (VR-03). Returns (added, duplicates, rejected).
    @discardableResult
    public func addVocabulary(lang: Lang, entries: [(text: String, translation: String)], source: VocabSource) async throws
        -> (added: Int, duplicates: Int, rejected: Int) {
        let st = await store.state
        // A duplicate is the current text of an item or the original text of an edited one (that text still belongs to it, VR-02).
        var keys = Set(st.vocabulary(lang: lang).map { VocabularyText.key(lang: $0.lang, text: $0.text) }).union(st.vocabAddKeys)
        var batch: [(type: String, session: String, payload: JSONValue)] = []
        var dup = 0, rejected = 0
        for e in entries {
            let text = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !VocabularyText.normalize(text).isEmpty else { continue }
            guard text.count <= 120 else { rejected += 1; continue }
            let key = VocabularyText.key(lang: lang, text: text)
            guard keys.insert(key).inserted else { dup += 1; continue }
            let tr = String(e.translation.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160))
            batch.append((EventType.vocabAdded, "", try JSONValue.from(Payload.VocabAdded(item: Payload.VocabDraft(
                lang: lang, text: text, translation: tr.isEmpty ? nil : tr, source: source)))))
        }
        if !batch.isEmpty { _ = try await store.appendBatch(batch) }
        return (batch.count, dup, rejected)
    }

    public enum VocabularyError: Error, Equatable { case emptyText, tooLong, starredItem, unknownItem }

    /// Updates an own item (★ items cannot be edited, VR-01a); an empty text is rejected.
    public func updateVocabulary(_ id: String, text: String? = nil, translation: String? = nil, note: String? = nil, example: String? = nil) async throws {
        if id.hasPrefix("star:") { throw VocabularyError.starredItem }
        guard await store.state.vocab[id] != nil else { throw VocabularyError.unknownItem }
        let text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = text, VocabularyText.normalize(t).isEmpty { throw VocabularyError.emptyText }
        if let t = text, t.count > 120 { throw VocabularyError.tooLong }
        try await store.append(EventType.vocabUpdated, session: "", Payload.VocabUpdated(
            item: id, text: text, translation: translation.map { String($0.prefix(160)) },
            note: note.map { String($0.prefix(300)) }, example: example.map { String($0.prefix(200)) }))
    }

    /// Removes an item; a ★ phrase is un-starred instead.
    public func removeVocabulary(_ id: String) async throws {
        let st = await store.state
        if id.hasPrefix("star:") {
            // VR-01a: removing a ★ item un-stars every ★ phrase with that key.
            for p in st.starred.values where VocabItem.starredID(lang: p.lang, text: p.text) == id {
                try await store.append(EventType.phraseUnstarred, session: "", Payload.PhraseMark(phrase: p))
            }
            return
        }
        try await store.append(EventType.vocabRemoved, session: "", Payload.VocabRemoved(item: id))
    }

    /// The daily goal in minutes (LINGO-05 GR-02), clamped to 5–120; a journal event, so it follows the learner to other devices.
    public func setDailyGoal(minutes: Int) async throws {
        let m = min(HistoryState.goalRange.upperBound, max(HistoryState.goalRange.lowerBound, minutes))
        try await store.append(EventType.goalSet, session: "", Payload.GoalSet(minutes: m))
    }

    public func updateProfile(goals: String? = nil, interests: String? = nil) async throws {
        try await store.append(EventType.profileUpdated, session: "", Payload.ProfileUpdated(
            goals: goals.map { String($0.prefix(300)) }, interests: interests.map { String($0.prefix(300)) }))
    }

    /// Usage detection after a turn (VR-07): every item of the session language found in the learner's utterance (not a command, not
    /// Russian) and in the assistant's `@say` lines gives one `vocab.used` event. No model call. The learner side is also written when the
    /// reply failed or was cancelled; the merge de-duplicates per (item, by, message), so a later "Reply again" does not count it twice.
    /// "Reply again" and merged utterances do not carry the detected command, so it is detected again from the stored text.
    func recordVocabularyUse(session: String, learnerMessage: String?, command: CommandKind?, reply: String?, segments: [ReplySegment]) async {
        let st = await store.state
        guard let s = st.sessions[session], s.settings.vocabularyOn else { return }
        let lang = s.settings.lang
        let items = st.vocabulary(lang: lang)
        guard !items.isEmpty else { return }
        var batch: [(type: String, session: String, payload: JSONValue)] = []
        if command == nil, let mid = learnerMessage, let m = st.messages[session]?.first(where: { $0.id == mid }), m.role == .user, m.lang != .ru,
           CommandDetector.detect(m.text) == nil {
            let fixes = segments.compactMap { seg -> Fix? in if case .fix(let f) = seg { return f }; return nil }
            for item in items where VocabularyMatcher.contains(item.text, in: m.text, lang: lang) {
                if let p = try? JSONValue.from(Payload.VocabUsed(item: item.id, message: mid, by: .learner, outcome: VocabularyMatcher.outcome(item, fixes: fixes))) {
                    batch.append((EventType.vocabUsed, session, p))
                }
            }
        }
        if let rid = reply {
            let said = segments.compactMap { seg -> String? in if case .say(let l, let t) = seg, l == lang { return t }; return nil }.joined(separator: " ")
            for item in items where VocabularyMatcher.contains(item.text, in: said, lang: lang) {
                if let p = try? JSONValue.from(Payload.VocabUsed(item: item.id, message: rid, by: .assistant, outcome: .ok)) {
                    batch.append((EventType.vocabUsed, session, p))
                }
            }
        }
        if !batch.isEmpty { _ = try? await store.appendBatch(batch) }
    }

    /// The session's targets for the prompt and for speech recognition (VR-06, VR-07c).
    public func vocabularyTargets(session: String) async -> [VocabItem] { await store.state.vocabTargets(session: session) }

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

    /// The goodbye of "Finish" (R-22): a fixed short phrase in the study language, written as an assistant message. It does not call a model:
    /// a model asked to "finish" answered the last utterance instead (a question), and every click produced one more such reply.
    /// Returns nil when the session is missing or already finished, so a second click changes nothing.
    public func farewell(session: String) async -> (lang: Lang, text: String)? {
        let st = await store.state
        guard let s = st.sessions[session], s.state != .ended else { return nil }
        // The study language is en or de; Russian is never spoken without a request (R-26), so anything else gets the English line.
        let lang: Lang = s.settings.lang == .de ? .de : .en
        let text = lang == .de ? "Das war eine gute Übung. Bis zum nächsten Mal!" : "That was good practice. See you next time!"
        let seg = ReplySegment.say(lang, text)
        do {
            _ = try await store.append(EventType.messageCreated, session: session,
                                       Payload.MessageCreated(role: .assistant, text: "@say \(lang.rawValue): \(text)", lang: lang, segments: [seg], source: "Lingo"))
        } catch { return nil }  // a goodbye that is not in the journal is not spoken either
        return (lang, text)
    }

    /// "Finish" or "that's all": a goodbye in the target language (already in the reply to the finish command), a recap in Russian
    /// if the "after the conversation" mode is on (R-23), the "finished" state, and a summary.
    public func end(_ session: String) async {
        guard await markEnded(session) else { return }
        await finalizeEnded(session)
    }

    /// The "finished" state, written at once (no model call), so the app can accept input again right away.
    /// Returns false when the session is missing or was already finished.
    public func markEnded(_ session: String) async -> Bool {
        let st = await store.state
        guard let s = st.sessions[session], s.state != .ended else { return false }
        _ = s
        _ = try? await store.append(EventType.sessionEnded, session: session, payload: .object([:]))
        return true
    }

    /// What follows the end of a session and needs the model: the recap in the "after" mode (R-23) and the final summary.
    public func finalizeEnded(_ session: String) async {
        let st = await store.state
        guard let s = st.sessions[session], !Self.skipsRecapAndSummary(s.settings) else { return }
        if s.settings.corrections.contains(.after) { await recap(session) }
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
        guard let s = st.sessions[session], !Self.skipsRecapAndSummary(s.settings), let msgs = st.messages[session], !msgs.isEmpty else { return }
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
