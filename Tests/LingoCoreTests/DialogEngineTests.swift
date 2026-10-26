import Foundation
import Testing
@testable import LingoCore

@Suite struct DialogEngineTests {
    func engine(_ behavior: @escaping @Sendable (String, String) -> MockProvider.Behavior) throws -> (DialogEngine, JournalStore) {
        let store = try JournalStore(base: tempDir("dlg"), deviceName: "Mac", deviceID: "mac-test")
        let p = MockProvider(id: .groq, behavior: behavior, calls: CallLog())
        let settings = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")],
                                   chain: [ChainEntry(provider: .groq, model: "openai/gpt-oss-120b")], firstTokenTimeout: 2)
        let secrets = InMemorySecretStore(["k": "synthetic"])
        let e = DialogEngine(store: store) {
            ChainFactory.chain(settings: settings, secrets: secrets, health: ProviderHealth(), providers: [.groq: p])
        }
        return (e, store)
    }

    @Test func turnWritesUserAssistantFixAndHint() async throws {
        let (e, store) = try engine { _, _ in .text(["@say de: Fast! Natürlicher: „seit zwei Jahren“.\n@fix: seit zwei Jahre → seit zwei Jahren | Dativ\n",
                                                     "@hint de: Ich wohne seit zwei Jahren hier. | Я живу здесь два года.\n@say de: Sag das bitte noch einmal."]) }
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .questions, topic: "Wohnort", level: "A2", corrections: [.inline]))
        var events: [TurnEvent] = []
        for await ev in e.send(session: sid, text: "Ich wohne hier seit zwei Jahre.", lang: .de) { events.append(ev) }
        let spoken = events.compactMap { if case .speak(_, let t) = $0 { return t }; return nil }
        #expect(spoken.first?.hasPrefix("Fast!") == true && spoken.last == "Sag das bitte noch einmal.")
        guard case .finished(_, let label, let segs, let bad)? = events.last else { Issue.record("\(events)"); return }
        #expect(label == "Groq · gpt-oss-120b" && bad == 0 && segs.count == 4)
        let st = await store.state
        let msgs = st.messages[sid]!
        #expect(msgs.map(\.role) == [.user, .assistant])
        #expect(msgs[1].source == "Groq · gpt-oss-120b")
        #expect(st.fixes[sid]?.first?.fix.corrected == "seit zwei Jahren")
        #expect(st.fixes[sid]?.first?.message == msgs[0].id)
        #expect(st.hints[sid]?.first?.text == "Ich wohne seit zwei Jahren hier.")
        #expect(st.sessions[sid]?.title == "Questions: Wohnort")
    }

    @Test func exhaustedSavesUserAndErrorMessage() async throws {
        let (e, store) = try engine { _, _ in .fail(.http(status: 429, message: "", retryAfter: 120)) }
        let sid = try await e.createSession(SessionSettings(lang: .en, mode: .free, corrections: [.after]))
        var last: TurnEvent?
        for await ev in e.send(session: sid, text: "Hello", lang: .en) { last = ev }
        guard case .failed(_, let wait)? = last else { Issue.record("\(String(describing: last))"); return }
        #expect((wait ?? 0) > 100)
        let msgs = await store.state.messages[sid]!
        #expect(msgs.count == 2 && msgs[0].text == "Hello")
        #expect(msgs[1].kind == .error && msgs[1].text.hasPrefix("Models are unavailable:") && msgs[1].text.contains("Next attempt in 2 min"))
        // The error message does not go into the model context (ContextPolicy).
        #expect(ContextPolicy().window(msgs).count == 1)
    }

    @Test func summaryAfterTenTurnsAndRegenerate() async throws {
        let (e, store) = try engine { _, _ in .text(["@say en: Nice! And then?"]) }
        let sid = try await e.createSession(SessionSettings(lang: .en, mode: .free, corrections: [.inline]))
        for i in 0..<10 { for await _ in e.send(session: sid, text: "Turn \(i)", lang: .en) {} }
        let st = await store.state
        #expect(st.sessions[sid]?.summary == "@say en: Nice! And then?" || !(st.sessions[sid]?.summary.isEmpty ?? true))
        #expect(st.sessions[sid]?.summaryThrough != nil)
        // "Reply again" to the first utterance — a new reply with replyTo.
        let firstUser = st.messages[sid]!.first { $0.role == .user }!.id
        var fin = false
        for await ev in e.respond(session: sid, replyTo: firstUser) { if case .finished = ev { fin = true } }
        #expect(fin)
        #expect(await store.state.messages[sid]!.count == 21)
    }

    @Test func renameDeleteEndResume() async throws {
        let (e, store) = try engine { _, _ in .text(["@say de: Hallo!"]) }
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .free, corrections: [.inline]), title: "At the café")
        try await e.rename(sid, to: "A café in Vienna")
        #expect(await store.state.sessions[sid]?.title == "A café in Vienna")
        try await store.append(EventType.sessionEnded, session: sid, payload: .object([:]))
        #expect(await store.state.sessions[sid]?.state == .ended)
        try await e.resume(sid)
        #expect(await store.state.sessions[sid]?.state == .active)
        try await e.delete(sid)
        #expect(await store.state.visibleSessions().isEmpty)
    }
}

@Suite struct HintsTests {
    @Test func topicPhrasesHowToSayAndStars() async throws {
        let store = try JournalStore(base: tempDir("hints"), deviceName: "Mac", deviceID: "mac-h")
        let calls = CallLog()
        let p = MockProvider(id: .groq, behavior: { _, _ in
            calls.add("x")
            if calls.all.count == 1 {  // the counter is only for behaviour (MockProvider keeps its own log)
                return .text(["@hint de: Ich wohne in Hamburg. | Я живу в Гамбурге.\n@hint de: Seit wann wohnen Sie hier? | С каких пор вы здесь живёте?\n",
                              "@hint de: Mir gefällt das Meer. | Мне нравится море.\n@hint de: Es ist ruhig hier. | Здесь тихо.\n",
                              "@hint de: Die Miete ist hoch. | Аренда высокая.\n@hint de: Ich mag den Hafen. | Мне нравится порт."])
            }
            return .text(["@say de: Zurzeit habe ich Ferien.\n@hint de: Zurzeit habe ich Ferien. | Сейчас у меня каникулы.\n@say de: Sag das bitte noch einmal."])
        }, calls: CallLog())
        let llm = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "m")])
        let secrets = InMemorySecretStore(["k": "synthetic"])
        let e = DialogEngine(store: store) { ChainFactory.chain(settings: llm, secrets: secrets, health: ProviderHealth(), providers: [.groq: p]) }
        let sid = try await e.createSession(SessionSettings(lang: .de, mode: .questions, topic: "Wohnort", level: "A2", corrections: [.inline]))
        await e.generateTopicPhrases(sid)
        for await _ in e.send(session: sid, text: "Как сказать «у меня сейчас каникулы»?", lang: .ru, command: .howToSay) {}
        let st = await store.state
        let hints = st.hints[sid] ?? []
        #expect(hints.filter { $0.source == .topic }.count == 6)
        #expect(hints.first { $0.source == .howToSay }?.text == "Zurzeit habe ich Ferien.")
        let phrase = hints[0]
        try await e.star(phrase, on: true)
        #expect(await store.state.starred[phrase.id]?.text == "Ich wohne in Hamburg.")
        try await e.star(phrase, on: false)
        #expect(await store.state.starred.isEmpty)
        // Requesting topic phrases again does not duplicate them.
        await e.generateTopicPhrases(sid)
        #expect((await store.state.hints[sid] ?? []).filter { $0.source == .topic }.count == 6)
    }
}
