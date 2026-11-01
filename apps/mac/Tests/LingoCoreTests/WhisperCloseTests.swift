import Foundation
import Testing
@testable import LingoCore

/// Quitting frees whisper first (the crash on ⌘Q): the load registry and `close()`.
@Suite struct WhisperCloseTests {
    @Test func registryRefusesLoadsOnceTerminatingAndWaitsForRunningOnes() async throws {
        let r = WhisperEngine.Registry()
        #expect(r.beginLoad())
        let started = Date()
        Task.detached {
            try? await Task.sleep(for: .milliseconds(200))
            r.endLoad()
        }
        r.terminate(waitingUpTo: 5)
        #expect(Date().timeIntervalSince(started) >= 0.15)  // waited for the load in progress
        #expect(!r.beginLoad())
        // A load that never ends does not block the quit for longer than the limit.
        let stuck = WhisperEngine.Registry()
        #expect(stuck.beginLoad())
        let t0 = Date()
        stuck.terminate(waitingUpTo: 0.2)
        #expect(Date().timeIntervalSince(t0) < 2)
    }

    /// Needs the local model (not on CI).
    @Test(.enabled(if: ModelStore.macDefault.isInstalled(.largeV3TurboQ5)))
    func closeIsIdempotentAndLaterCallsThrow() throws {
        let w = try WhisperEngine(modelPath: ModelStore.macDefault.path(.largeV3TurboQ5).path)
        let tone = (0..<16_000).map { Float(0.2 * sin(2 * Double.pi * 440 * Double($0) / 16_000)) }
        _ = try w.transcribeSync(tone, candidates: [.en], forced: .en)
        w.close()
        w.close()
        #expect(throws: WhisperError.self) { try w.transcribeSync(tone, candidates: [.en], forced: .en) }
        #expect(throws: WhisperError.self) { try w.detectLanguage(tone, candidates: [.en, .de]) }
    }
}
