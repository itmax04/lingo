import Foundation
import LingoCore

/// Synthetic redesign evidence. This data never reads or writes the learner's journal.
@MainActor
enum Fixtures {
    static let original = "Ich habe seit zwei Tage Kopfschmerzen."
    static let corrected = "Ich habe seit zwei Tagen Kopfschmerzen."
    static let russianExplanation = "После seit нужен дательный падеж: seit zwei Tagen."
    static let rule = "Nach seit steht der Dativ."
    static func fill(_ m: AppModel, now: Date = Date(timeIntervalSince1970: 1793109600)) {
        let settings = SessionSettings(lang: .de, mode: .customPrompt, topic: "Beim Arzt", level: "B1", corrections: [.inline])
        m.sessions = [
            Session(id: "s1", title: String(localized: "At the doctor"), settings: settings, createdAt: now, lastActivity: now),
            Session(id: "s2", title: "IELTS Part 2", settings: SessionSettings(lang: .en, mode: .free), createdAt: now, lastActivity: now),
            Session(id: "s3", title: String(localized: "Work: interview"), settings: settings, createdAt: now, lastActivity: now)
        ]
        m.selectedSessionID = "s1"
        m.section = .conversations
        m.langFilter = .de
        m.messages = [
            ChatMessage(id: "m1", session: "s1", role: .assistant, text: "", lang: .de,
                        segments: [.say(.de, "Guten Morgen! Was führt Sie heute zu mir?")], createdAt: now),
            ChatMessage(id: "m2", session: "s1", role: .user, text: original, lang: .de, createdAt: now, synced: true),
            ChatMessage(id: "m3", session: "s1", role: .assistant, text: "", lang: .de,
                        segments: [.say(.de, "Das tut mir leid. Haben Sie auch Fieber?"),
                                   .fix(Fix(original: original, corrected: corrected, rule: rule))], createdAt: now)
        ]
        m.phrases = [
            Phrase(lang: .de, text: "Ich habe Kopfschmerzen.", translation: "У меня болит голова.", source: .topic),
            Phrase(lang: .de, text: "Seit wann haben Sie Fieber?", translation: "С какого времени у вас температура?", source: .topic)
        ]
        m.voiceState = .speaking
        m.levels = (0..<64).map { 0.1 + 0.7 * abs(sin(Float($0) * 0.3)) }
        m.sourceLabel = "Groq · 120b"
        m.hasKey = true
        m.online = true
        m.syncStatus = String(localized: "Saved on this Mac")
    }
}
