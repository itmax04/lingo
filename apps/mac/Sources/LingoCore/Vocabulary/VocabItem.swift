import Foundation

/// Where a vocabulary item came from (VR-01, LINGO-08).
public enum VocabSource: String, Codable, Sendable, Hashable { case manual, list, starred }

/// Who used an item in a turn, and how (VR-02, VR-07).
public enum VocabActor: String, Codable, Sendable, Hashable { case learner, assistant }
public enum VocabOutcome: String, Codable, Sendable, Hashable { case ok, mistake }

/// One word, phrase or expression the learner wants to practise (VR-01), with its practice statistics (VR-05).
public struct VocabItem: Sendable, Hashable, Identifiable {
    public var id: String
    public var lang: Lang
    public var text: String
    public var translation: String
    public var note: String
    public var example: String
    public var source: VocabSource
    public var createdAt: Date
    /// The assistant used it in a reply.
    public var offered = 0
    /// The learner used it without a correction.
    public var used = 0
    /// The learner used it and the reply corrected it.
    public var mistakes = 0
    public var lastPractised: Date?

    public init(id: String, lang: Lang, text: String, translation: String = "", note: String = "", example: String = "",
                source: VocabSource = .manual, createdAt: Date, offered: Int = 0, used: Int = 0, mistakes: Int = 0, lastPractised: Date? = nil) {
        self.id = id
        self.lang = lang
        self.text = text
        self.translation = translation
        self.note = note
        self.example = example
        self.source = source
        self.createdAt = createdAt
        self.offered = offered
        self.used = used
        self.mistakes = mistakes
        self.lastPractised = lastPractised
    }

    /// Id of a ★ phrase shown as an item (A-02): stable, derived from the phrase key.
    public static func starredID(_ phraseKey: String) -> String { "star:" + phraseKey }
}

/// The learner's profile used by the prompt (PR-01): free text, synced through the journal (`profile.updated`).
public struct LearnerProfile: Sendable, Hashable {
    public var goals = ""
    public var interests = ""
    public init(goals: String = "", interests: String = "") { self.goals = goals; self.interests = interests }
}
