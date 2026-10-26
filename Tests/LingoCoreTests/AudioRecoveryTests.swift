import Testing
@testable import LingoCore

@Suite struct AudioRecoveryTests {
    @Test func continuousWatchdogPollingDoesNotExtendCooldown() {
        var limiter = AudioRestartLimiter()
        var accepted: [Int] = []
        for second in 0..<181 {
            if limiter.allow(at: Double(second)) { accepted.append(second) }
        }
        #expect(Array(accepted.prefix(10)) == [0, 1, 2, 3, 4, 60, 61, 62, 63, 64])
        #expect(accepted.contains(120))
        #expect(accepted.contains(180))
    }

    @Test func rejectedAttemptsDoNotConsumeBudget() {
        var limiter = AudioRestartLimiter(maximumAttempts: 2, window: 10)
        let first = limiter.allow(at: 0)
        let second = limiter.allow(at: 1)
        #expect(first && second)
        for second in 2..<10 {
            let allowed = limiter.allow(at: Double(second))
            #expect(!allowed)
        }
        #expect(limiter.attempts == [0, 1])
        let afterWindow = limiter.allow(at: 10)
        let afterSecond = limiter.allow(at: 11)
        #expect(afterWindow && afterSecond)
    }
}
