import Foundation

/// Политика контекста модели (R-04): системная обёртка + краткое содержание + последние N ходов.
/// Ход — реплика пользователя вместе с ответом помощника.
public struct ContextPolicy: Sendable, Hashable, Codable {
    /// N: по умолчанию 8 (Q29, было 20), от 6 до 40.
    public var maxTurns: Int
    /// Краткое содержание обновляется каждые 10 ходов и при завершении сессии.
    public var summaryEvery: Int

    public static let turnsRange: ClosedRange<Int> = 6...40

    /// Бюджет символов расшифровки в запросе (≈ 1800 токенов, R-04 в версии 2.2): старые ходы отбрасываются раньше N.
    public static let transcriptCharBudget = 6300

    public init(maxTurns: Int = 8, summaryEvery: Int = 10) {
        self.maxTurns = maxTurns.clamped(to: Self.turnsRange)
        self.summaryEvery = summaryEvery
    }

    /// Сообщения для `<transcript>`: начиная с N-й с конца реплики пользователя (и первая реплика помощника, если он начинал).
    /// Служебные сообщения (итог, ошибки цепочки) в контекст не идут.
    public func window(_ messages: [ChatMessage]) -> [ChatMessage] {
        let real = messages.filter { $0.kind == .normal }
        let userIdx = real.indices.filter { real[$0].role == .user }
        var w = userIdx.count > maxTurns ? Array(real[userIdx[userIdx.count - maxTurns]...]) : real
        // Бюджет по символам: убираем самые старые ходы, но последний ход остаётся всегда.
        func size(_ m: [ChatMessage]) -> Int { m.reduce(0) { $0 + ($1.role == .assistant ? $1.spokenText.count + 40 : $1.text.count) + 24 } }
        while size(w) > Self.transcriptCharBudget, let next = w.dropFirst().firstIndex(where: { $0.role == .user }) {
            w = Array(w[next...])
        }
        return w
    }

    /// Сколько ходов (реплик пользователя) после последнего краткого содержания.
    public func turnsSinceSummary(_ messages: [ChatMessage], through: String?) -> Int {
        let real = messages.filter { $0.kind == .normal }
        var after = real[...]
        if let t = through, let i = real.firstIndex(where: { $0.id == t }) { after = real[(i + 1)...] }
        return after.filter { $0.role == .user }.count
    }

    public func needsSummary(_ messages: [ChatMessage], through: String?) -> Bool {
        turnsSinceSummary(messages, through: through) >= summaryEvery
    }

    /// Подсказка в шапке (S-16): интерфейс не обещает, что модель помнит всё.
    public func memoryNote() -> String {
        "Помощник помнит краткое содержание и последние \(maxTurns) реплик"
    }
}
