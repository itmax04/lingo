import Foundation

/// Event payloads (R-35). All fields are synthetic or user texts; API keys never get here (R-48).
public enum Payload {
    public struct SessionCreated: Codable, Sendable, Hashable {
        public var title: String
        public var settings: SessionSettings
        public init(title: String, settings: SessionSettings) { self.title = title; self.settings = settings }
    }

    /// Change of the title and/or settings. `nil` — the field is unchanged.
    public struct SessionUpdated: Codable, Sendable, Hashable {
        public var title: String?
        public var settings: SessionSettings?
        public init(title: String? = nil, settings: SessionSettings? = nil) { self.title = title; self.settings = settings }
    }

    public struct MessageCreated: Codable, Sendable, Hashable {
        public var role: Role
        public var text: String
        public var lang: Lang
        public var segments: [ReplySegment]?
        public var source: String?
        public var kind: ChatMessage.Kind?
        /// The user message this is a reply to — for "Reply again" (R-09).
        public var replyTo: String?
        /// LINGO-09 MR-18: fixed app text spoken without a model request. Missing = false; excluded from the context window.
        public var local: Bool?

        public init(role: Role, text: String, lang: Lang, segments: [ReplySegment]? = nil, source: String? = nil,
                    kind: ChatMessage.Kind? = nil, replyTo: String? = nil, local: Bool? = nil) {
            self.role = role
            self.text = text
            self.lang = lang
            self.segments = segments
            self.source = source
            self.kind = kind
            self.replyTo = replyTo
            self.local = local
        }
    }

    public struct MessageEdited: Codable, Sendable, Hashable {
        public var message: String
        public var text: String
        public init(message: String, text: String) { self.message = message; self.text = text }
    }

    public struct MessageInterrupted: Codable, Sendable, Hashable {
        public var message: String
        public var at: Int
        public init(message: String, at: Int) { self.message = message; self.at = at }
    }

    public struct SummaryUpdated: Codable, Sendable, Hashable {
        public var text: String
        /// The last message included in the summary (R-04).
        public var through: String?
        public init(text: String, through: String? = nil) { self.text = text; self.through = through }
    }

    public struct FixRecorded: Codable, Sendable, Hashable {
        public var message: String
        public var fix: Fix
        public init(message: String, fix: Fix) { self.message = message; self.fix = fix }
    }

    public struct HintAdded: Codable, Sendable, Hashable {
        public var phrase: Phrase
        public init(phrase: Phrase) { self.phrase = phrase }
    }

    public struct PhraseMark: Codable, Sendable, Hashable {
        public var phrase: Phrase
        public init(phrase: Phrase) { self.phrase = phrase }
    }

    // MARK: My vocabulary (LINGO-08, VR-02) and the learner profile (PR-01)

    public struct VocabDraft: Codable, Sendable, Hashable {
        public var lang: Lang
        public var text: String
        public var translation: String?
        public var note: String?
        public var example: String?
        public var source: VocabSource
        public init(lang: Lang, text: String, translation: String? = nil, note: String? = nil, example: String? = nil, source: VocabSource = .manual) {
            self.lang = lang; self.text = text; self.translation = translation; self.note = note; self.example = example; self.source = source
        }
    }

    public struct VocabAdded: Codable, Sendable, Hashable {
        public var item: VocabDraft
        public init(item: VocabDraft) { self.item = item }
    }

    /// Only the fields that are present change (each one last-writer-wins).
    public struct VocabUpdated: Codable, Sendable, Hashable {
        public var item: String
        public var text: String?
        public var translation: String?
        public var note: String?
        public var example: String?
        public init(item: String, text: String? = nil, translation: String? = nil, note: String? = nil, example: String? = nil) {
            self.item = item; self.text = text; self.translation = translation; self.note = note; self.example = example
        }
    }

    public struct VocabRemoved: Codable, Sendable, Hashable {
        public var item: String
        public init(item: String) { self.item = item }
    }

    public struct VocabUsed: Codable, Sendable, Hashable {
        public var item: String
        /// The learner's message (by learner) or the assistant's reply (by assistant): one event counts per (item, by, message).
        public var message: String
        public var by: VocabActor
        public var outcome: VocabOutcome
        public init(item: String, message: String, by: VocabActor, outcome: VocabOutcome) {
            self.item = item; self.message = message; self.by = by; self.outcome = outcome
        }
    }

    /// LINGO-05 CR-02: a card review in a warm-up; `message` is the graded learner message, "" for a skipped card.
    public struct CardReviewed: Codable, Sendable, Hashable {
        public var card: String
        public var rating: CardRating
        public var source: CardReviewSource
        public var message: String
        public init(card: String, rating: CardRating, source: CardReviewSource = .warmup, message: String) {
            self.card = card; self.rating = rating; self.source = source; self.message = message
        }
    }

    /// LINGO-05 SR-03: task `task` (1-based) of the session's scenario was completed in reply to the learner message `message`.
    public struct ScenarioTask: Codable, Sendable, Hashable {
        public var task: Int
        public var message: String
        public init(task: Int, message: String) { self.task = task; self.message = message }
    }

    /// LINGO-05 XR-02: the start of a timed exam phase.
    public struct ExamPart: Codable, Sendable, Hashable {
        public var part: ExamPhase
        public init(part: ExamPhase) { self.part = part }
    }

    /// LINGO-05 GR-05: the advice for one ISO week ("YYYY-Www"); the last writer per week wins.
    public struct ReportWeekly: Codable, Sendable, Hashable {
        public var week: String
        public var text: String
        public init(week: String, text: String) { self.week = week; self.text = text }
    }

    /// LINGO-05 GR-06: a memory fact the learner said about themselves; `lang` is "de", "en" or "" (general). The event id is the fact id.
    public struct MemoryNoted: Codable, Sendable, Hashable {
        public var text: String
        public var lang: String
        public init(text: String, lang: String) { self.text = text; self.lang = lang }
    }

    /// LINGO-05 GR-06: the new text of a fact (last writer by lamport, device).
    public struct MemoryUpdated: Codable, Sendable, Hashable {
        public var fact: String
        public var text: String
        public init(fact: String, text: String) { self.fact = fact; self.text = text }
    }

    /// LINGO-05 GR-06: the fact is deleted (final).
    public struct MemoryRemoved: Codable, Sendable, Hashable {
        public var fact: String
        public init(fact: String) { self.fact = fact }
    }

    /// LINGO-05 GR-06: memory on or off (last writer wins; on by default).
    public struct MemorySwitched: Codable, Sendable, Hashable {
        public var on: Bool
        public init(on: Bool) { self.on = on }
    }

    /// LINGO-05 GR-02: the daily goal in minutes (5–120; other values are clamped when read).
    public struct GoalSet: Codable, Sendable, Hashable {
        public var minutes: Int
        public init(minutes: Int) { self.minutes = minutes }
    }

    /// LINGO-05 CR-02: a card is suspended (never queued) or resumed; last writer wins.
    public struct CardSuspended: Codable, Sendable, Hashable {
        public var card: String
        public var suspended: Bool
        public init(card: String, suspended: Bool) { self.card = card; self.suspended = suspended }
    }

    public struct ProfileUpdated: Codable, Sendable, Hashable {
        public var goals: String?
        public var interests: String?
        public init(goals: String? = nil, interests: String? = nil) { self.goals = goals; self.interests = interests }
    }
}
