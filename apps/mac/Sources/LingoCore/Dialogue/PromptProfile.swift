import Foundation

/// Learner profile for the system part (LINGO-08 PR-01). Computed once per session from the journal as it was before the session
/// started, so the system part stays identical during the session and the provider can cache it.
public struct PromptProfile: Sendable, Hashable {
    public struct Mistake: Sendable, Hashable {
        public var rule: String
        /// `original → corrected`, at most `PromptProfile.exampleLimit` characters; empty when every example of the group is longer.
        public var example: String
        public init(rule: String, example: String) { self.rule = rule; self.example = example }
    }

    public var goals = ""
    public var interests = ""
    public var mistakes: [Mistake] = []

    public static let maxMistakes = 3
    public static let minOccurrences = 2
    public static let window: TimeInterval = 30 * 86_400
    public static let exampleLimit = 80

    public init(goals: String = "", interests: String = "", mistakes: [Mistake] = []) {
        self.goals = goals
        self.interests = interests
        self.mistakes = mistakes
    }

    public var isEmpty: Bool {
        goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && interests.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && mistakes.isEmpty
    }
}

/// A `profile.updated` event kept with its version, so the profile can be read as it was at a given time (PR-01).
public struct ProfileUpdate: Sendable, Hashable {
    public var ts: Date
    public var version: Version
    public var goals: String?
    public var interests: String?
}

public extension HistoryState {
    /// The goals and interests as they were before `date` (per-field LWW over the earlier updates).
    func learnerProfile(before date: Date) -> LearnerProfile {
        var goals = LWW(""), interests = LWW("")
        for u in profileUpdates where u.ts < date {
            if let g = u.goals { goals.apply(g, u.version) }
            if let i = u.interests { interests.apply(i, u.version) }
        }
        return LearnerProfile(goals: goals.value, interests: interests.value)
    }

    /// The profile block of a session (PR-01): goals and interests before the session started and up to 3 recurring mistakes —
    /// `fix.recorded` of other non-deleted sessions in the same language from the 30 days before it, grouped by the normalised rule
    /// text, at least 2 occurrences, most frequent first (then the most recent, then the key).
    func promptProfile(session: String) -> PromptProfile {
        guard let s = sessions[session] else { return PromptProfile() }
        let start = s.createdAt
        let p = learnerProfile(before: start)
        struct Group { var count = 0; var last = Date.distantPast; var rule = ""; var examples: [String] = [] }
        var groups: [String: Group] = [:]
        for (sid, list) in fixes where sid != session {
            guard let other = sessions[sid], !other.deleted, other.settings.lang == s.settings.lang else { continue }
            for f in list where f.ts < start && f.ts >= start.addingTimeInterval(-PromptProfile.window) {
                let key = VocabularyText.normalize(f.fix.rule)
                guard !key.isEmpty else { continue }
                var g = groups[key] ?? Group()
                g.count += 1
                if f.ts >= g.last { g.last = f.ts; g.rule = f.fix.rule }
                g.examples.append("\(f.fix.original) → \(f.fix.corrected)")
                groups[key] = g
            }
        }
        let ranked = groups.filter { $0.value.count >= PromptProfile.minOccurrences }.sorted { a, b in
            if a.value.count != b.value.count { return a.value.count > b.value.count }
            if a.value.last != b.value.last { return a.value.last > b.value.last }
            return Array(a.key.utf8).lexicographicallyPrecedes(Array(b.key.utf8))
        }
        let mistakes = ranked.prefix(PromptProfile.maxMistakes).map { _, g in
            let example = g.examples.map(PromptBuilder.oneLine)
                .filter { $0.unicodeScalars.count <= PromptProfile.exampleLimit }
                .min { a, b in
                    let (x, y) = (a.unicodeScalars.count, b.unicodeScalars.count)
                    return x != y ? x < y : Array(a.utf8).lexicographicallyPrecedes(Array(b.utf8))
                } ?? ""
            return PromptProfile.Mistake(rule: PromptBuilder.cut(PromptBuilder.oneLine(g.rule), PromptProfile.exampleLimit), example: example)
        }
        return PromptProfile(goals: p.goals, interests: p.interests, mistakes: Array(mistakes))
    }
}
