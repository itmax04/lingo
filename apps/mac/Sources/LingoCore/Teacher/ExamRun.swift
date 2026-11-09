import Foundation

/// Timed phases and roles of XR-02. A preparation phase never starts a model turn or captures audio.
public enum ExamPhase: String, Codable, Sendable, CaseIterable {
    case goethePrep = "goethe_b1.1.prep", goethe1 = "goethe_b1.1", goethe2 = "goethe_b1.2", goethe3 = "goethe_b1.3"
    case ielts1 = "ielts.1", ieltsPrep = "ielts.2.prep", ielts2 = "ielts.2", ielts3 = "ielts.3"
    /// LINGO-10 BR-02a: additive part values. No run uses them before G-3; `goetheEnd` is a marker, not a timed part.
    case goetheIntro = "goethe_b1.intro", goethePartner = "goethe_b1.2.partner", goetheFeedback = "goethe_b1.3.feedback", goetheEnd = "goethe_b1.end"
    public var isPreparation: Bool { self == .goethePrep || self == .ieltsPrep }
    public var isMonologue: Bool { self == .goethe2 || self == .ielts2 }
    public var seconds: Int {
        switch self {
        case .goethePrep: 900
        case .goethe1, .goethe2: 180
        case .goethe3, .ielts2: 120
        case .ielts1, .ielts3: 300
        case .ieltsPrep, .goetheIntro: 60
        case .goetheFeedback: 120
        case .goethePartner: 300
        case .goetheEnd: 0
        }
    }
    public var role: String {
        switch self {
        case .goethePrep, .ieltsPrep: "prepare silently"
        case .goethe1: "planning partner; suggest and sometimes disagree; cover the four points"
        case .goethe2: "silent listener; after the monologue, acknowledge briefly"
        case .goethe3: "partner; one short reaction and one question, then close"
        case .ielts1, .ielts3: "neutral examiner; ask the listed questions in order, one at a time"
        case .ielts2: "after the monologue, ask the one follow-up question"
        case .goetheIntro: "examiner; greet and let the learner introduce themselves (not assessed)"
        case .goethePartner: "partner; present the prepared talk"
        case .goetheFeedback: "partner; answer the learner's feedback and question"
        case .goetheEnd: "none; end marker"
        }
    }
    public var taskIndex: Int {
        switch self {
        case .goethePrep, .goethe1, .ielts1, .goetheIntro: 0
        case .goethe2, .ieltsPrep, .ielts2, .goethePartner, .goetheFeedback: 1
        case .goethe3, .ielts3, .goetheEnd: 2
        }
    }
}

/// Value-state for the exam coordinator (no wall-clock task, audio or model calls).
/// A queued transition is applied once after the running turn, rather than skipping a part on every timer tick.
public struct ExamRun: Sendable, Equatable {
    public let kind: ExamKind
    public let tasks: [String]
    public private(set) var index = 0
    public private(set) var startedAt: Date
    public private(set) var timeIsUp = false
    public private(set) var finished = false
    private var pending: Bool?
    public var phases: [ExamPhase] {
        kind == .goetheB1 ? [.goethePrep, .goethe1, .goethe2, .goethe3] : [.ielts1, .ieltsPrep, .ielts2, .ielts3]
    }
    public var phase: ExamPhase { phases[index] }
    public var task: ExamTask { ExamCatalog.task(tasks[phase.taskIndex])! }
    public var microphoneAllowed: Bool { !finished && !phase.isPreparation }
    public func remaining(now: Date) -> Int { max(0, min(phase.seconds, Int(ceil(Double(phase.seconds) - now.timeIntervalSince(startedAt))))) }

    public init?(kind: ExamKind, tasks: [String], now: Date) {
        guard ExamCatalog.validSelection(kind, ids: tasks) else { return nil }
        self.kind = kind; self.tasks = tasks; self.startedAt = now
    }

    /// `expected` comes from the action/timer that saw that phase; stale double clicks do nothing.
    /// The coordinator releases a held monologue BEFORE requesting its phase transition.
    @discardableResult public mutating func advance(expected: ExamPhase, timeUp: Bool, turnRunning: Bool, now: Date) -> Bool {
        guard !finished, expected == phase else { return false }
        if turnRunning { pending = (pending ?? false) || timeUp; return false }
        timeIsUp = timeUp; pending = nil
        if index == phases.count - 1 { finished = true } else { index += 1; startedAt = now }
        return true
    }

    @discardableResult public mutating func turnFinished(now: Date) -> Bool {
        guard let timedOut = pending else { return false }
        return advance(expected: phase, timeUp: timedOut, turnRunning: false, now: now)
    }

    /// Clear the one-request transition notice after the coordinator has built that request.
    public mutating func consumeTransition() { timeIsUp = false }

    public static func isDoneUtterance(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        return ["fertig", "done", "finished"].contains(cleaned)
    }

    /// "That's all" (R-22) ends the whole exam session, typed or spoken; a Done word only completes the part.
    public static func isFinishCommand(_ text: String) -> Bool {
        !isDoneUtterance(text) && CommandDetector.detect(text)?.kind == .finish
    }
}
