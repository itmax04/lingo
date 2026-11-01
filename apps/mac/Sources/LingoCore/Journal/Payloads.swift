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

        public init(role: Role, text: String, lang: Lang, segments: [ReplySegment]? = nil, source: String? = nil,
                    kind: ChatMessage.Kind? = nil, replyTo: String? = nil) {
            self.role = role
            self.text = text
            self.lang = lang
            self.segments = segments
            self.source = source
            self.kind = kind
            self.replyTo = replyTo
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
