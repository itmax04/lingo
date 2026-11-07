import Foundation
import Testing
@testable import LingoCore

/// Records only synthetic audio measurements. The first call can be held until explicitly released.
private actor ExamAudioRecognizer: SpeechRecognizer {
    let id = "exam-audio-fake"
    private var gate: CheckedContinuation<Void, Never>?
    private var holdFirst: Bool
    private var counts: [Int] = []
    private var peaks: [Float] = []
    private let texts: [String]
    init(_ texts: [String], holdFirst: Bool = false) { self.texts = texts; self.holdFirst = holdFirst }
    func measurements() -> (counts: [Int], peaks: [Float]) { (counts, peaks) }
    func release() { holdFirst = false; gate?.resume(); gate = nil }
    func transcribe(_ samples: [Float], candidates: [Lang], forced: Lang?, context: String?) async throws -> Transcription {
        let index = counts.count
        counts.append(samples.count); peaks.append(samples.map(abs).max() ?? 0)
        if index == 0, holdFirst { await withCheckedContinuation { gate = $0 } }
        // The second short utterance is Done; cumulative audio reproduces F-1 instead.
        let text = index < texts.count ? texts[index] : ""
        let result = text == "Fertig!" && samples.count > 32_000 ? "Präsentation. Fertig!" : text
        return Transcription(text: result, lang: candidates[0], audioSeconds: Double(samples.count) / 16_000, elapsedMs: 1)
    }
}

@MainActor @Suite struct ExamAudioRegressionTests {
    private func monologue(_ e: TurnControllerTests.Env, _ clock: ExamControllerTests.Clock,
                           kind: ExamKind = .goetheB1) async throws -> ExamController {
        let c = try await ExamVoiceTests().setup(e, clock: clock, kind: kind)
        await ExamVoiceTests().drain(e, c)
        if kind == .goetheB1 {
            c.advance(expected: .goethePrep); await ExamVoiceTests().drain(e, c)
            c.advance(expected: .goethe1)
        } else {
            c.advance(expected: .ielts1); await ExamVoiceTests().drain(e, c)
            c.advance(expected: .ieltsPrep)
        }
        await ExamVoiceTests().drain(e, c)
        e.tc.startContinuous()
        return c
    }

    private func waitForCalls(_ recognizer: ExamAudioRecognizer, _ count: Int) async {
        for _ in 0..<200 {
            if await recognizer.measurements().counts.count >= count { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(await recognizer.measurements().counts.count >= count)
    }

    @Test func continuousFragmentsDoNotResubmitEarlierAudioAndDoneReleases() async throws {
        let rec = ExamAudioRecognizer(["Präsentation.", "Fertig!"])
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let c = try await monologue(e, ExamControllerTests.Clock())
        defer { e.tc.stopVoice(cancelTurn: true) }
        await e.feed(1200, speech: true); await e.feed(1600, speech: false)
        await e.waitUntil { c.canCapture }
        await e.feed(800, speech: true); await e.feed(1600, speech: false)
        await e.waitUntil { c.run?.phase == .goethe3 }; await ExamVoiceTests().drain(e, c)
        let counts = await rec.measurements().counts
        #expect(counts.count == 2 && counts.allSatisfy { (11_200..<32_000).contains($0) })
        #expect(await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }.map(\.text) == ["Präsentation.", "Fertig!"])
        #expect(c.run?.phase == .goethe3 && e.log.all.count == 2)
    }

    @Test func deadlineDrainsClosedAndFlushedFragmentsInOrder() async throws {
        let rec = ExamAudioRecognizer(["Erster Teil.", "Zweiter Teil.", "Letzter Teil."], holdFirst: true)
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let clock = ExamControllerTests.Clock()
        let c = try await monologue(e, clock)
        defer { e.tc.stopVoice(cancelTurn: true) }
        await e.feed(1200, speech: true); await e.feed(2300, speech: false)
        await waitForCalls(rec, 1)
        await e.feed(800, speech: true); await e.feed(2300, speech: false)
        await e.feed(900, speech: true) // still open when the deadline flushes it
        clock.date.addTimeInterval(181); c.tick(); c.tick()
        #expect(await rec.measurements().counts.count == 1, "STT is serial")
        #expect(c.run?.phase == .goethe2 && e.log.all.count == 1)
        await rec.release()
        await e.waitUntil { c.run?.phase == .goethe3 }; await ExamVoiceTests().drain(e, c)
        #expect(await rec.measurements().counts.count == 3)
        #expect(await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }.map(\.text) == ["Erster Teil.", "Zweiter Teil.", "Letzter Teil."])
        #expect(e.log.all.count == 2 && ["Erster Teil.", "Zweiter Teil.", "Letzter Teil."].allSatisfy { e.log.all.last?.contains($0) == true })
    }

    @Test func normalPhaseDeadlineWaitsForQueueBeforePreparation() async throws {
        let rec = ExamAudioRecognizer(["First answer.", "Second answer."], holdFirst: true)
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let clock = ExamControllerTests.Clock()
        let c = try await ExamVoiceTests().setup(e, clock: clock, kind: .ielts)
        defer { e.tc.stopVoice(cancelTurn: true) }
        await ExamVoiceTests().drain(e, c)
        e.tc.startContinuous()
        await e.feed(1200, speech: true); await e.feed(2300, speech: false)
        await waitForCalls(rec, 1)
        await e.feed(800, speech: true); await e.feed(1600, speech: false)
        clock.date.addTimeInterval(301); c.tick()
        await rec.release()
        await e.waitUntil { c.run?.phase == .ieltsPrep }; await ExamVoiceTests().drain(e, c)
        #expect(await rec.measurements().counts.count == 2)
        #expect(await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }.map(\.text) == ["First answer.", "Second answer."])
        #expect(c.run?.phase == .ieltsPrep && e.sink.micMuted && e.log.all.count == 1)
    }

    @Test func queuedDoneIsRecognizedAfterSlowFirstFragment() async throws {
        let rec = ExamAudioRecognizer(["Präsentation.", "Fertig!"], holdFirst: true)
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let c = try await monologue(e, ExamControllerTests.Clock())
        defer { e.tc.stopVoice(cancelTurn: true) }
        await e.feed(1200, speech: true); await e.feed(2300, speech: false)
        await waitForCalls(rec, 1)
        await e.feed(800, speech: true); await e.feed(1600, speech: false)
        #expect(await rec.measurements().counts.count == 1)
        await rec.release()
        await e.waitUntil { c.run?.phase == .goethe3 }; await ExamVoiceTests().drain(e, c)
        #expect(await rec.measurements().counts.count == 2)
        #expect(c.run?.phase == .goethe3 && e.log.all.count == 2)
    }

    @Test func stopInvalidatesQueuedAudioAndLateRecognition() async throws {
        let rec = ExamAudioRecognizer(["Präsentation.", "Fertig!"], holdFirst: true)
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let c = try await monologue(e, ExamControllerTests.Clock())
        await e.feed(1200, speech: true); await e.feed(2300, speech: false)
        await waitForCalls(rec, 1)
        await e.feed(800, speech: true); await e.feed(1600, speech: false)
        e.tc.stopVoice(cancelTurn: true)
        await rec.release()
        // Join the synthetic recognizer's release and allow the canceled queue to unwind.
        try await Task.sleep(for: .milliseconds(100))
        #expect(await rec.measurements().counts.count == 1)
        #expect(await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }.isEmpty != false)
        #expect(e.log.all.count == 1 && e.sink.micMuted)
    }

    @Test(arguments: [65, 120, 180]) func longMonologueRetainsBeginningThroughDeadline(duration: Int) async throws {
        let rec = ExamAudioRecognizer(["Complete monologue."])
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let clock = ExamControllerTests.Clock()
        let kind: ExamKind = duration == 120 ? .ielts : .goetheB1
        let c = try await monologue(e, clock, kind: kind)
        defer { e.tc.stopVoice(cancelTurn: true) }
        // Deterministic continuous tone, with a louder first second to detect loss of its beginning.
        for frame in 0..<(duration * 50) {
            let amplitude: Float = frame < 50 ? 0.2 : 0.1
            let samples = (0..<320).map { i -> Float in
                let sample = frame * 320 + i
                let syllable = 0.55 + 0.45 * sin(Float(sample) / 16_000 * 2 * .pi * 4)
                return amplitude * syllable * sin(Float(sample) * 2 * .pi * 220 / 16_000)
            }
            e.tc.feed(samples)
            if frame % 50 == 0 { await Task.yield() }
        }
        #expect(e.log.all.count == 1, "model requests remain held")
        clock.date.addTimeInterval(181); c.tick()
        await e.waitUntil { c.monologueReleased || c.run?.phase == .goethe3 }
        await ExamVoiceTests().drain(e, c)
        let measurements = await rec.measurements()
        #expect(measurements.counts.count == 1)
        #expect(abs(Double(measurements.counts.first ?? 0) / 16_000 - Double(duration)) < 0.3)
        #expect((measurements.peaks.first ?? 0) > 0.19, "the first second survives")
        #expect(e.log.all.count == 2)
        #expect(await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }.map(\.text) == ["Complete monologue."])
    }

    /// F-2 voice path: "that's all" ends the session (R-22) in an ordinary part and in a held monologue; it is not an answer.
    @Test(arguments: [false, true]) func spokenFinishCommandEndsTheExamInsteadOfAnswering(monologuePart: Bool) async throws {
        let rec = ExamAudioRecognizer(["That's all."])
        let e = try await TurnControllerTests().env(texts: [], recognizer: rec, requests: CallLog())
        let clock = ExamControllerTests.Clock()
        let c: ExamController
        if monologuePart { c = try await monologue(e, clock) } else {
            c = try await ExamVoiceTests().setup(e, clock: clock, kind: .ielts)
            await ExamVoiceTests().drain(e, c)
            e.tc.startContinuous()
        }
        defer { e.tc.stopVoice(cancelTurn: true) }
        var finished: String?
        e.tc.onFinishCommand = { finished = $0 }
        let phase = c.run?.phase, calls = e.log.all.count
        await e.feed(1200, speech: true); await e.feed(1600, speech: false)
        await e.waitUntil { finished != nil }
        #expect(finished == c.sessionID && finished != nil)
        #expect(await e.store.state.messages[c.sessionID!]?.filter { $0.role == .user }.map(\.text) == ["That's all."])
        #expect(!c.canCapture && !c.busy && e.sink.micMuted)
        clock.date.addTimeInterval(400); c.tick(); c.tick()
        try await Task.sleep(for: .milliseconds(50))
        #expect(c.run?.phase == phase && e.log.all.count == calls, "no release, transition or examiner reply after Finish")
    }

    @Test func doneWordsAreNotFinishCommands() {
        for done in ["Fertig!", "done", "Finished."] { #expect(ExamRun.isDoneUtterance(done) && !ExamRun.isFinishCommand(done)) }
        for finish in ["That's all.", "das war's", "на этом всё"] { #expect(ExamRun.isFinishCommand(finish)) }
        #expect(!ExamRun.isFinishCommand("I have finished my presentation."))
    }
}
