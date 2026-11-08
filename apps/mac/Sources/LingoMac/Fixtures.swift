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
        // My vocabulary (LINGO-08 VR-11): synthetic items, two ★ phrases as on the design reference.
        m.vocabulary = [
            VocabItem(id: VocabItem.starredID(lang: .de, text: "Ich habe Kopfschmerzen."), lang: .de, text: "Ich habe Kopfschmerzen.",
                      translation: "У меня болит голова.", source: .starred, createdAt: now, offered: 2, used: 1),
            VocabItem(id: "01JVOCABFEIERABEND00000000", lang: .de, text: "Feierabend", translation: "конец рабочего дня",
                      note: "nach der Arbeit", source: .manual, createdAt: now.addingTimeInterval(-60), offered: 3, used: 2),
            VocabItem(id: "01JVOCABVERABREDEN00000000", lang: .de, text: "sich verabreden", translation: "договориться о встрече",
                      source: .list, createdAt: now.addingTimeInterval(-120), offered: 1, used: 0, mistakes: 1),
            VocabItem(id: VocabItem.starredID(lang: .en, text: "Nice to meet you."), lang: .en, text: "Nice to meet you.",
                      translation: "Приятно познакомиться.", source: .starred, createdAt: now),
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

    static func exam(_ model: AppModel, kind: ExamKind, phase: ExamPhase, transcript: Bool = false) {
        let ids = kind == .goetheB1 ? ["b1-plan-park", "b1-talk-bicycle", "b1-discuss-bicycle"]
            : ["ielts-topic-home", "ielts-cue-journey", "ielts-discuss-journey"]
        // Use a validated linked selection, independent of random catalogue draws.
        let tasks = ExamCatalog.validSelection(kind, ids: ids) ? ids : [ExamCatalog.tasks(kind, part: 1)[0].id,
            ExamCatalog.tasks(kind, part: 2)[0].id, ExamCatalog.tasks(kind, part: 3)[0].id]
        let now = Date()
        guard let settings = kind.settings(tasks: tasks), var run = ExamRun(kind: kind, tasks: tasks, now: now) else { return }
        while run.phase != phase { run.advance(expected: run.phase, timeUp: false, turnRunning: false, now: now) }
        model.sessions = [Session(id: "exam-fixture", title: kind.title, settings: settings, createdAt: now, lastActivity: now)]
        model.selectedSessionID = "exam-fixture"
        model.section = .conversations
        model.langFilter = kind.lang
        model.hintsVisible = false
        model.messages = phase.isPreparation ? [] : [ChatMessage(id: "exam-user", session: "exam-fixture", role: .user,
            text: kind == .goetheB1 ? "Ich fahre jeden Tag mit dem Fahrrad zur Arbeit." : "I remember a journey to the mountains with my friends.",
            lang: kind.lang, createdAt: now)]
        model.liveExamSessionID = transcript ? nil : "exam-fixture"
        model.examRun = transcript ? nil : run
        model.examBusy = false
        model.examInputAllowed = run.microphoneAllowed
        model.examFollowUp = false
        model.voiceState = phase.isPreparation || transcript ? .idle : .listening
        model.levels = []
        model.phrases = []
    }

    /// XR-03 screenshots: a finished IELTS exam with a stored debrief, or without one (the failure card).
    static func examDebrief(_ model: AppModel, stored: Bool) {
        exam(model, kind: .ielts, phase: .ielts3, transcript: true)
        model.sessions[0].state = .ended
        guard stored else { return }
        model.messages.append(ChatMessage(id: "exam-debrief", session: "exam-fixture", role: .assistant, text: """
            Fluency and coherence: ответы связные, паузы редкие. Ориентировочный диапазон: B1–B2
            Лексика: хороший выбор слов о путешествиях. Ориентировочный диапазон: B1–B2
            Сильные стороны: ясные примеры; уверенный рассказ
            Что улучшить: I go to mountains → I went to the mountains — прошедшее время
            Это оценка для практики, а не официальный балл.
            """, lang: .ru, createdAt: Date(), kind: .summary))
    }

    /// A synthetic teacher journal for the screenshots (T-4): words to review, 12 minutes of practice today, a goal, a finished
    /// warm-up with one skipped card and one suspended card. Written to the snapshot's temporary journal, never the learner's.
    static func teacherJournal(_ services: AppServices) async -> Bool {
        let e = services.engine, store = services.store
        do {
            try await e.addVocabulary(lang: .de, entries: [("Feierabend", "конец рабочего дня"), ("sich verabreden", "договориться о встрече"),
                                                           ("Termin", "приём, встреча"), ("vereinbaren", "договариваться"),
                                                           ("Kopfschmerzen", "головная боль"), ("Wohnung", "квартира"),
                                                           ("Miete", "арендная плата")], source: .list)
            let practice = try await e.createSession(SessionSettings(lang: .de, mode: .free, topic: "Beim Arzt", corrections: [.after]))
            for i in 0..<13 {
                _ = try await store.append(EventType.messageCreated, session: practice,
                                           Payload.MessageCreated(role: i % 2 == 0 ? .user : .assistant, text: i % 2 == 0 ? "Ich habe seit zwei Tagen Kopfschmerzen." : "Das tut mir leid.", lang: .de),
                                           at: Date().addingTimeInterval(Double(i - 13) * 55))
            }
            guard let w = try await e.startWarmup(lang: .de, corrections: [.inline]) else { return false }
            let queue = await store.state.sessions[w]?.settings.warmupCards ?? []
            _ = try await store.append(EventType.messageCreated, session: w, Payload.MessageCreated(
                role: .assistant, text: "", lang: .de, segments: [.say(.de, "Guten Tag! Wie war dein Feierabend gestern?")]), at: Date().addingTimeInterval(-300))
            _ = try await store.append(EventType.messageCreated, session: w, Payload.MessageCreated(
                role: .user, text: "Nach dem Feierabend habe ich gekocht.", lang: .de), at: Date().addingTimeInterval(-280))
            for (i, r) in [CardRating.good, .hard, .again, .good, .easy].enumerated() where i < queue.count {
                _ = try await store.append(EventType.cardReviewed, session: w, Payload.CardReviewed(card: queue[i], rating: r, message: i == 2 ? "" : "m\(i)"),
                                           at: Date().addingTimeInterval(-270 + Double(i) * 30))
            }
            await e.setCardSuspended(queue.last ?? "", true)
            try await e.setDailyGoal(minutes: 15)
            // A scenario with two of its four tasks done (T-5 screenshots).
            if let sc = try await e.startScenario("de-doctor", corrections: [.inline]) {
                _ = try await store.append(EventType.messageCreated, session: sc, Payload.MessageCreated(
                    role: .assistant, text: "", lang: .de, segments: [.say(.de, "Guten Tag! Was führt Sie zu mir?")]))
                _ = try await store.append(EventType.messageCreated, session: sc, Payload.MessageCreated(
                    role: .user, text: "Ich habe seit drei Tagen Halsschmerzen und Fieber.", lang: .de))
                for n in [1, 2] { _ = try await store.append(EventType.scenarioTask, session: sc, Payload.ScenarioTask(task: n, message: "m")) }
            }
            services.model.apply(await store.state)
            return true
        } catch { return false }
    }

    /// T-7 screenshots: a synthetic busy journal of the last 30 days (practice on most days, four mistake rules, card reviews) and,
    /// optionally, a stored weekly advice. Written to the snapshot's temporary journal, never the learner's.
    static func progressJournal(_ services: AppServices) async -> Bool {
        let e = services.engine, store = services.store
        do {
            try await e.addVocabulary(lang: .de, entries: [("Feierabend", "конец рабочего дня"), ("Termin", "приём, встреча"), ("Wohnung", "квартира"), ("Miete", "арендная плата")], source: .list)
            let de = try await e.createSession(SessionSettings(lang: .de, mode: .free, topic: "Alltag", corrections: [.after]))
            let en = try await e.createSession(SessionSettings(lang: .en, mode: .free, topic: "Work", corrections: [.after]))
            let rules = ["Perfekt mit sein", "Nach seit steht der Dativ", "Artikel: der, die, das", "Wortstellung im Nebensatz"]
            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            var fixCount = 0
            for offset in 0..<30 where offset % 4 != 3 {
                let start = (cal.date(byAdding: .day, value: -offset, to: today) ?? today).addingTimeInterval(19 * 3600)
                // More practice in recent weeks: the chart shows a rising line.
                let turns = offset < 7 ? 14 : offset < 14 ? 10 : 6
                let (sid, lang) = offset % 2 == 0 ? (de, Lang.de) : (en, Lang.en)
                for i in 0..<turns {
                    let at = start.addingTimeInterval(Double(i) * 70)
                    if i % 2 == 0 {
                        let text = lang == .de ? "Ich habe gestern im Park gearbeitet und Freunde besucht." : "I worked in the park yesterday and met my friends."
                        let m = try await store.append(EventType.messageCreated, session: sid, Payload.MessageCreated(role: .user, text: text, lang: lang), at: at)
                        if i % 6 == 0 {
                            let n = fixCount; fixCount += 1
                            // Fewer mistakes per word in the later weeks.
                            if offset < 7 || n % 2 == 0 {
                                try await store.append(EventType.fixRecorded, session: sid, Payload.FixRecorded(message: m.id, fix: Fix(
                                    original: lang == .de ? "ich bin gearbeitet \(n)" : "I goed to work \(n)",
                                    corrected: lang == .de ? "ich habe gearbeitet \(n)" : "I went to work \(n)",
                                    rule: rules[n % rules.count])), at: at.addingTimeInterval(5))
                            }
                        }
                    } else {
                        try await store.append(EventType.messageCreated, session: sid, Payload.MessageCreated(role: .assistant, text: "Gut.", lang: lang), at: at)
                    }
                }
            }
            for (i, text) in ["Feierabend", "Termin", "Wohnung"].enumerated() {
                try await store.append(EventType.cardReviewed, session: de, Payload.CardReviewed(card: "word:de:\(text)", rating: i == 0 ? .good : .easy, message: "m"),
                                       at: Date().addingTimeInterval(-Double(i + 1) * 3600))
            }
            services.model.apply(await store.state)
            return true
        } catch { return false }
    }

    /// Synthetic memory facts and a profile (T-8 screenshots): no personal data.
    static func memoryFacts(_ services: AppServices) async -> Bool {
        do {
            try await services.engine.updateProfile(goals: "Sicher im Alltag und bei der Arbeit sprechen", interests: "Wandern, Kochen, Fotografie")
            for (text, lang) in [("Работает в небольшой IT-компании", "de"), ("Любит ходить в горы по выходным", ""), ("Готовится к экзамену B1 весной", "de"),
                                 ("Хочет свободно говорить на встречах по-английски", "en"), ("Учит язык по вечерам, около получаса", "")] {
                try await services.store.append(EventType.memoryNoted, session: "", Payload.MemoryNoted(text: text, lang: lang))
            }
            services.model.apply(await services.store.state)
            return true
        } catch { return false }
    }

    /// The stored weekly advice of the current ISO week (T-7 screenshots).
    static func weeklyAdvice(_ services: AppServices) async -> Bool {
        do {
            try await services.store.append(EventType.reportWeekly, session: "", Payload.ReportWeekly(
                    week: HistoryState.weekID(Date()),
                    text: "На этой неделе вы занимались почти каждый день и набрали хороший темп: слов стало больше, а ошибок на сто слов меньше. Чаще всего вы путаете вспомогательный глагол в Perfekt, поэтому повторите глаголы движения с sein. Попробуйте три коротких разговора по десять минут и одну разминку в день. В конце недели вернитесь к карточкам со словом Termin."))
            services.model.apply(await services.store.state)
            return true
        } catch { return false }
    }
}

