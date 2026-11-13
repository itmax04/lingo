import Foundation
import LingoCore
import Testing
@testable import LingoMac

/// LINGO-09 M-11b (MAC-32, MAC-33): the block's life around a turn, reveal and its record, Insert, refresh and its limits.
/// Synthetic data only: no key, no audio, no network.
@MainActor @Suite(.serialized) struct ReplyOptionsHostTests {
    final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        private var out: String
        var reply: String { get { lock.withLock { out } } set { lock.withLock { out = newValue } } }
        var count: Int { lock.withLock { n } }
        init(_ reply: String) { out = reply }
        func hit() -> String { lock.withLock { n += 1; return out } }
    }
    struct Provider: LLMProvider {
        let id = ProviderID.groq
        let calls: Calls
        let fail: Bool
        func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error> {
            let text = calls.hit()
            return AsyncThrowingStream { c in
                if fail { c.finish(throwing: LLMError.http(status: 429, message: "quota", retryAfter: 60)) }
                else { c.yield(.text(text)); c.finish() }
            }
        }
    }

    static let anchorText = "@say en: Where do you live?\n@reply en: I live in Berlin. | Я живу в Берлине.\n@reply en: In a small village near Hamburg. | В маленькой деревне.\n@reply en: Not far from here. | Недалеко отсюда."

    @MainActor final class Env {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-reply-host-" + UUID().uuidString)
        let suite = "lingo-reply-host-" + UUID().uuidString
        let model = AppModel()
        let services: AppServices
        let calls = Calls("@reply en: Fresh one here. | Свежий.\n@reply en: Another fresh answer. | Другой.")
        init(fail: Bool = false) throws {
            let defaults = try #require(UserDefaults(suiteName: suite))
            let settings = LLMSettings(keys: [KeyRecord(id: "fixture", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "mock")])
            let provider = Provider(calls: calls, fail: fail)
            services = try AppServices(model: model, settingsStore: SettingsStore(defaults: defaults), secrets: InMemorySecretStore(), base: base, chain: {
                ChainFactory.chain(settings: settings, secrets: InMemorySecretStore(["fixture": "synthetic"]), health: ProviderHealth(), providers: [.groq: provider])
            })
            model.services = services
            model.hasKey = true
            model.networkUp = true
            model.recomputeOnline()
        }
        /// Switch on; `updateSettings` recomputes `hasKey` from the (empty) stored settings, so the fixture key is restored.
        func switchOn() {
            services.toggleReplyOptions()
            model.hasKey = true
            model.recomputeOnline()
        }
        func clean() {
            try? FileManager.default.removeItem(at: base)
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        /// A session whose last model message is `text`, selected in the model.
        @discardableResult func session(_ s: SessionSettings = SessionSettings(lang: .en, mode: .free, corrections: [.inline]), anchor text: String = ReplyOptionsHostTests.anchorText) async throws -> String {
            let sid = try await services.engine.createSession(s)
            _ = try await services.store.append(EventType.messageCreated, session: sid,
                Payload.MessageCreated(role: .assistant, text: text, lang: .en, segments: ReplyProtocol.parse(text, studyLang: .en).segments, source: "Groq · mock"))
            model.apply(await services.store.state)
            model.selectedSessionID = sid
            model.refreshSelection()
            return sid
        }
        func revealEvents(_ sid: String) async -> [Payload.ReplyRevealed] {
            await services.store.allEvents().filter { $0.type == EventType.replyRevealed && $0.session == sid }
                .compactMap { try? $0.payload.decode(Payload.ReplyRevealed.self) }
        }
    }

    func wait(_ condition: () -> Bool) async {
        for _ in 0..<400 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }

    @Test func theBlockFollowsTheSwitchAndTheTurn() async throws {
        let e = try Env(); defer { e.clean() }
        let sid = try await e.session()
        #expect(!e.model.replyBlockShown, "off by default")
        e.services.toggleReplyOptions()
        #expect(e.model.replyOptionsOn && e.model.replyBlockShown)
        #expect(e.model.replyAnchor?.session == sid && e.model.replyOptionList(for: e.model.replyAnchor!).count == 3)
        e.model.voiceState = .speaking
        #expect(!e.model.replyBlockShown, "appears when the anchor has been spoken")
        e.model.voiceState = .recording
        #expect(!e.model.replyBlockShown, "hides when the learner's next turn starts")
        e.model.voiceState = .idle
        e.model.thinking = true
        #expect(!e.model.replyBlockShown)
        e.model.thinking = false
        #expect(e.model.replyBlockShown, "a failed turn brings it back as it was")
    }

    @Test func notOfferedInToneEndedAndTeacherSessions() async throws {
        let e = try Env(); defer { e.clean() }
        e.services.toggleReplyOptions()
        var toned = SessionSettings(lang: .en, mode: .free, corrections: [.inline]); toned.tone = .strictTeacher
        try await e.session(toned)
        #expect(!e.model.replyOptionsOffered && !e.model.replyBlockShown)
        try await e.session(SessionSettings(lang: .en, mode: .free, corrections: [.inline], activity: .warmup(["c1"])))
        #expect(!e.model.replyOptionsOffered)
        let sid = try await e.session()
        #expect(e.model.replyOptionsOffered)
        _ = try await e.services.store.append(EventType.sessionEnded, session: sid)
        e.model.apply(await e.services.store.state)
        #expect(!e.model.replyOptionsOffered && !e.model.replyBlockShown)
    }

    @Test func onlyTheLatestModelMessageIsTheAnchor() async throws {
        let e = try Env(); defer { e.clean() }
        let sid = try await e.session()
        _ = try await e.services.store.append(EventType.messageCreated, session: sid, Payload.MessageCreated(role: .user, text: "I live in Berlin.", lang: .en))
        _ = try await e.services.store.append(EventType.messageCreated, session: sid,
            Payload.MessageCreated(role: .assistant, text: "Models are unavailable", lang: .ru, kind: .error))
        e.model.apply(await e.services.store.state)
        #expect(e.model.replyAnchor?.text == Self.anchorText, "a user line and an error are never the anchor")
    }

    @Test func revealRecordsEachOptionOnceAndShowAllRevealsTheRest() async throws {
        let e = try Env(); defer { e.clean() }
        let sid = try await e.session()
        e.switchOn()
        let mid = try #require(e.model.replyAnchor?.id)
        e.services.revealReply(1)
        e.services.revealReply(1)
        #expect(e.model.replyBlocks[mid]?.revealed == [1])
        await wait { e.model.services != nil }
        e.services.revealAllReplies()
        #expect(e.model.replyBlocks[mid]?.revealed == [0, 1, 2])
        var events: [Payload.ReplyRevealed] = []
        for _ in 0..<400 where events.count < 3 { events = await e.revealEvents(sid); try await Task.sleep(for: .milliseconds(5)) }
        #expect(events.map(\.index).sorted() == [0, 1, 2] && events.allSatisfy { $0.message == mid })
        #expect(e.calls.count == 0, "revealing sends nothing")
    }

    @Test func insertPutsTextInTheFieldAndSendsNothing() async throws {
        let e = try Env(); defer { e.clean() }
        let sid = try await e.session()
        e.switchOn()
        let opt = try #require(e.model.replyOptionList(for: e.model.replyAnchor!).first)
        e.services.insertReply(opt)
        #expect(e.model.draft == "I live in Berlin.")
        e.model.draft = "Well,"
        e.services.insertReply(opt)
        #expect(e.model.draft == "Well, I live in Berlin.")
        #expect(e.calls.count == 0)
        #expect(await e.services.store.state.messages[sid]?.count == 1, "nothing is sent automatically")
    }

    @Test func refreshReplacesTheOptionsAtMostTwiceAndTheCountIsPerAnchor() async throws {
        let e = try Env(); defer { e.clean() }
        try await e.session()
        e.switchOn()
        let mid = try #require(e.model.replyAnchor?.id)
        e.services.revealReply(0)
        for round in 1...2 {
            #expect(e.services.canRefreshReplies)
            e.services.refreshReplies()
            await wait { e.model.replyBlocks[mid]?.refreshes == round }
            #expect(e.model.replyOptionList(for: e.model.replyAnchor!).map(\.text) == ["Fresh one here.", "Another fresh answer."])
            #expect(e.model.replyBlocks[mid]?.revealed == [], "new options start hidden")
        }
        #expect(!e.services.canRefreshReplies, "two refreshes per anchor")
        e.services.refreshReplies()
        #expect(e.calls.count == 2, "one request per press, none after the limit")
    }

    @Test func refreshIsDisabledOfflineWithoutAKeyAndWhileATurnRuns() async throws {
        let e = try Env(); defer { e.clean() }
        try await e.session()
        e.switchOn()
        #expect(e.services.canRefreshReplies)
        e.model.thinking = true
        #expect(!e.services.canRefreshReplies)
        e.model.thinking = false
        e.model.networkUp = false; e.model.recomputeOnline()
        #expect(!e.services.canRefreshReplies)
        e.model.networkUp = true; e.model.hasKey = false; e.model.recomputeOnline()
        #expect(!e.services.canRefreshReplies)
    }

    @Test func aFailedRefreshShowsTextAndKeepsTheOptions() async throws {
        let e = try Env(fail: true); defer { e.clean() }
        try await e.session()
        e.switchOn()
        let mid = try #require(e.model.replyAnchor?.id)
        e.services.refreshReplies()
        await wait { e.model.replyBlocks[mid]?.error != nil }
        #expect(e.model.replyBlocks[mid]?.refreshes == 0 && e.model.replyBlocks[mid]?.options == nil)
        #expect(e.model.replyOptionList(for: e.model.replyAnchor!).count == 3)
        #expect(e.services.canRefreshReplies, "a failure does not use up a refresh")
    }

    @Test func aReopenedSessionDerivesTheOptionsFromTheRawTextAgain() async throws {
        let e = try Env(); defer { e.clean() }
        let sid = try await e.session()
        e.switchOn()
        let mid = try #require(e.model.replyAnchor?.id)
        e.services.revealReply(0)
        e.services.refreshReplies()
        await wait { e.model.replyBlocks[mid]?.refreshes == 1 }
        e.model.selectedSessionID = nil
        e.model.selectedSessionID = sid
        e.model.refreshSelection()
        #expect(e.model.replyBlocks.isEmpty)
        #expect(e.model.replyOptionList(for: e.model.replyAnchor!).first?.text == "I live in Berlin.")
    }

    @Test func theCollapsedStateAndTheSwitchStayOnThisMacOnly() async throws {
        let e = try Env(); defer { e.clean() }
        try await e.session()
        e.services.toggleReplyOptions()
        e.services.toggleReplyCollapsed()
        #expect(e.model.replyCollapsed && e.services.settings.replyOptionsCollapsed && e.services.settings.replyOptions)
        let reloaded = e.services.settingsStore.load()
        #expect(reloaded.replyOptionsCollapsed && reloaded.replyOptions)
        #expect(await e.services.store.allEvents().allSatisfy { $0.type != "settings.changed" })
    }
}
