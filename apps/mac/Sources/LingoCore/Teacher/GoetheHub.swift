import Foundation

/// LINGO-10 BR-34, BR-36: what the Goethe screen reads from the journal. Pure functions of the history, so they are unit tested.
public enum GoetheHub {
    public struct Practice: Sendable, Equatable {
        public var count: Int
        public var last: Date
    }

    /// BR-34: per task id, the number of live German exam sessions (legacy ones included) that hold at least one learner message and
    /// have the task in `tasks`, and the date of the latest of them. A Mock holds three tasks, so each of them counts once.
    public static func practice(_ state: HistoryState) -> [String: Practice] {
        var result: [String: Practice] = [:]
        for session in state.sessions.values where !session.deleted {
            guard let a = session.settings.activity, a.kind == .exam, a.exam == ExamKind.goetheB1.rawValue else { continue }
            guard (state.messages[session.id] ?? []).contains(where: { $0.role == .user && $0.kind == .normal }) else { continue }
            for id in Set(a.tasks ?? []) {
                let last = max(result[id]?.last ?? .distantPast, session.lastActivity)
                result[id] = Practice(count: (result[id]?.count ?? 0) + 1, last: last)
            }
        }
        return result
    }

    public struct DebriefEntry: Sendable, Equatable, Identifiable {
        public var id: String
        public var date: Date
        public var format: Activity.Format
        public var teil: Int?
        /// German title of the topic: the learner's talk in a Mock, the chosen task in Training.
        public var topic: String
    }

    /// BR-36: sessions with a format that have ended, newest first, including those whose debrief failed (Retry lives on the session).
    public static func debriefs(_ state: HistoryState) -> [DebriefEntry] {
        state.sessions.values.compactMap { s -> DebriefEntry? in
            guard !s.deleted, s.state == .ended, let a = s.settings.activity, a.kind == .exam, let format = a.format,
                  a.exam == ExamKind.goetheB1.rawValue else { return nil }
            let ids = a.tasks ?? []
            let task = ExamCatalog.task(format == .mock ? (ids.count > 1 ? ids[1] : "") : (ids.first ?? ""))
            return DebriefEntry(id: s.id, date: s.lastActivity, format: format, teil: a.teil, topic: task?.title ?? task?.task ?? s.title)
        }
        .sorted { ($0.date, $0.id) > ($1.date, $1.id) }
    }

    /// The categories present in a Teil, in the fixed order of `ExamCategory`.
    public static func categories(teil: Int) -> [ExamCategory] {
        let present = Set(ExamCatalog.tasks(.goetheB1, part: teil).compactMap(\.category))
        return ExamCategory.allCases.filter(present.contains)
    }

    /// Tasks of a Teil for the Training list, optionally of one category. The order is the catalogue's.
    public static func tasks(teil: Int, category: ExamCategory?) -> [ExamTask] {
        ExamCatalog.tasks(.goetheB1, part: teil).filter { category == nil || $0.category == category }
    }
}
