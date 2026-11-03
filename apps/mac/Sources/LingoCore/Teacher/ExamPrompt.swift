import Foundation

extension PromptBuilder {
    /// Constant within the session; ≤ 200 estimated provider tokens (PX-03).
    static let examinerRule = "Exam practice. Follow the current <exam> part, role and task; questions in order, one per turn. Suspend base rule 5: for Russian, ask once in the study language to answer in that language; do not translate or drill. Suspend spoken corrections, even on request: keep silent @fix lines for real mistakes. Rules 1, 3, 4 and 7 still apply. Do not abandon the task for an off-topic answer. Preparation and monologues are managed by the app: do not speak during them. When time is up, give one short transition line and start the named part. Never rate pronunciation or give a score."

    /// Dynamic part data follows the transcript. A scalar budget also covers adversarial max-length Unicode data (PX-03).
    static func examBlock(_ run: ExamRun, now: Date) -> String {
        examBlock(phase: run.phase, task: run.task, remaining: run.remaining(now: now), timeIsUp: run.timeIsUp)
    }

    static func examBlock(phase: ExamPhase, task t: ExamTask, remaining: Int, timeIsUp: Bool) -> String {
        var fields = ["part: \(phase.rawValue)", "remaining_seconds: \(max(0, min(phase.seconds, remaining)))", "role: \(phase.role)"]
        if timeIsUp { fields.append("time is up for the previous part; make one short transition") }
        var task = "task: \(oneLine(t.task))"
        if !t.points.isEmpty { task += "\n" + t.points.enumerated().map { "\($0.offset + 1). \(oneLine($0.element))" }.joined(separator: "\n") }
        if !t.questions.isEmpty { task += "\nquestions: " + t.questions.map(oneLine).joined(separator: " | ") }
        // The full catalogue task remains on screen. Only a bounded excerpt is sent to the model; it is data, never instructions.
        let prefix = fields.joined(separator: "\n") + "\n"
        return "<exam>\n" + prefix + cut(task, max(0, 700 - prefix.unicodeScalars.count)) + "\n</exam>"
    }
}
