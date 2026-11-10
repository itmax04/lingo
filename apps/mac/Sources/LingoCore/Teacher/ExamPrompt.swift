import Foundation

extension PromptBuilder {
    /// Constant within the session; ≤ 200 estimated provider tokens (PX-03).
    static let examinerRule = "Exam practice. Follow the current <exam> part, role and task; questions in order, one per turn. Suspend base rule 5: for Russian, ask once in the study language to answer in that language; do not translate or drill. Suspend spoken corrections, even on request: keep silent @fix lines for real mistakes. Rules 1, 3, 4 and 7 still apply. Do not abandon the task for an off-topic answer. Preparation and monologues are managed by the app: do not speak during them. When time is up, give one short transition line and start the named part. Never rate pronunciation or give a score."

    /// LINGO-10 BR-25: replaces `examinerRule` in a Goethe Training; ≤ 200 estimated provider tokens (PX-03). Corrections, Russian,
    /// commands and the output protocol keep their ordinary (non-exam) text there.
    static let goetheTrainingRule = "Exam training. Follow the current <exam> part, role and task. You play the learner's exam partner, never the examiner; at most one question per turn. Ignore remaining_seconds: the learner ends the part. Rules 1, 3, 4 and 7 still apply; corrections follow rule 6. Do not abandon the task for an off-topic answer. The app speaks the examiner's lines and the prepared talk: do not speak for them. Never rate pronunciation or give a score."

    /// BR-14: the learner's whole talk in one turn, at most this many characters.
    static let examOwnTalkCap = 4_000

    /// Dynamic part data follows the transcript. A scalar budget also covers adversarial max-length Unicode data (PX-03).
    static func examBlock(_ run: ExamRun, now: Date) -> String {
        // BR-15: in a run with a format the Examiner line is the transition, so `time is up` is never sent.
        examBlock(phase: run.phase, task: run.task, remaining: run.remaining(now: now), timeIsUp: run.format == nil && run.timeIsUp,
                  role: run.role, format: run.format)
    }

    /// BR-24a: the feedback part carries the talk summary in place of the task (the full talk is never sent), and Mock Teil 3 has
    /// no `questions:`, so the partner cannot ask the question that the Examiner asks next.
    static func examBlock(phase: ExamPhase, task t: ExamTask, remaining: Int, timeIsUp: Bool, role: String? = nil,
                          format: Activity.Format? = nil) -> String {
        var fields = ["part: \(phase.rawValue)", "remaining_seconds: \(max(0, min(phase.seconds, remaining)))", "role: \(role ?? phase.role)"]
        if timeIsUp { fields.append("time is up for the previous part; make one short transition") }
        var task = phase == .goetheFeedback ? "talk_summary: \(oneLine(t.talkSummary ?? ""))" : "task: \(oneLine(t.task))"
        if phase != .goetheFeedback, !t.points.isEmpty { task += "\n" + t.points.enumerated().map { "\($0.offset + 1). \(oneLine($0.element))" }.joined(separator: "\n") }
        if phase != .goetheFeedback, !t.questions.isEmpty, !(format == .mock && phase == .goethe3) {
            task += "\nquestions: " + t.questions.map(oneLine).joined(separator: " | ")
        }
        // The full catalogue task remains on screen. Only a bounded excerpt is sent to the model; it is data, never instructions.
        let prefix = fields.joined(separator: "\n") + "\n"
        return "<exam>\n" + prefix + cut(task, max(0, 700 - prefix.unicodeScalars.count)) + "\n</exam>"
    }

    /// BR-14: the request of Mock Teil 3 sees the learner's whole talk as one turn (every line shortened evenly within the cap)
    /// instead of the last turns. Nil for any other part, or when the learner said nothing.
    static func examOwnTalk(_ run: ExamRun?, _ messages: [ChatMessage]) -> [ChatMessage]? {
        guard let run, run.format == .mock, run.phase == .goethe3 else { return nil }
        let lines = messages.filter { run.ownTalk.contains($0.id) && $0.role == .user }
        guard var one = lines.first else { return nil }
        let texts = lines.map { oneLine($0.text).trimmingCharacters(in: .whitespaces) }
        let total = texts.reduce(0) { $0 + $1.unicodeScalars.count + 1 }
        let each = total > examOwnTalkCap ? max(40, examOwnTalkCap / texts.count - 1) : examOwnTalkCap
        one.text = cut(texts.map { cut($0, each) }.joined(separator: " "), examOwnTalkCap)
        return [one]
    }
}
