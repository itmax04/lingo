import Foundation
import Testing
@testable import LingoCore

struct ExamProvider: LLMProvider {
    let id = ProviderID.groq
    let requests: CallLog
    func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error> {
        requests.add(request.messages.map(\.text).joined(separator: "\n"))
        return MockProvider(id: id, behavior: { _, _ in .text(["@say en: Why is that important?"]) }, calls: CallLog())
            .stream(request, model: model, key: key)
    }
}

@MainActor @Suite struct ExamControllerTests {
    final class Clock { var date = Date(timeIntervalSince1970: 1_800_000_000) }
    final class Env {
        let store: JournalStore
        var engine: DialogEngine!
        let sink = FakeSink()
        let clock = Clock()
        let requests = CallLog()
        var events: [TurnEvent] = []
        var holdSpeech = false
        init() throws {
            store = try JournalStore(base: tempDir("exam-controller"), deviceName: "Synthetic", deviceID: "synthetic-exam")

        }
    }

    // A separate factory lets the consumer observe this environment without an initialization cycle.
    func env() throws -> (Env, ExamController) {
        let e = try Env()
        let p = ExamProvider(requests: e.requests)
        let settings = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")],
                                   chain: [ChainEntry(provider: .groq, model: "mock")])
        let engine = DialogEngine(store: e.store) {
            ChainFactory.chain(settings: settings, secrets: InMemorySecretStore(["k": "synthetic"]), health: ProviderHealth(), providers: [.groq: p])
        }
        e.engine = engine
        let c = ExamController(engine: engine, sink: e.sink, now: { e.clock.date }) { stream in
            for await event in stream { e.events.append(event) }
            while e.holdSpeech, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(5)) }
        }
        return (e, c)
    }
    func idle(_ c: ExamController) async {
        for _ in 0..<400 { if !c.busy { return }; try? await Task.sleep(for: .milliseconds(5)) }
        #expect(!c.busy)
    }
    func go(_ c: ExamController, _ phase: ExamPhase) async {
        c.advance(expected: phase); await idle(c)
    }

    @Test func goetheHoldsAllFragmentsAndReleasesOnceIntoPart3() async throws {
        let (e, c) = try env()
        let sid = try #require(try await c.start(.goetheB1, automaticTimer: false))
        #expect(e.sink.micMuted && e.requests.all.isEmpty)
        await c.submit("not captured", lang: .de)
        #expect((await e.store.state.messages[sid] ?? []).isEmpty)
        await go(c, .goethePrep)
        #expect(!e.sink.micMuted && e.requests.all.count == 1)
        await go(c, .goethe1)
        #expect(c.run?.phase == .goethe2 && e.requests.all.count == 1)
        await c.submit("Ich fahre oft Fahrrad.", lang: .de)
        await c.submit("Ich bin noch nicht fertig.", lang: .de)
        #expect(e.requests.all.count == 1)
        await c.submit("Fertig!", lang: .de)
        await idle(c)
        c.advance(expected: .goethe2); await idle(c)
        #expect(e.requests.all.count == 2 && c.run?.phase == .goethe3)
        let request = try #require(e.requests.all.last)
        #expect(request.contains("part: goethe_b1.3") && request.contains("Ich fahre oft Fahrrad.") && request.contains("Ich bin noch nicht fertig."))
        await go(c, .goethe3)
        #expect(c.run?.finished == true && e.sink.micMuted)
        #expect(await e.store.state.sessions[sid]?.state == .ended)
        #expect(await e.store.state.examParts[sid] == [.goethePrep, .goethe1, .goethe2, .goethe3])
        await e.engine.requestTopicPhrases(sid)
        await e.engine.finalizeEnded(sid)
        #expect(e.requests.all.count == 2, "no topic phrases, recap or summary")
        c.stop()
    }

    @Test func ieltsDeadlineWaitsForRecognitionThenOneFollowUp() async throws {
        let (e, c) = try env()
        let sid = try #require(try await c.start(.ielts, automaticTimer: false)); await idle(c)
        await go(c, .ielts1)
        #expect(e.sink.micMuted && c.run?.phase == .ieltsPrep)
        e.clock.date.addTimeInterval(60); c.tick(); await idle(c)
        #expect(!e.sink.micMuted && c.run?.phase == .ielts2)
        let token = try #require(c.beginCapture())
        e.clock.date.addTimeInterval(120)
        for _ in 0..<4 { c.tick() }
        #expect(e.requests.all.count == 1)
        await c.endCapture(token, text: "I remember this journey.", lang: .en); await idle(c)
        for _ in 0..<4 { c.tick(); c.advance(expected: .ielts2) }
        #expect(e.requests.all.count == 2 && c.run?.phase == .ielts2 && c.monologueReleased)
        #expect(e.requests.all.last?.contains("I remember this journey.") == true)
        #expect(e.requests.all.last?.contains("part: ielts.2") == true)
        await c.submit("Yes, I would go again.", lang: .en); await idle(c)
        #expect(e.requests.all.count == 3 && c.run?.phase == .ielts3)
        #expect(await e.store.state.examParts[sid] == [.ielts1, .ieltsPrep, .ielts2, .ielts3])
        c.stop()
    }

    @Test func deadlineWaitsForConsumerSpeechAndQueuesOnlyOneTransition() async throws {
        let (e, c) = try env(); e.holdSpeech = true
        _ = try await c.start(.ielts, automaticTimer: false)
        for _ in 0..<100 { if !e.requests.all.isEmpty { break }; await Task.yield() }
        e.clock.date.addTimeInterval(301)
        for _ in 0..<5 { c.tick() }
        #expect(c.run?.phase == .ielts1 && !e.sink.micMuted)
        e.holdSpeech = false; await idle(c)
        #expect(c.run?.phase == .ieltsPrep && e.sink.micMuted && e.requests.all.count == 1)
        c.stop()
    }

    @Test func normalTurnSavesBargeInWhileSpeechDrainsThenAnswersIt() async throws {
        let (e, c) = try env(); e.holdSpeech = true
        _ = try await c.start(.ielts, automaticTimer: false)
        for _ in 0..<100 { if !e.requests.all.isEmpty { break }; await Task.yield() }
        await c.submit("I live near a park.", lang: .en)
        #expect(e.requests.all.count == 1)
        e.holdSpeech = false; await idle(c)
        #expect(e.requests.all.count == 2)
        #expect(e.requests.all.last?.contains("I live near a park.") == true)
        c.stop()
    }

    @Test func doubleStartAndLateTranscriptAfterStop() async throws {
        let (e, c) = try env()
        async let first = c.start(.goetheB1, automaticTimer: false)
        async let second = c.start(.goetheB1, automaticTimer: false)
        _ = try await (first, second)
        #expect(await e.store.state.sessions.count == 1)
        await go(c, .goethePrep); await go(c, .goethe1)
        let token = try #require(c.beginCapture())
        c.advance(expected: .goethe2)
        c.stop()
        await c.endCapture(token, text: "late transcript", lang: .de)
        e.clock.date.addTimeInterval(999); c.tick(); await idle(c)
        #expect(e.requests.all.count == 1 && e.sink.micMuted)
        #expect(await e.store.state.examParts[c.sessionID!] == [.goethePrep, .goethe1, .goethe2])
    }

    @Test func stopCancelsPendingConsumerAndAutomaticTimer() async throws {
        let (e, c) = try env(); e.holdSpeech = true
        _ = try await c.start(.ielts)
        c.stop(); e.clock.date.addTimeInterval(999)
        try await Task.sleep(for: .milliseconds(1100))
        #expect(!c.busy && e.sink.micMuted && c.run?.phase == .ielts1)
        #expect(await e.store.state.examParts[c.sessionID!] == [.ielts1])
    }
}

@MainActor @Suite struct ExamVoiceTests {
    func setup(_ e: TurnControllerTests.Env, clock: ExamControllerTests.Clock, kind: ExamKind = .goetheB1) async throws -> ExamController {
        let c = ExamController(engine: e.engine, sink: e.sink, now: { clock.date }) { [weak tc = e.tc, store = e.store, holder = e.holder] stream in
            if let sid = tc?.exam?.sessionID, let session = await store.state.sessions[sid] {
                holder?.ctx = TurnController.Context(session: session, lastAssistant: nil, lastUser: nil, phrases: [])
            }
            await tc?.consumeExamReply(stream)
        }
        e.tc.exam = c
        let sid = try #require(try await c.start(kind, automaticTimer: false))
        let st = await e.store.state
        e.holder?.ctx = TurnController.Context(session: st.sessions[sid]!, lastAssistant: nil, lastUser: nil, phrases: [])
        return c
    }
    func drain(_ e: TurnControllerTests.Env, _ c: ExamController) async {
        for _ in 0..<200 {
            e.sink.finish()
            if !c.busy { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(!c.busy)
    }
    @Test func preparationBlocksAudioAndMonologueBypassesLocalCommandsAndMerging() async throws {
        let e = try await TurnControllerTests().env(texts: ["nochmal bitte", "Ich fahre Fahrrad.", "Fertig!"])
        let clock = ExamControllerTests.Clock()
        let c = try await setup(e, clock: clock)
        e.tc.startContinuous(); e.tc.pushDown()
        await e.feed(1200, speech: true); e.tc.pushUp()
        #expect(e.log.all.isEmpty && e.sink.micMuted)
        c.advance(expected: .goethePrep); await drain(e, c)
        c.advance(expected: .goethe1); await drain(e, c)
        for count in 1...3 {
            e.tc.pushDown(); await e.feed(1200, speech: true); e.tc.pushUp()
            for _ in 0..<100 {
                let msgs = await e.store.state.messages[c.sessionID!] ?? []
                if msgs.filter({ $0.role == .user }).count == count { break }
                try? await Task.sleep(for: .milliseconds(10))
            }
            if count < 3 {
                await e.waitUntil { c.canCapture }
                #expect(e.log.all.count == 1)
            }
        }
        await e.waitUntil { c.run?.phase == .goethe3 }
        await drain(e, c)
        #expect(e.log.all.count == 2 && c.run?.phase == .goethe3)
        let users = await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }
        #expect(users?.map(\.text) == ["nochmal bitte", "Ich fahre Fahrrad.", "Fertig!"])
        e.tc.stopVoice(cancelTurn: true)
    }
    @Test func deadlineFlushesContinuousSpeechAndWaitsForDelayedSTT() async throws {
        let e = try await TurnControllerTests().env(texts: ["Eine lange Präsentation."], recDelay: 0.15)
        let clock = ExamControllerTests.Clock()
        let c = try await setup(e, clock: clock)
        c.advance(expected: .goethePrep); await drain(e, c)
        c.advance(expected: .goethe1); await drain(e, c)
        e.tc.startContinuous()
        await e.feed(1200, speech: true)
        clock.date.addTimeInterval(241); c.tick(); c.tick()
        #expect(c.run?.phase == .goethe2 && e.log.all.count == 1)
        await e.waitUntil(timeout: 5) { c.run?.phase == .goethe3 }; await drain(e, c)
        #expect(c.run?.phase == .goethe3 && e.log.all.count == 2)
        #expect(await e.store.state.messages[c.sessionID!]?.contains { $0.text == "Eine lange Präsentation." } == true)
        e.tc.stopVoice(cancelTurn: true)
    }
}
