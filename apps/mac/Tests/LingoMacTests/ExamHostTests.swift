import Foundation
import LingoCore
import Testing
@testable import LingoMac

@MainActor @Suite(.serialized) struct ExamHostTests {
    final class Sink: SpeechSink {
        var isSpeaking = false
        var micMuted = false
        func speak(_ text: String, lang: Lang, voiceID: String?, rate: Float, pauseAfter: Double, tag: Int) { isSpeaking = true }
        func stopSpeaking() -> (tag: Int, charOffset: Int)? { isSpeaking = false; return nil }
    }
    struct Recognizer: SpeechRecognizer {
        let id = "synthetic"
        func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription {
            Transcription(text: "synthetic", lang: .de, audioSeconds: Double(samples.count) / 16000, elapsedMs: 0)
        }
    }
    struct Provider: LLMProvider {
        let id = ProviderID.groq
        func stream(_ request: LLMRequest, model: String, key: String) -> AsyncThrowingStream<LLMEvent, Error> {
            AsyncThrowingStream { continuation in
                continuation.yield(.text("@say en: Tell me about your hometown."))
                continuation.finish()
            }
        }
    }
    @MainActor final class Env {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("lingo-exam-host-" + UUID().uuidString)
        let suite = "lingo-exam-host-" + UUID().uuidString
        let model = AppModel()
        let sink = Sink()
        let services: AppServices
        let tc: TurnController
        init() throws {
            let defaults = try #require(UserDefaults(suiteName: suite))
            let settings = LLMSettings(keys: [KeyRecord(id: "fixture", provider: .groq, last4: "0000")],
                                       chain: [ChainEntry(provider: .groq, model: "mock")])
            services = try AppServices(model: model, settingsStore: SettingsStore(defaults: defaults),
                secrets: InMemorySecretStore(), base: base, chain: {
                    ChainFactory.chain(settings: settings, secrets: InMemorySecretStore(["fixture": "synthetic"]),
                                       health: ProviderHealth(), providers: [.groq: Provider()])
                })
            let m = model
            tc = TurnController(engine: services.engine, recognizer: Recognizer(), sink: sink, metrics: nil, voice: VoiceSettings()) {
                guard let s = m.selectedSession else { return nil }
                return TurnController.Context(session: s, lastAssistant: nil, lastUser: nil, phrases: [])
            }
            services.turn = tc
            model.services = services
            model.hasKey = true
        }
        func clean() {
            services.stopExam()
            try? FileManager.default.removeItem(at: base)
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
    }
    func wait(_ condition: () -> Bool) async {
        for _ in 0..<400 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }

    @Test func startGuardsDoubleClicksAndPreparationCannotCaptureOrType() async throws {
        let e = try Env(); defer { e.clean() }
        e.services.startExam(.goetheB1); e.services.startExam(.ielts)
        await wait { !e.model.startingExam }
        #expect(await e.services.store.state.sessions.count == 1)
        #expect(e.tc.exam === e.services.exam)
        #expect(e.model.examRun?.phase == .goethePrep && e.sink.micMuted)
        #expect(!e.model.disabledReason.isEmpty && !e.model.canContinue)
        e.model.draft = "not captured"
        e.services.sendText()
        e.tc.pushDown()
        #expect(e.model.draft == "not captured" && e.tc.state == .idle)
        e.sink.micMuted = false // VoiceIO start/recovery and phrase idle restore the same gate.
        e.services.restoreExamMicrophone(on: e.sink)
        #expect(e.sink.micMuted)
        #expect(await e.services.store.state.messages[e.model.selectedSessionID!] == nil)
    }

    @Test func hostWaitsForSpeechThenQueuesOneTransitionAndHoldsTypedFragments() async throws {
        let e = try Env(); defer { e.clean() }
        e.services.startExam(.goetheB1); await wait { !e.model.startingExam }
        let c = try #require(e.services.exam)
        c.advance(expected: .goethePrep)
        await wait { e.sink.isSpeaking }
        #expect(c.busy && e.model.examBusy)
        c.advance(expected: .goethe1); c.advance(expected: .goethe1)
        #expect(c.run?.phase == .goethe1)
        e.sink.isSpeaking = false
        await wait { c.run?.phase == .goethe2 && !c.busy }
        e.model.draft = "Ich fahre oft Fahrrad."
        e.services.sendText()
        e.model.draft = "A second fragment still being typed."
        e.services.sendText()
        #expect(e.model.draft == "A second fragment still being typed.")
        let sid = try #require(c.sessionID)
        await wait { c.canCapture }
        #expect(await e.services.store.state.messages[sid]?.filter { $0.role == .user }.count == 1)
        #expect(c.run?.phase == .goethe2 && !c.busy)
        e.services.finishSession(sid)
        await wait { !e.services.ending }
        e.model.apply(await e.services.store.state)
        #expect(e.model.selectedSession?.state == .ended && e.model.examReadOnly)
        #expect(e.tc.exam == nil && e.sink.micMuted && !e.sink.isSpeaking)
    }

    @Test(arguments: [false, true]) func leavingOrDeletingInvalidatesLiveExamAndCannotResume(delete: Bool) async throws {
        let e = try Env(); defer { e.clean() }
        e.services.startExam(.goetheB1); await wait { !e.model.startingExam }
        let c = try #require(e.services.exam), sid = try #require(c.sessionID)
        if delete { e.services.delete(sid) } else { e.model.selectedSessionID = nil }
        #expect(e.services.exam == nil && e.tc.exam == nil && e.sink.micMuted)
        c.advance(expected: .goethePrep)
        #expect(c.run?.phase == .goethePrep)
        e.model.apply(await e.services.store.state)
        e.model.selectedSessionID = sid
        #expect(e.model.examReadOnly && !e.model.canContinue && !e.model.disabledReason.isEmpty)
        e.services.continueSession()
        #expect(e.services.exam == nil)
    }

    @Test func finishDuringOpeningSpeechCancelsAndEndsWithoutResume() async throws {
        let e = try Env(); defer { e.clean() }
        e.services.startExam(.ielts)
        await wait { !e.model.startingExam && e.sink.isSpeaking }
        let sid = try #require(e.services.exam?.sessionID)
        e.services.finishSession(sid); e.services.finishSession(sid)
        await wait { !e.services.ending }
        e.model.apply(await e.services.store.state)
        #expect(e.model.selectedSession?.state == .ended)
        #expect(e.model.examReadOnly && !e.sink.isSpeaking && e.sink.micMuted)
        #expect(e.services.exam == nil && e.services.turn == nil)
        #expect(await e.services.store.state.messages[sid]?.filter { $0.kind == .summary }.isEmpty == true)
    }

    @Test func naturalEndLeavesOnlyTranscriptAndNoController() async throws {
        let e = try Env(); defer { e.clean() }
        e.services.startExam(.goetheB1); await wait { !e.model.startingExam }
        let c = try #require(e.services.exam)
        for phase in [ExamPhase.goethePrep, .goethe1, .goethe2, .goethe3] {
            c.advance(expected: phase)
            for _ in 0..<400 {
                e.sink.isSpeaking = false
                if !c.busy { break }
                try await Task.sleep(for: .milliseconds(5))
            }
            #expect(!c.busy)
        }
        e.model.apply(await e.services.store.state)
        #expect(e.model.selectedSession?.state == .ended && e.model.examReadOnly)
        #expect(e.services.exam == nil && e.tc.exam == nil && e.sink.micMuted)
    }

    @Test func selectionBeforeStartTaskRunsCreatesNoExam() async throws {
        let e = try Env(); defer { e.clean() }
        e.services.startExam(.goetheB1)
        e.model.selectedSessionID = "other"
        await Task.yield()
        #expect(await e.services.store.state.sessions.isEmpty)
        #expect(e.services.exam == nil && !e.model.startingExam)
        e.sink.isSpeaking = true; e.sink.micMuted = true
        e.services.restoreExamMicrophone(on: e.sink)
        #expect(e.sink.micMuted)
        e.sink.isSpeaking = false
        e.services.restoreExamMicrophone(on: e.sink)
        #expect(!e.sink.micMuted)
    }
}
