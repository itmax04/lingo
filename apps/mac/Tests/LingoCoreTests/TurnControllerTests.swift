import Foundation
import Testing
@testable import LingoCore

/// Fake speech output: "speaks" until the test calls `finish()`.
@MainActor
final class FakeSink: SpeechSink {
    var spoken: [(String, Float, Double)] = []
    var playing = false
    var stops = 0
    var stopTimes: [Double] = []
    var micMuted = false
    var isSpeaking: Bool { playing }
    /// The first part queued since the last stop: "playback" stops 4 characters into it.
    var currentTag: Int?
    func speak(_ text: String, lang: Lang, voiceID: String?, rate: Float, pauseAfter: Double, tag: Int) {
        spoken.append((text, rate, pauseAfter))
        if currentTag == nil { currentTag = tag }
        playing = true
    }
    func stopSpeaking() -> (tag: Int, charOffset: Int)? {
        guard playing else { return nil }
        playing = false
        stops += 1
        stopTimes.append(MetricsRecorder.now())
        defer { currentTag = nil }
        return (currentTag ?? 1, 4)
    }
    func finish() { playing = false; currentTag = nil }
}

/// Recognition returns the given texts in turn.
final class FakeRecognizer: SpeechRecognizer, @unchecked Sendable {
    let id = "fake"
    private let lock = NSLock()
    private var texts: [String]
    var delay: Double
    init(_ texts: [String], delay: Double = 0) { self.texts = texts; self.delay = delay }
    func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription {
        if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
        let t = lock.withLock { texts.isEmpty ? "" : texts.removeFirst() }
        return Transcription(text: t, lang: candidates[0], audioSeconds: Double(samples.count) / 16_000, elapsedMs: 1)
    }
}

/// Audio: speech — a tone with a syllable envelope, silence — faint noise. Fed in 20 ms blocks.
func audio(_ ms: Int, speech: Bool, phase: inout Int) -> [Float] {
    var rng = SystemRandomNumberGenerator()
    return (0..<(ms * 16)).map { i in
        let s = phase + i
        let noise = Float.random(in: -1...1, using: &rng) * 0.0025
        guard speech else { return noise }
        let syll = 0.55 + 0.45 * sin(Float(s) / 16_000 * 2 * .pi * 4)
        return 0.1 * syll * sin(Float(s) / 16_000 * 2 * .pi * 220) + noise
    }
}

@MainActor
@Suite struct TurnControllerTests {
    @MainActor
    final class Env {
        var holder: Holder?
        let tc: TurnController
        let sink: FakeSink
        let store: JournalStore
        let engine: DialogEngine
        let sid: String
        let log: CallLog
        var phase = 0
        init(tc: TurnController, sink: FakeSink, store: JournalStore, engine: DialogEngine, sid: String, log: CallLog) {
            self.tc = tc; self.sink = sink; self.store = store; self.engine = engine; self.sid = sid; self.log = log
        }
        func feed(_ ms: Int, speech: Bool) async {
            var left = ms
            while left > 0 {
                let n = min(20, left)
                tc.feed(audio(n, speech: speech, phase: &phase))
                phase += n * 16
                left -= n
                await Task.yield()
            }
        }
        func settle(_ s: Double = 0.3) async { try? await Task.sleep(for: .seconds(s)) }
        /// Waits until `condition` holds (at most `timeout` s): a slow CI runner needs longer than a fixed pause.
        func waitUntil(timeout: Double = 15, _ condition: () -> Bool) async {
            let end = Date().addingTimeInterval(timeout)
            while !condition(), Date() < end { try? await Task.sleep(for: .milliseconds(25)) }
        }
    }

    func env(texts: [String], recDelay: Double = 0, recognizer: (any SpeechRecognizer)? = nil, requests: CallLog? = nil, firstTokenTimeout: Double = 5, reply: @escaping @Sendable (String) -> MockProvider.Behavior = { _ in .text(["@say de: Schön! Wie lange schon?"]) }) async throws -> Env {
        let store = try JournalStore(base: tempDir("tc"), deviceName: "Mac", deviceID: "mac-tc")
        let log = requests ?? CallLog()
        let p: any LLMProvider
        if let requests { p = ExamProvider(requests: requests) }
        else { p = MockProvider(id: .groq, behavior: { _, _ in reply("") }, calls: log) }
        let llm = LLMSettings(keys: [KeyRecord(id: "k", provider: .groq, last4: "0000")], chain: [ChainEntry(provider: .groq, model: "m")], firstTokenTimeout: firstTokenTimeout)
        let secrets = InMemorySecretStore(["k": "synthetic"])
        let engine = DialogEngine(store: store) { ChainFactory.chain(settings: llm, secrets: secrets, health: ProviderHealth(), providers: [.groq: p]) }
        let sid = try await engine.createSession(SessionSettings(lang: .de, mode: .free, topic: "Wohnort", corrections: [.inline]))
        let sink = FakeSink()
        let holder = Holder()
        let tc = TurnController(engine: engine, recognizer: recognizer ?? FakeRecognizer(texts, delay: recDelay), sink: sink, metrics: nil, voice: VoiceSettings()) {
            holder.ctx
        }
        let e = Env(tc: tc, sink: sink, store: store, engine: engine, sid: sid, log: log)
        let st = await store.state
        holder.ctx = TurnController.Context(session: st.sessions[sid]!, lastAssistant: st.messages[sid]?.last { $0.role == .assistant }, lastUser: nil, phrases: [])
        holder.refresh = { [store] in
            let st = await store.state
            holder.ctx = TurnController.Context(session: st.sessions[sid]!, lastAssistant: st.messages[sid]?.last { $0.role == .assistant && $0.kind == .normal },
                                                lastUser: nil, phrases: [])
        }
        e.holder = holder
        await e.feed(1000, speech: false) // the VAD learns the noise
        return e
    }

    @Test func pushToTalkTurn() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg."])
        e.tc.pushDown()
        await e.feed(1200, speech: true)
        e.tc.pushUp()
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?" }
        #expect(e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?")
        #expect(e.tc.state == .speaking)
        e.sink.finish()
        await e.waitUntil { e.tc.state == .idle }
        #expect(e.tc.state == .idle)
        let msgs = await e.store.state.messages[e.sid]!
        #expect(msgs.map(\.role) == [.user, .assistant] && msgs[0].text == "Ich wohne in Hamburg.")
    }

    @Test func stoppingAReplayNeverMarksTheReplyInterrupted() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg."])
        e.tc.startContinuous()
        await e.feed(1200, speech: true)
        await e.feed(1600, speech: false)
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?" }
        e.sink.finish()  // the reply was heard in full
        await e.waitUntil { e.tc.state == .listening }
        let reply = try #require(await e.store.state.messages[e.sid]?.first { $0.role == .assistant })
        e.tc.replay(reply)  // a click on the bubble, then the learner speaks over the replay
        #expect(e.sink.isSpeaking)
        var fed = 0
        while e.sink.isSpeaking && fed < 1000 { await e.feed(20, speech: true); fed += 20 }
        await e.settle(0.3)
        #expect(await e.store.state.messages[e.sid]?.first { $0.role == .assistant }?.interruptedAt == nil)
    }

    @Test func interruptionOffsetCountsCharacters() {
        // "👍🏽" is 4 UTF-16 units but one Character; the reader cuts `spokenText` by Characters.
        let parts = [(tag: 1, text: "👍🏽 Yes!"), (tag: 2, text: "Go on.")]
        #expect(TurnController.interruptionOffset(parts: parts, stopTag: 1, utf16Offset: 5) == 2)  // after "👍🏽 "
        #expect(TurnController.interruptionOffset(parts: parts, stopTag: 2, utf16Offset: 3) == 10)  // "👍🏽 Yes! " (7) + "Go " (3)
        let spoken = parts.map(\.text).joined(separator: " ")
        #expect(String(spoken.prefix(10)) == "👍🏽 Yes! Go ")
        #expect(TurnController.interruptionOffset(parts: parts, stopTag: 9, utf16Offset: 1) == 14)  // unknown tag: the whole text plus separators
        // Inside a surrogate pair or a flag: round down to a whole Character, never past the part.
        #expect([0, 1, 2, 3, 4].map { TurnController.interruptionOffset(parts: parts, stopTag: 1, utf16Offset: $0) } == [0, 0, 0, 0, 1])
        #expect(TurnController.interruptionOffset(parts: [(tag: 1, text: "🇩🇪 ok")], stopTag: 1, utf16Offset: 3) == 0)
    }

    @Test func bargeInStopsWithinHalfSecondAndMarksInterrupted() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg.", "Seit zwei Jahren."])
        e.tc.startContinuous()
        await e.feed(1200, speech: true)
        await e.feed(1600, speech: false)
        // The whole reply must be written (and spoken) before the barge-in, so wait for its last sentence, not only for the first sound.
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?" }
        await e.settle(0.1)
        #expect(e.sink.isSpeaking)
        // The user barges in: the time from speech start to speech stop is measured in audio (samples), not by the test clock.
        var fedMs = 0
        while e.sink.isSpeaking && fedMs < 1000 { await e.feed(20, speech: true); fedMs += 20 }
        #expect(e.sink.stops == 1)
        #expect(fedMs <= 500, "stopped after \(fedMs) ms of speech")
        await e.feed(800, speech: true)
        await e.feed(1600, speech: false)
        await e.settle(0.5)
        let st = await e.store.state
        let first = st.messages[e.sid]!.first { $0.role == .assistant }!
        #expect(first.interruptedAt == 4)
        #expect(st.messages[e.sid]!.filter { $0.role == .user }.count == 2)
    }

    @Test func s05MergeCancelsAndCombines() async throws {
        // The first reply is delayed (slower recognition), the addition arrives within G → merge.
        // The first model request stays pending until the merge cancels it (it never answers by itself), so the addition always
        // arrives before the assistant starts speaking, however slow the machine is. The timeout is the maximum, so it cannot fire first.
        let calls = CallLog()
        let e = try await env(texts: ["Am Wochenende gehe", "spazieren"], recDelay: 0.05, firstTokenTimeout: 15, reply: { _ in
            calls.add("x")
            return calls.all.count == 1 ? .hang : .text(["@say de: Schön! Wohin gehen Sie spazieren?"])
        })
        await e.holder?.refresh?()
        e.tc.startContinuous()
        await e.feed(1300, speech: true)
        await e.feed(1550, speech: false)   // > T: the first utterance is over, the turn has started
        await e.settle(0.2)                 // the request is sent and waiting for a reply
        await e.feed(600, speech: true)     // the addition after ~1.55 s ≤ G (by audio)
        await e.feed(1600, speech: false)
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wohin gehen Sie spazieren?" }
        await e.settle(0.3)                 // a stray reply of the cancelled request would show up here
        let msgs = await e.store.state.messages[e.sid]!
        let users = msgs.filter { $0.role == .user }
        #expect(users.count == 1)
        #expect(users.first?.text == "Am Wochenende gehe spazieren")
        let assistants = msgs.filter { $0.role == .assistant }
        #expect(assistants.map(\.spokenText) == ["Schön! Wohin gehen Sie spazieren?"], "the first request is cancelled, one reply")
    }

    @Test func repeatIsLocalAndFast() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg.", "nochmal bitte"])
        e.tc.pushDown(); await e.feed(1000, speech: true); e.tc.pushUp()
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?" }  // the whole first reply, however slow
        e.sink.finish()
        await e.settle(0.2)
        await e.holder?.refresh?()
        let callsBefore = e.log.all.count
        e.sink.spoken = []
        e.tc.pushDown(); await e.feed(800, speech: true)
        e.tc.pushUp()
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?" }
        await e.settle(0.2)                 // a model reply or a second playback would show up here
        #expect(e.log.all.count == callsBefore, "the model is not called")
        #expect(e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?")
    }

    @Test func slowerSplitsAndSlowsDown() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg.", "langsamer", "langsamer"], reply: { _ in .text(["@say de: Wie lange wohnen Sie schon in Hamburg, und gefällt es Ihnen?"]) })
        e.tc.pushDown(); await e.feed(1000, speech: true); e.tc.pushUp()
        await e.waitUntil { e.sink.spoken.last?.0.hasSuffix("Ihnen?") == true }  // the whole first reply, however slow
        e.sink.finish(); await e.settle(0.2)
        await e.holder?.refresh?()
        e.sink.spoken = []
        e.tc.pushDown(); await e.feed(800, speech: true); e.tc.pushUp(); await e.waitUntil { e.sink.spoken.count >= 2 }
        let first = e.sink.spoken
        #expect(first.count >= 2 && first.allSatisfy { $0.2 == 0.6 })
        e.sink.finish(); await e.settle(0.2)
        e.sink.spoken = []
        e.tc.pushDown(); await e.feed(800, speech: true); e.tc.pushUp(); await e.waitUntil { !e.sink.spoken.isEmpty }
        #expect(e.sink.spoken.first!.1 < first.first!.1, "the second time is slower (×0.6)")
    }

    @Test func escapeStopsSpeech() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg."])
        e.tc.pushDown(); await e.feed(1000, speech: true); e.tc.pushUp()
        await e.waitUntil { e.sink.isSpeaking }
        #expect(e.sink.isSpeaking)
        e.tc.cancel()
        #expect(!e.sink.isSpeaking && e.tc.state == .idle)
    }
}

/// Context for TurnController in tests.
@MainActor
final class Holder {
    var ctx: TurnController.Context?
    var refresh: (() async -> Void)?
}


extension TurnControllerTests {
    @Test func pushToTalkEndsByItselfAfterPause() async throws {
        let e = try await env(texts: ["Ich wohne in Hamburg."])
        e.tc.pushDown()
        await e.feed(1200, speech: true)
        await e.feed(1700, speech: false)   // without a second press
        await e.waitUntil { e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?" }
        #expect(e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?")
    }
}

@MainActor @Suite struct FinishCancelsTheTurnTests {
    /// "Finish" must stop a reply that is still being generated; nothing may be spoken afterwards.
    @Test func finishCancelsAReplyThatIsStillBeingGenerated() async throws {
        let h = TurnControllerTests()
        let e = try await h.env(texts: ["Ich wohne in Hamburg."], reply: { _ in .delayed(0.8, ["@say de: Schön! Wie lange schon?"]) })
        e.tc.pushDown()
        await e.feed(1200, speech: true)
        e.tc.pushUp()
        await e.settle(0.2)
        #expect(e.tc.state == .thinking)
        e.tc.stopVoice(cancelTurn: true)
        await e.settle(1.2)
        #expect(e.sink.spoken.isEmpty)
        #expect(e.tc.state == .idle)
    }

    /// Without `cancelTurn` (switching continuous mode off) the running turn still finishes: the old behaviour is kept.
    @Test func switchingContinuousModeOffKeepsTheRunningTurn() async throws {
        let h = TurnControllerTests()
        let e = try await h.env(texts: ["Ich wohne in Hamburg."], reply: { _ in .delayed(0.5, ["@say de: Schön! Wie lange schon?"]) })
        e.tc.pushDown()
        await e.feed(1200, speech: true)
        e.tc.pushUp()
        await e.settle(0.2)
        e.tc.stopVoice()
        await e.settle(1.0)
        #expect(e.sink.spoken.map(\.0).joined(separator: " ") == "Schön! Wie lange schon?")
    }
}

@MainActor @Suite struct VoiceFinishTests {
    /// "That's all" by voice (R-22): the line is saved, the model is NOT asked for a reply (the app says its own goodbye and ends the session).
    @Test func finishCommandByVoiceSavesTheLineSkipsTheModelAndEndsTheSession() async throws {
        let h = TurnControllerTests()
        let e = try await h.env(texts: ["That's all."], reply: { _ in .text(["@say de: this must never be requested"]) })
        var endedSession: String?
        e.tc.onFinishCommand = { endedSession = $0 }
        e.tc.pushDown()
        await e.feed(1200, speech: true)
        e.tc.pushUp()
        await e.waitUntil { endedSession != nil }
        await e.settle(0.1)
        #expect(endedSession == e.sid)
        #expect(e.log.all.isEmpty)           // no model call
        #expect(e.sink.spoken.isEmpty)       // nothing spoken by the turn itself
        let msgs = await e.store.state.messages[e.sid] ?? []
        #expect(msgs.map(\.role) == [.user] && msgs[0].text == "That's all.")
    }

    @Test func anOrdinaryUtteranceDoesNotEndTheSession() async throws {
        let h = TurnControllerTests()
        let e = try await h.env(texts: ["Ich wohne in Hamburg."])
        var finished = false
        e.tc.onFinishCommand = { _ in finished = true }
        e.tc.pushDown()
        await e.feed(1200, speech: true)
        e.tc.pushUp()
        await e.settle()
        e.sink.finish()
        await e.settle(0.3)
        #expect(!finished)
    }
}

@MainActor @Suite struct EndedSessionVoiceTests {
    /// Voice still on while a finished session is selected: the utterance is dropped (no model call, nothing written), voice stops.
    @Test func anUtteranceForAFinishedSessionIsDroppedAndVoiceStops() async throws {
        let h = TurnControllerTests()
        let e = try await h.env(texts: ["Ich wohne in Hamburg."])
        var s = try #require(e.holder?.ctx?.session)
        s.state = .ended
        e.holder?.ctx = TurnController.Context(session: s, lastAssistant: nil, lastUser: nil, phrases: [])
        var told = false
        e.tc.onEndedSession = { told = true }
        e.tc.startContinuous()
        await e.feed(1200, speech: true)
        await e.feed(1700, speech: false)
        await e.waitUntil { told }
        #expect(told)
        #expect(e.log.all.isEmpty)
        #expect(e.tc.mode == .pushToTalk)
        #expect((await e.store.state.messages[e.sid] ?? []).isEmpty)
    }
}
