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

    public init(lang: Lang, mode: SessionMode, topic: String = "", role: String = "", level: String = "",
                customPrompt: String = "", corrections: Set<CorrectionMode> = [], starter: Starter = .assistant,
                useVocabulary: Bool? = nil, vocabularyFocus: Bool? = nil, pinnedVocab: String? = nil) {
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
    }

    /// "My words" (VR-09).
    public var isVocabularyFocus: Bool { vocabularyFocus == true && mode == .questions }
    /// The vocabulary is used: always with the focus, otherwise unless switched off (VR-08).
    public var vocabularyOn: Bool { isVocabularyFocus || useVocabulary != false }

    /// Default title: "<Mode>: <topic>" (R-01).
    public var defaultTitle: String {
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = isVocabularyFocus ? String(localized: "My words") : mode.title
        return t.isEmpty ? name : "\(name): \(t)"
    }

    /// "Start" is enabled only if at least one correction mode is selected (S-01, A-3),
    /// and for "Custom prompt" the prompt text is not empty (R-03).
    public var canStart: Bool {
        guard !corrections.isEmpty else { return false }
        if mode == .customPrompt {
            return !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    /// Header subtitle: "<mode> in <language>" (R-40).
    public var subtitle: String { "\(mode.title) \(lang.inLanguagePhrase)" }
}
