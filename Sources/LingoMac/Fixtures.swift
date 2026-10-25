import Foundation
import LingoCore

/// Синтетические данные для P-01 и снимков интерфейса: сессии и сообщения как на макете `lingo-mac.webp`.
/// Имя «Alex» — обезличенное (evals/README.md).
@MainActor
enum Fixtures {
    static func fill(_ m: AppModel, now: Date = Date()) {
        let cal = Calendar.current
        func day(_ month: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
            var c = cal.dateComponents([.year], from: now)
            c.month = month; c.day = d; c.hour = h; c.minute = min
            return cal.date(from: c) ?? now
        }
        let today = cal.date(bySettingHour: 14, minute: 28, second: 0, of: now) ?? now
        func s(_ id: String, _ title: String, _ date: Date, mode: SessionMode = .free, topic: String = "") -> Session {
            Session(id: id, title: title, settings: SessionSettings(lang: .en, mode: mode, topic: topic, level: "B1",
                                                                     corrections: [.inline]),
                    createdAt: date, lastActivity: date)
        }
        m.sessions = [
            Session(id: "s1", title: "Практика: знакомство",
                    settings: SessionSettings(lang: .en, mode: .free, topic: "знакомство", level: "B1", corrections: [.inline]),
                    createdAt: today, lastActivity: today),
            s("s2", "В кафе", day(5, 12, 17, 3)),
            s("s3", "Путешествия", day(5, 10, 11, 20)),
            s("s4", "Работа и карьера", day(5, 8, 16, 45)),
            s("s5", "Повседневные ситуации", day(5, 5, 9, 12)),
            s("s6", "Аэропорт", day(5, 2, 20, 18)),
            s("s7", "Планы на выходные", day(4, 28, 14, 6)),
        ]
        m.selectedSessionID = "s1"
        let t1 = today, t2 = today.addingTimeInterval(60)
        m.messages = [
            ChatMessage(id: "m1", session: "s1", role: .user, text: "How do I introduce myself naturally?", lang: .en,
                        createdAt: t1, synced: true),
            ChatMessage(id: "m2", session: "s1", role: .assistant, text: "", lang: .en,
                        segments: [.say(.en, "You can say: “Hi, I’m Alex. Nice to meet you.”")], createdAt: t1),
            ChatMessage(id: "m3", session: "s1", role: .user, text: "А можно медленнее?", lang: .ru, createdAt: t2, synced: true),
            ChatMessage(id: "m4", session: "s1", role: .assistant, text: "", lang: .en,
                        segments: [.say(.en, "Конечно. Повторим по частям.")], createdAt: t2),
        ]
        m.phrases = [
            Phrase(lang: .en, text: "Nice to meet you.", translation: "Приятно познакомиться.", source: .topic),
            Phrase(lang: .en, text: "I’m Alex.", translation: "Меня зовут Алекс.", source: .topic),
        ]
        m.voiceState = .listening
        m.levels = (0..<64).map { i in
            let x = Float(i) / 63
            let env = max(0, 1 - abs(x - 0.45) * 2.6)
            return 0.12 + env * (0.55 + 0.4 * abs(sin(Float(i) * 1.7)))
        }
        m.sourceLabel = "На устройстве"
        m.online = true
        m.syncStatus = "Синхронизировано в 14:28"
    }
}
