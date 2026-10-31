import Foundation

/// Only accepted recovery attempts consume the budget. Watchdog polls must not extend a lockout.
struct AudioRestartLimiter {
    let maximumAttempts: Int
    let window: Double
    private(set) var attempts: [Double] = []

    init(maximumAttempts: Int = 5, window: Double = 60) {
        self.maximumAttempts = maximumAttempts
        self.window = window
    }

    mutating func allow(at now: Double) -> Bool {
        attempts.removeAll { now - $0 >= window }
        guard attempts.count < maximumAttempts else { return false }
        attempts.append(now)
        return true
    }
}
