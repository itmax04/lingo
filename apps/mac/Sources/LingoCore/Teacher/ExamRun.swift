import Foundation

/// Timed phases and roles of XR-02. A preparation phase never starts a model turn or captures audio.
public enum ExamPhase: String, Codable, Sendable, CaseIterable {
    case goethePrep = "goethe_b1.1.prep", goethe1 = "goethe_b1.1", goethe2 = "goethe_b1.2", goethe3 = "goethe_b1.3"
    case ielts1 = "ielts.1", ieltsPrep = "ielts.2.prep", ielts2 = "ielts.2", ielts3 = "ielts.3"
    /// LINGO-10 BR-02a: additive part values of a run with a format; `goetheEnd` is a marker, not a timed part.
    case goetheIntro = "goethe_b1.intro", goethePartner = "goethe_b1.2.partner", goetheFeedback = "goethe_b1.3.feedback", goetheEnd = "goethe_b1.end"
    public var isPreparation: Bool { self == .goethePrep || self == .ieltsPrep }
    /// Held speech without a model reply: the talks, and the unassessed introduction of a Mock (BR-11).
    public var isMonologue: Bool { self == .goethe2 || self == .ielts2 || self == .goetheIntro }
    public var seconds: Int {
        switch self {
        case .goethePrep: 900
        case .goethe1: 180
        case .goethe2: 240 // BR-07: shown as "3-4 min"; the speech buffer of TurnController derives from it
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
    /// LINGO-10 BR-01: nil for IELTS and for a legacy German exam.
    public let format: Activity.Format?
    public let teil: Int?
    public let partnerTask: String?
    /// BR-14: ids of the learner's own Teil 2 lines in a Mock, for the partner's reaction in Teil 3. Ids only, never text.
    public var ownTalk: [String] = []
    public private(set) var index = 0
    public private(set) var startedAt: Date
    public private(set) var timeIsUp = false
    public private(set) var finished = false
    private var pending: Bool?
    /// BR-07. Mock preparation runs before the session exists, so it is not a phase of the run.
    public var phases: [ExamPhase] {
        switch (format, teil) {
        case (.mock, _): [.goetheIntro, .goethe1, .goethe2, .goethe3, .goethePartner, .goetheFeedback]
        case (.training, 1): [.goethe1]
        case (.training, 2): [.goethe2]
        case (.training, _): [.goethePartner, .goetheFeedback, .goethe3]
        default: kind == .goetheB1 ? [.goethePrep, .goethe1, .goethe2, .goethe3] : [.ielts1, .ieltsPrep, .ielts2, .ielts3]
        }
    }
    public var phase: ExamPhase { phases[index] }
    /// The partner's talk is the `partnerTask` of a Mock and the talk linked to the discussion task of a Training (BR-13, BR-17).
    public var task: ExamTask {
        let partner = phase == .goethePartner || phase == .goetheFeedback
        switch format {
        case .mock: return ExamCatalog.task(partner ? partnerTask! : tasks[phase.taskIndex])!
        case .training: return partner ? ExamCatalog.task(ExamCatalog.task(tasks[0])!.linkedTo!)! : ExamCatalog.task(tasks[0])!
        case nil: return ExamCatalog.task(tasks[phase.taskIndex])!
        }
    }
    /// BR-10: closed for the whole partner's talk, also after its speech has ended.
    public var microphoneAllowed: Bool { !finished && !phase.isPreparation && phase != .goethePartner }
    /// BR-09, BR-18: Training dialogue parts and its partner's talk do not end at zero; the monologue always does.
    public var endsAtZero: Bool { format != .training || phase == .goethe2 }
    /// BR-24: role texts of a run with a format; legacy and IELTS roles are unchanged.
    public var role: String {
        guard let format else { return phase.role }
        switch phase {
        case .goethe1: return "planning partner; suggest and sometimes disagree; cover the four points and accept one more if the learner brings it"
        case .goethe3: return format == .mock ? "partner; one short reaction to the talk and one question"
            : "partner; react briefly to the learner's answer to the examiner's question; ask nothing new"
        case .goetheFeedback: return "partner who has just given a talk; answer the learner's question in one or two sentences from the talk summary"
        default: return phase.role
        }
    }
    /// BR-10: what the Examiner says to open the current part. In Training Teil 3 the catalogue question follows the line (BR-07).
    public var examinerOpening: [String] {
        guard format != nil, let line = GoetheExaminerLine(rawValue: phase.rawValue) else { return [] }
        return [line.text] + (format == .training && phase == .goethe3 ? Array(task.questions.prefix(1)) : [])
    }
    public func remaining(now: Date) -> Int { max(0, min(phase.seconds, Int(ceil(Double(phase.seconds) - now.timeIntervalSince(startedAt))))) }

    public init?(kind: ExamKind, tasks: [String], format: Activity.Format? = nil, teil: Int? = nil, partnerTask: String? = nil, now: Date) {
        guard ExamCatalog.valid(kind, ids: tasks, format: format, teil: teil, partnerTask: partnerTask) else { return nil }
        self.kind = kind; self.tasks = tasks; self.format = format; self.teil = teil; self.partnerTask = partnerTask; self.startedAt = now
    }

    /// BR-10: the part's timer starts when its Examiner line has ended.
    public mutating func restart(now: Date) { startedAt = now }

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

    /// BR-13: the partner's talk as sentences for the speech queue (the talks hold no abbreviations or digits, D-G2-4).
    public static func sentences(_ text: String) -> [String] {
        var out: [String] = [], current = ""
        for ch in text {
            if ch.isNewline { out.append(current); current = ""; continue }
            current.append(ch)
            if ".!?".contains(ch) { out.append(current); current = "" }
        }
        return (out + [current]).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    public static func isDoneUtterance(_ text: String) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()
        return ["fertig", "done", "finished"].contains(cleaned)
    }

    /// "That's all" (R-22) ends the whole exam session, typed or spoken; a Done word only completes the part.
    public static func isFinishCommand(_ text: String) -> Bool {
        !isDoneUtterance(text) && CommandDetector.detect(text)?.kind == .finish
    }
}
