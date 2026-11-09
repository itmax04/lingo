import Testing
@testable import LingoCore

/// H-05: `VoiceIO.stopSpeaking()` read `lastRenderTime` on a player node that was not attached to an engine
/// (before start, or after `stop()` replaced the node). That raises an NSException, which Swift cannot catch.
/// A crash of the test process is the failure mode of these tests. No microphone is needed: the engine is never started.
@Suite struct VoiceIOStopTests {
    @Test func stopSpeakingBeforeStartDoesNotTouchDetachedPlayer() {
        let io = VoiceIO()
        #expect(io.stopSpeaking() == nil)
        #expect(!io.isSpeaking)
    }

    @Test func stopSpeakingAfterStopDoesNotTouchDetachedPlayer() {
        let io = VoiceIO()
        io.stop()
        #expect(io.stopSpeaking() == nil)
        io.stop()
        #expect(io.stopSpeaking() == nil)
    }
}
