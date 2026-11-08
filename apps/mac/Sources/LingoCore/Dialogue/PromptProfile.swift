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
    /// Memory facts (GR-06): up to `maxFacts`, oldest first, frozen with the profile.
    public var facts: [String] = []

    /// The frozen profile minus facts that are no longer live (deleted, edited or memory switched off) in `state` (GR-06: hidden from Lingo).
    public func keepingLiveFacts(of state: HistoryState) -> PromptProfile {
        var p = self
        let live = Set(state.memoryFacts.map(\.text))
        p.facts = state.memoryOn ? facts.filter { live.contains($0) } : []
        return p
    }

    public static let maxFacts = 5
    public static let maxMistakes = 3
    public static let minOccurrences = 2
    public static let window: TimeInterval = 30 * 86_400
    public static let exampleLimit = 80

    public init(goals: String = "", interests: String = "", mistakes: [Mistake] = [], facts: [String] = []) {
        self.facts = facts
        self.goals = goals
        self.interests = interests
        self.mistakes = mistakes
    }

    public var isEmpty: Bool {
        goals.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && interests.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && mistakes.isEmpty && facts.isEmpty
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

    /// The profile block of a session (PR-01); the engine computes it once per session and keeps it, so events that sync later do not
    /// change the system part in the middle of a session: goals and interests before the session started and up to 3 recurring mistakes —
    /// `fix.recorded` of other non-deleted sessions in the same language from the 30 days before it, grouped by the normalised rule
    /// text, at least 2 occurrences, most frequent first (then the most recent, then the key).
    func promptProfile(session: String) -> PromptProfile {
        guard let s = sessions[session] else { return PromptProfile() }
        let start = s.createdAt
        let p = learnerProfile(before: start)
        let mistakes = recurringMistakes(lang: s.settings.lang, before: start, excluding: session)
        // Memory facts (GR-06): the 5 most recent live facts of the session language or general that existed before the session started
        // (oldest of them first). With memory off, none.
        let facts = memoryOn ? memoryFacts.filter { ($0.lang == nil || $0.lang == s.settings.lang) && $0.ts < start }.suffix(PromptProfile.maxFacts).map(\.text) : []
        return PromptProfile(goals: p.goals, interests: p.interests, mistakes: Array(mistakes), facts: facts)
    }

    /// Up to 3 recurring mistakes of a language (PR-01): `fix.recorded` of non-deleted sessions in that language from the 30 days before
    /// `date` (a session id in `excluding` is skipped), grouped by the normalised rule text, at least 2 occurrences, most frequent first
    /// (then the most recent, then the key). Also shown on "What Lingo knows about me" (GR-06).
    func recurringMistakes(lang: Lang, before date: Date, excluding: String? = nil) -> [PromptProfile.Mistake] {
        struct Group { var count = 0; var last = Date.distantPast; var rule = ""; var examples: [String] = [] }
        var groups: [String: Group] = [:]
        var picked: [(sid: String, f: FixEntry)] = []
        for (sid, list) in fixes where sid != excluding {
            guard let other = sessions[sid], !other.deleted, other.settings.lang == lang else { continue }
            for f in list where f.ts < date && f.ts >= date.addingTimeInterval(-PromptProfile.window) { picked.append((sid, f)) }
        }
        // A fixed order (time, session, message, rule, original), so the rule spelling shown for a group never depends on dictionary order.
        picked.sort { ($0.f.ts, $0.sid, $0.f.message, $0.f.fix.rule, $0.f.fix.original) < ($1.f.ts, $1.sid, $1.f.message, $1.f.fix.rule, $1.f.fix.original) }
        for (_, f) in picked {
            let key = VocabularyText.normalize(f.fix.rule)
            guard !key.isEmpty else { continue }
            var g = groups[key] ?? Group()
            g.count += 1
            g.last = f.ts
            g.rule = f.fix.rule
            g.examples.append("\(f.fix.original) → \(f.fix.corrected)")
            groups[key] = g
        }
        let ranked = groups.filter { $0.value.count >= PromptProfile.minOccurrences }.sorted { a, b in
            if a.value.count != b.value.count { return a.value.count > b.value.count }
            if a.value.last != b.value.last { return a.value.last > b.value.last }
            return Array(a.key.utf8).lexicographicallyPrecedes(Array(b.key.utf8))
        }
        return ranked.prefix(PromptProfile.maxMistakes).map { _, g in
            let example = g.examples.map(PromptBuilder.oneLine)
                .filter { $0.unicodeScalars.count <= PromptProfile.exampleLimit }
                .min { a, b in
                    let (x, y) = (a.unicodeScalars.count, b.unicodeScalars.count)
                    return x != y ? x < y : Array(a.utf8).lexicographicallyPrecedes(Array(b.utf8))
                } ?? ""
            return PromptProfile.Mistake(rule: PromptBuilder.cut(PromptBuilder.oneLine(g.rule), PromptProfile.exampleLimit), example: example)
        }
    }
}
