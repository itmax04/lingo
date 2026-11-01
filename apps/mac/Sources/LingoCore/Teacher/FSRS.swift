import Foundation

/// A review grade (LINGO-05 CR-02): again 1, hard 2, good 3, easy 4.
public enum CardRating: String, Codable, Sendable, Hashable, CaseIterable {
    case again, hard, good, easy
    public var grade: Int {
        switch self { case .again: 1; case .hard: 2; case .good: 3; case .easy: 4 }
    }
}

/// The schedule of one card (CR-03). `phase` and `step` follow the reference scheduler's states.
public struct CardState: Sendable, Hashable {
    public enum Phase: String, Sendable, Hashable { case learning, review, relearning }
    public var phase: Phase
    /// Index into the learning or relearning steps; nil in review.
    public var step: Int?
    public var stability: Double
    public var difficulty: Double
    public var lastReview: Date
    public var due: Date
    public var reviews: Int
    /// `again` ratings after the first review (CR-03).
    public var lapses: Int
}

/// FSRS-5 as in py-fsrs 5.1.3 (`Scheduler.review_card`, default parameters), ported without a dependency (LINGO-05 CR-03). The state
/// of a card is a pure function of its reviews in order, so every device computes the same schedule from the same journal.
/// No fuzzing: the schedule must be identical on every device.
public enum FSRS {
    public static let w: [Double] = [0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
                                     1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621]
    public static let decay = -0.5
    public static let factor = pow(0.9, 1 / decay) - 1
    static let day: TimeInterval = 86_400

    /// Scheduler settings besides the weights. `lingo` is what the app uses; `reference` is py-fsrs's default (for its published tests).
    public struct Profile: Sendable {
        public var retention: Double
        public var learningSteps: [TimeInterval]
        public var relearningSteps: [TimeInterval]
        public var maximumIntervalDays: Int
        /// One review per card per session and a daily queue, so no minute steps; intervals of at most a year.
        public static let lingo = Profile(retention: 0.9, learningSteps: [], relearningSteps: [], maximumIntervalDays: 365)
        public static let reference = Profile(retention: 0.9, learningSteps: [60, 600], relearningSteps: [600], maximumIntervalDays: 36_500)
    }

    static func clampD(_ d: Double) -> Double { min(10, max(1, d)) }
    static func initialStability(_ g: Int) -> Double { max(w[g - 1], 0.1) }
    static func initialDifficulty(_ g: Int) -> Double { clampD(w[4] - exp(w[5] * Double(g - 1)) + 1) }

    /// Whole days between two reviews, rounded down like Python's `timedelta.days`, on whole milliseconds (journal precision), so an
    /// exact multiple of a day never comes out one short.
    public static func elapsedDays(from: Date, to: Date) -> Int {
        let ms = Int64((to.timeIntervalSince1970 * 1000).rounded()) - Int64((from.timeIntervalSince1970 * 1000).rounded())
        let dayMs: Int64 = 86_400_000
        return Int(ms >= 0 ? ms / dayMs : -((-ms + dayMs - 1) / dayMs))
    }

    /// Retrievability after `days` whole days with stability `s`.
    public static func retrievability(days: Int, stability s: Double) -> Double {
        pow(1 + factor * Double(max(0, days)) / s, decay)
    }

    /// Interval in whole days for stability `s`: rounded half to even like Python's `round`, at least 1, at most the profile's maximum.
    public static func intervalDays(_ s: Double, profile: Profile = .lingo) -> Int {
        let raw = s / factor * (pow(profile.retention, 1 / decay) - 1)
        return min(profile.maximumIntervalDays, max(1, Int(raw.rounded(.toNearestOrEven))))
    }

    static func nextDifficulty(_ d: Double, _ g: Int) -> Double {
        let delta = -(w[6] * Double(g - 3))
        return clampD(w[7] * initialDifficulty(4) + (1 - w[7]) * (d + (10 - d) * delta / 9))
    }

    static func shortTermStability(_ s: Double, _ g: Int) -> Double { s * exp(w[17] * (Double(g - 3) + w[18])) }

    static func nextStability(d: Double, s: Double, r: Double, g: Int) -> Double {
        if g == 1 {
            let longTerm = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
            return min(longTerm, s / exp(w[17] * w[18]))
        }
        let hard = g == 2 ? w[15] : 1, easy = g == 4 ? w[16] : 1
        return s * (1 + exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1) * hard * easy)
    }

    /// The next state after a review at `at` (nil = a new card), in the reference order: stability from the old difficulty, then
    /// difficulty, then the interval from the phase and its steps.
    public static func review(_ state: CardState?, rating: CardRating, at: Date, profile: Profile = .lingo) -> CardState {
        let g = rating.grade
        let s: Double, d: Double
        if let st = state {
            let days = elapsedDays(from: st.lastReview, to: at)
            s = days < 1 ? shortTermStability(st.stability, g)
                : nextStability(d: st.difficulty, s: st.stability, r: retrievability(days: days, stability: st.stability), g: g)
            d = nextDifficulty(st.difficulty, g)
        } else {
            s = initialStability(g)
            d = initialDifficulty(g)
        }
        var phase = state?.phase ?? .learning
        var step: Int? = state.map(\.step) ?? 0
        func graduate() -> TimeInterval {
            phase = .review
            step = nil
            return Double(intervalDays(s, profile: profile)) * day
        }
        let interval: TimeInterval
        switch phase {
        case .learning, .relearning:
            let steps = phase == .learning ? profile.learningSteps : profile.relearningSteps
            let current = step ?? 0
            if steps.isEmpty || (current >= steps.count && g > 1) {
                interval = graduate()
            } else {
                switch rating {
                case .again:
                    step = 0
                    interval = steps[0]
                case .hard:
                    interval = current == 0 ? (steps.count == 1 ? steps[0] * 1.5 : (steps[0] + steps[1]) / 2) : steps[current]
                case .good:
                    if current + 1 == steps.count { interval = graduate() } else { step = current + 1; interval = steps[current + 1] }
                case .easy:
                    interval = graduate()
                }
            }
        case .review:
            if rating == .again && !profile.relearningSteps.isEmpty {
                phase = .relearning
                step = 0
                interval = profile.relearningSteps[0]
            } else {
                interval = graduate()
            }
        }
        return CardState(phase: phase, step: step, stability: s, difficulty: d, lastReview: at, due: at.addingTimeInterval(interval),
                         reviews: (state?.reviews ?? 0) + 1, lapses: (state?.lapses ?? 0) + (state != nil && g == 1 ? 1 : 0))
    }

    /// The state after all reviews in order; nil when the card was never reviewed.
    public static func schedule(_ reviews: [(rating: CardRating, at: Date)], profile: Profile = .lingo) -> CardState? {
        reviews.reduce(nil as CardState?) { review($0, rating: $1.rating, at: $1.at, profile: profile) }
    }
}
