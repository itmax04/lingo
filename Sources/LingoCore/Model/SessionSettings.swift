import Foundation

/// Режим сессии (R-03).
public enum SessionMode: String, Codable, Sendable, CaseIterable, Hashable {
    case questions, free, customPrompt = "custom"

    public var title: String {
        switch self {
        case .questions: "Вопросы"
        case .free: "Свободный разговор"
        case .customPrompt: "Свой промпт"
        }
    }
}

/// Режимы исправления (R-20). Возможно любое непустое сочетание.
public enum CorrectionMode: String, Codable, Sendable, CaseIterable, Hashable, Comparable {
    case inline, after, onDemand = "on_demand"

    public var title: String {
        switch self {
        case .inline: "По ходу"
        case .after: "После разговора"
        case .onDemand: "По запросу"
        }
    }

    public static func < (a: CorrectionMode, b: CorrectionMode) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// Кто начинает разговор (S-01).
public enum Starter: String, Codable, Sendable, CaseIterable, Hashable {
    case assistant, user

    public var title: String {
        switch self {
        case .assistant: "Помощник"
        case .user: "Я"
        }
    }
}

/// Уровни CEFR для выбора; «свой текст» — любая другая строка (R-01, A-8).
public enum Levels {
    public static let cefr = ["A1", "A2", "B1", "B2", "C1", "C2"]
}

/// Настройки сессии (R-01, S-01). Значений по умолчанию для роли, темы и уровня нет (A-8).
public struct SessionSettings: Codable, Sendable, Hashable {
    public var lang: Lang
    public var mode: SessionMode
    public var topic: String
    public var role: String
    public var level: String
    public var customPrompt: String
    public var corrections: Set<CorrectionMode>
    public var starter: Starter

    public init(lang: Lang, mode: SessionMode, topic: String = "", role: String = "", level: String = "",
                customPrompt: String = "", corrections: Set<CorrectionMode> = [], starter: Starter = .assistant) {
        self.lang = lang
        self.mode = mode
        self.topic = topic
        self.role = role
        self.level = level
        self.customPrompt = customPrompt
        self.corrections = corrections
        self.starter = starter
    }

    /// Название по умолчанию: «<Режим>: <тема>» (R-01).
    public var defaultTitle: String {
        let t = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? mode.title : "\(mode.title): \(t)"
    }

    /// «Начать» активна, только если выбран хотя бы один режим исправления (S-01, A-3),
    /// а для «Своего промпта» текст промпта не пустой (R-03).
    public var canStart: Bool {
        guard !corrections.isEmpty else { return false }
        if mode == .customPrompt {
            return !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    /// Подзаголовок шапки: «<режим> на <языке>» (R-40).
    public var subtitle: String { "\(mode.title) \(lang.russianPrepositional)" }
}
