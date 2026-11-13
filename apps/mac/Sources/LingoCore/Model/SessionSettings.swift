import Foundation

/// Session mode (R-03).
public enum SessionMode: String, Codable, Sendable, CaseIterable, Hashable {
    case questions, free, customPrompt = "custom"

    public var title: String {
        switch self {
        case .questions: String(localized: "Questions")
        case .free: String(localized: "Free conversation")
        case .customPrompt: String(localized: "Custom prompt")
        }
    }
}

/// Correction modes (R-20). Any non-empty combination is allowed.
public enum CorrectionMode: String, Codable, Sendable, CaseIterable, Hashable, Comparable {
    case inline, after, onDemand = "on_demand"

    public var title: String {
        switch self {
        case .inline: String(localized: "As we go")
        case .after: String(localized: "After the conversation")
        case .onDemand: String(localized: "On request")
        }
    }

    public static func < (a: CorrectionMode, b: CorrectionMode) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// Who starts the conversation (S-01).
public enum Starter: String, Codable, Sendable, CaseIterable, Hashable {
    case assistant, user

    public var title: String {
        switch self {
        case .assistant: String(localized: "Assistant")
        case .user: String(localized: "Me")
        }
    }
}

/// CEFR levels to choose from; "custom text" is any other string (R-01, A-8).
public enum Levels {
    public static let cefr = ["A1", "A2", "B1", "B2", "C1", "C2"]
}

/// Session settings (R-01, S-01). There are no defaults for role, topic or level (A-8).
public struct SessionSettings: Codable, Sendable, Hashable {
    public var lang: Lang
    public var mode: SessionMode
    public var topic: String
    public var role: String
    public var level: String
    public var customPrompt: String
    public var corrections: Set<CorrectionMode>
    public var starter: Starter
    /// LINGO-08 VR-08: the learner's vocabulary is used in this session. Optional so that old sessions decode unchanged (missing = on).
    public var useVocabulary: Bool?
    /// LINGO-08 VR-09: "My words" — the Questions mode built around the vocabulary (6 targets, PR-03).
    public var vocabularyFocus: Bool?
    /// LINGO-08 VR-11: the item chosen with "Practise"; it is the first target while it is a candidate.
    public var pinnedVocab: String?
    /// LINGO-05: a teacher activity (warm-up, scenario, exam). Older builds ignore it and open the session as its stored mode (PX-05).
    public var activity: Activity?
    /// LINGO-09 MR-01: harshness/hostility/profanity. Stored only when its level is ≥ 1; older builds ignore it (MR-45).
    public var tone: Tone? { didSet { tone = Self.normalized(tone) } }

    private static func normalized(_ t: Tone?) -> Tone? { t.flatMap { $0.isActive && (0...5).contains($0.harshness) && (0...5).contains($0.hostility) ? $0 : nil } }

    public init(lang: Lang, mode: SessionMode, topic: String = "", role: String = "", level: String = "",
                customPrompt: String = "", corrections: Set<CorrectionMode> = [], starter: Starter = .assistant,
                useVocabulary: Bool? = nil, vocabularyFocus: Bool? = nil, pinnedVocab: String? = nil, activity: Activity? = nil, tone: Tone? = nil) {
        self.lang = lang
        self.mode = mode
        self.topic = topic
        self.role = role
        self.level = level
        self.customPrompt = customPrompt
        self.corrections = corrections
        self.starter = starter
        self.useVocabulary = useVocabulary
        self.vocabularyFocus = vocabularyFocus
        self.pinnedVocab = pinnedVocab
        self.activity = activity
        self.tone = Self.normalized(tone)
    }

    enum CodingKeys: String, CodingKey {
        case lang, mode, topic, role, level, customPrompt, corrections, starter, useVocabulary, vocabularyFocus, pinnedVocab, activity, tone
    }

    /// As the synthesized decoder, except that `activity` is tolerant: missing, malformed or of an unknown kind → nil (PX-05).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lang = try c.decode(Lang.self, forKey: .lang)
        mode = try c.decode(SessionMode.self, forKey: .mode)
        topic = try c.decode(String.self, forKey: .topic)
        role = try c.decode(String.self, forKey: .role)
        level = try c.decode(String.self, forKey: .level)
        customPrompt = try c.decode(String.self, forKey: .customPrompt)
        corrections = try c.decode(Set<CorrectionMode>.self, forKey: .corrections)
        starter = try c.decode(Starter.self, forKey: .starter)
        useVocabulary = try c.decodeIfPresent(Bool.self, forKey: .useVocabulary)
        vocabularyFocus = try c.decodeIfPresent(Bool.self, forKey: .vocabularyFocus)
        pinnedVocab = try c.decodeIfPresent(String.self, forKey: .pinnedVocab)
        activity = (try? c.decodeIfPresent(Activity.self, forKey: .activity)) ?? nil
        tone = Self.normalized((try? c.decodeIfPresent(Tone.self, forKey: .tone)) ?? nil)
    }

    public var examKind: ExamKind? { activity?.kind == .exam ? activity?.exam.flatMap(ExamKind.init(rawValue:)) : nil }
    public var canResume: Bool { examKind == nil }

    /// The catalogue id of a scenario session (SR-02), nil for other sessions.
    public var scenarioID: String? { activity?.kind == .scenario ? activity?.id : nil }

    /// The scenario of a scenario session: the learner's own copy stored in the session, else the catalogue entry.
    public var scenario: Scenario? {
        guard let id = scenarioID else { return nil }
        if let c = activity?.custom { return c.scenario }
        return ScenarioCatalog.scenario(id)
    }

    /// The frozen card queue of a warm-up (WR-01), nil for other sessions.
    public var warmupCards: [String]? { activity?.kind == .warmup ? activity?.cards : nil }

    /// "My words" (VR-09).
    public var isVocabularyFocus: Bool { vocabularyFocus == true && mode == .questions }
    /// The vocabulary is used: always with the focus, otherwise unless switched off (VR-08).
    public var vocabularyOn: Bool { isVocabularyFocus || useVocabulary != false }

    /// "Practise" on an item (VR-11): a "My words" session in the item's language with the item first; the assistant opens.
    public static func myWords(for item: VocabItem, corrections: Set<CorrectionMode>) -> SessionSettings {
        SessionSettings(lang: item.lang, mode: .questions, corrections: corrections.isEmpty ? [.inline] : corrections,
                        starter: .assistant, vocabularyFocus: true, pinnedVocab: item.id)
    }

    /// The "My words" checkbox of the new-session screen (VR-09): on forces Questions with the focus, off clears the focus.
    public func withWordsMode(_ on: Bool) -> SessionSettings {
        var s = self
        if on { s.mode = .questions; s.vocabularyFocus = true } else { s.vocabularyFocus = nil }
        return s
    }

    /// The per-session switch (VR-08): off stores `false`, on removes the field (missing = on). A "My words" session keeps it on.
    public func togglingVocabulary() -> SessionSettings {
        guard !isVocabularyFocus else { return self }
        var s = self
        s.useVocabulary = vocabularyOn ? false : nil
        return s
    }

    /// Default title: "<Mode>: <topic>" (R-01).
    public var defaultTitle: String {
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = isVocabularyFocus ? String(localized: "My words") : mode.title
        return t.isEmpty ? name : "\(name): \(t)"
    }

    /// Ordinary sessions need a correction mode (S-01, A-3) and custom prompts need text (R-03).
    /// Exams store "after" themselves, so their picker needs no correction choice (PX-05).
    public var canStart: Bool {
        if examKind != nil { return true }
        guard !corrections.isEmpty else { return false }
        if mode == .customPrompt {
            return !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    /// Header subtitle: "<mode> in <language>" (R-40).
    public var subtitle: String {
        switch activity?.kind {
        case .warmup: "\(String(localized: "Warm-up")) \(lang.inLanguagePhrase)"
        case .scenario: "\(String(localized: "Scenario")) \(lang.inLanguagePhrase)"
        default: "\(mode.title) \(lang.inLanguagePhrase)"
        }
    }
}

/// A teacher activity of a session (LINGO-05 WR-01, SR-02, XR-02). Only the fields of its kind are set.
public struct Activity: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case warmup, scenario, exam }
    public var kind: Kind
    /// Warm-up: the frozen queue of card ids.
    public var cards: [String]?
    /// Scenario: the catalogue id.
    public var id: String?
    /// Exam: "goethe_b1" or "ielts", and the tasks drawn at the start.
    public var exam: String?
    public var tasks: [String]?
    /// LINGO-10 BR-01: Goethe exam format ("mock" or "training"), the Teil of a training, the partner's talk of a mock.
    public enum Format: String, Codable, Sendable { case mock, training }
    public var format: Format?
    public var teil: Int?
    public var partnerTask: String?
    /// Scenario: the learner's own scenario (its id equals `id`); nil for a catalogue scenario.
    public var custom: CustomScenario?

    public init(kind: Kind, cards: [String]? = nil, id: String? = nil, exam: String? = nil, tasks: [String]? = nil,
                format: Format? = nil, teil: Int? = nil, partnerTask: String? = nil, custom: CustomScenario? = nil) {
        self.kind = kind; self.cards = cards; self.id = id; self.exam = exam; self.tasks = tasks
        self.format = format; self.teil = teil; self.partnerTask = partnerTask; self.custom = custom
    }

    public static func warmup(_ cards: [String]) -> Activity { Activity(kind: .warmup, cards: cards) }

    enum CodingKeys: String, CodingKey { case kind, cards, id, exam, tasks, format, teil, partnerTask, custom }

    /// Malformed content for its kind throws, so `SessionSettings` decodes it as no activity (PX-05).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        cards = try c.decodeIfPresent([String].self, forKey: .cards)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        exam = try c.decodeIfPresent(String.self, forKey: .exam)
        tasks = try c.decodeIfPresent([String].self, forKey: .tasks)
        // An unknown format value throws (no activity); so does a field of the wrong type.
        format = try c.decodeIfPresent(Format.self, forKey: .format)
        teil = try c.decodeIfPresent(Int.self, forKey: .teil)
        partnerTask = try c.decodeIfPresent(String.self, forKey: .partnerTask)
        custom = try c.decodeIfPresent(CustomScenario.self, forKey: .custom)
        let valid: Bool
        switch kind {
        case .warmup: valid = !(cards ?? []).isEmpty
        case .scenario: valid = !(id ?? "").isEmpty && custom.map { $0.id == id && $0.isValid } ?? true
        case .exam:
            valid = exam.flatMap(ExamKind.init(rawValue:)).map {
                ExamCatalog.valid($0, ids: tasks ?? [], format: format, teil: teil, partnerTask: partnerTask)
            } ?? false
        }
        guard valid else { throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "activity without its fields") }
    }
}
