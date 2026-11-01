import Foundation

/// A practice situation (LINGO-05 SR-01). Texts in the study language were written for Lingo; titles also in English and Russian
/// for the interface. `packages/contracts/teacher/scenarios.json` is written from this catalogue by the tests.
public struct Scenario: Codable, Sendable, Hashable, Identifiable {
    public struct Phrase: Codable, Sendable, Hashable {
        public var text: String
        public var translation: String
    }
    public var id: String
    public var lang: Lang
    /// The title in the study language (the session topic, which older builds show).
    public var title: String
    public var title_en: String
    public var title_ru: String
    /// A2 | B1 | B2.
    public var level: String
    /// Lingo's role, study language.
    public var role: String
    public var situation: String
    /// 3–5 things the learner should get done, in order.
    public var tasks: [String]
    public var phrases: [Phrase]

    public static let levels = ["A2", "B1", "B2"]
    public static let roleLimit = 80, situationLimit = 300, taskLimit = 120
}

public enum ScenarioCatalog {
    public static func scenario(_ id: String) -> Scenario? { all.first { $0.id == id } }
    public static func scenarios(lang: Lang) -> [Scenario] { all.filter { $0.lang == lang } }

    private static func s(_ id: String, _ lang: Lang, _ level: String, _ title: String, en: String, ru: String, role: String,
                          situation: String, tasks: [String], phrases: [(String, String)]) -> Scenario {
        Scenario(id: id, lang: lang, title: title, title_en: en, title_ru: ru, level: level, role: role, situation: situation, tasks: tasks,
                 phrases: phrases.map { Scenario.Phrase(text: $0.0, translation: $0.1) })
    }

    public static let all: [Scenario] = [
        // German: life in Germany.
        s("de-doctor", .de, "A2", "Beim Hausarzt", en: "At the GP", ru: "У терапевта",
          role: "Ärztin in einer Hausarztpraxis",
          situation: "Sie haben seit drei Tagen Halsschmerzen und Fieber. Sie sind zum ersten Mal in dieser Praxis, und morgen müssten Sie eigentlich arbeiten.",
          tasks: ["Beschreiben Sie Ihre Beschwerden und seit wann Sie sie haben.",
                  "Beantworten Sie die Fragen nach Allergien und Medikamenten.",
                  "Bitten Sie um eine Krankschreibung für Ihren Arbeitgeber.",
                  "Fragen Sie, wie und wie oft Sie das Medikament nehmen sollen."],
          phrases: [("Ich habe seit drei Tagen Halsschmerzen.", "У меня три дня болит горло."),
                    ("Ich habe leichtes Fieber.", "У меня небольшая температура."),
                    ("Könnten Sie mich bitte krankschreiben?", "Не могли бы вы выписать мне больничный?"),
                    ("Wie oft soll ich die Tabletten nehmen?", "Как часто мне принимать таблетки?")]),
        s("de-anmeldung", .de, "A2", "Wohnsitz anmelden", en: "Registering your address", ru: "Регистрация по месту жительства",
          role: "Sachbearbeiter im Bürgeramt",
          situation: "Sie sind vor einer Woche umgezogen und haben einen Termin im Bürgeramt. Die Wohnungsgeberbestätigung haben Sie leider zu Hause vergessen.",
          tasks: ["Sagen Sie, warum Sie da sind.",
                  "Erklären Sie, dass ein Dokument fehlt, und finden Sie eine Lösung.",
                  "Nennen Sie Ihre neue Adresse und das Einzugsdatum.",
                  "Fragen Sie, wann und wie Sie die Meldebescheinigung bekommen."],
          phrases: [("Ich möchte meinen neuen Wohnsitz anmelden.", "Я хочу зарегистрировать новое место жительства."),
                    ("Die Wohnungsgeberbestätigung habe ich leider vergessen.", "Подтверждение от арендодателя я, к сожалению, забыл."),
                    ("Kann ich das Dokument per E-Mail nachreichen?", "Можно прислать документ позже по электронной почте?"),
                    ("Ich bin letzte Woche eingezogen.", "Я въехал на прошлой неделе.")]),
        s("de-auslaenderbehoerde", .de, "B1", "Aufenthaltstitel verlängern", en: "Extending a residence permit", ru: "Продление вида на жительство",
          role: "Sachbearbeiterin in der Ausländerbehörde",
          situation: "Ihr Aufenthaltstitel läuft in drei Wochen ab. Sie haben einen Termin, aber der aktuelle Gehaltsnachweis fehlt noch, weil Ihr Arbeitgeber ihn erst nächste Woche schickt.",
          tasks: ["Erklären Sie Ihr Anliegen und wann Ihr Titel abläuft.",
                  "Sagen Sie, welches Dokument fehlt und warum.",
                  "Fragen Sie nach der Frist für die fehlenden Unterlagen.",
                  "Fragen Sie, ob Sie bis zur Entscheidung eine Fiktionsbescheinigung bekommen."],
          phrases: [("Ich möchte meinen Aufenthaltstitel verlängern.", "Я хочу продлить вид на жительство."),
                    ("Mein Titel läuft in drei Wochen ab.", "Мой ВНЖ истекает через три недели."),
                    ("Bis wann muss ich die Unterlagen nachreichen?", "До какого срока нужно донести документы?"),
                    ("Bekomme ich eine Fiktionsbescheinigung?", "Мне выдадут временное удостоверение (Fiktionsbescheinigung)?")]),
        s("de-besichtigung", .de, "B1", "Wohnungsbesichtigung", en: "Flat viewing", ru: "Осмотр квартиры",
          role: "Vermieterin einer Zweizimmerwohnung",
          situation: "Sie besichtigen eine Zweizimmerwohnung in Ihrer Stadt. Es gibt viele Interessenten, und die Vermieterin möchte schnell entscheiden.",
          tasks: ["Stellen Sie sich kurz vor: Beruf und warum Sie umziehen.",
                  "Fragen Sie nach der Warmmiete und den Nebenkosten.",
                  "Klären Sie, ob eine Katze erlaubt ist.",
                  "Vereinbaren Sie, welche Unterlagen Sie schicken und bis wann."],
          phrases: [("Wie hoch sind die Nebenkosten?", "Сколько составляют коммунальные платежи?"),
                    ("Ist die Miete warm oder kalt?", "Аренда с отоплением или без?"),
                    ("Sind Haustiere erlaubt?", "Можно ли держать домашних животных?"),
                    ("Ich kann Ihnen die Unterlagen heute Abend schicken.", "Я могу прислать вам документы сегодня вечером.")]),
        s("de-bank", .de, "A2", "Ein Girokonto eröffnen", en: "Opening a bank account", ru: "Открытие счёта в банке",
          role: "Bankberater in einer Filiale",
          situation: "Sie haben eine neue Arbeit und brauchen ein Girokonto für Ihr Gehalt. Sie haben Ihren Pass und die Meldebescheinigung dabei.",
          tasks: ["Sagen Sie, dass Sie ein Konto eröffnen möchten.",
                  "Fragen Sie, welche Dokumente nötig sind.",
                  "Fragen Sie nach den Kontoführungsgebühren.",
                  "Fragen Sie nach der Karte und dem Online-Banking."],
          phrases: [("Ich möchte ein Girokonto eröffnen.", "Я хочу открыть текущий счёт."),
                    ("Welche Unterlagen brauchen Sie von mir?", "Какие документы вам от меня нужны?"),
                    ("Kostet das Konto etwas?", "Счёт платный?"),
                    ("Wann bekomme ich die Bankkarte?", "Когда я получу банковскую карту?")]),
        s("de-reklamation", .de, "B1", "Reklamation im Geschäft", en: "Returning a faulty product", ru: "Возврат неисправного товара",
          role: "Verkäufer in einem Elektronikmarkt",
          situation: "Sie haben vor einer Woche Kopfhörer gekauft. Seit gestern funktioniert die linke Seite nicht mehr. Den Kassenbon haben Sie dabei.",
          tasks: ["Beschreiben Sie das Problem genau.",
                  "Zeigen Sie den Kassenbon und sagen Sie, wann Sie gekauft haben.",
                  "Verlangen Sie einen Umtausch oder Ihr Geld zurück.",
                  "Reagieren Sie auf den Vorschlag des Verkäufers und einigen Sie sich."],
          phrases: [("Die linke Seite funktioniert nicht mehr.", "Левый наушник больше не работает."),
                    ("Hier ist der Kassenbon.", "Вот чек."),
                    ("Ich möchte die Kopfhörer umtauschen.", "Я хочу обменять наушники."),
                    ("Ich hätte lieber mein Geld zurück.", "Я бы предпочёл вернуть деньги.")]),
        s("de-zug", .de, "B1", "Zug fällt aus", en: "A cancelled train", ru: "Поезд отменили",
          role: "Mitarbeiterin im Reisezentrum am Bahnhof",
          situation: "Ihr Zug nach München ist ausgefallen, und Sie verpassen Ihren Anschlusszug zu einem wichtigen Termin. Sie gehen ins Reisezentrum.",
          tasks: ["Erklären Sie die Situation und wohin Sie müssen.",
                  "Fragen Sie nach der schnellsten Alternative.",
                  "Fragen Sie, ob Sie eine Entschädigung bekommen.",
                  "Bitten Sie um eine Bestätigung für Ihren Arbeitgeber."],
          phrases: [("Mein Zug ist ausgefallen.", "Мой поезд отменили."),
                    ("Ich verpasse meinen Anschluss.", "Я опаздываю на пересадку."),
                    ("Gibt es eine andere Verbindung?", "Есть другой вариант?"),
                    ("Kann ich eine Bestätigung bekommen?", "Можно получить подтверждение?")]),
        // German: work.
        s("de-vorstellung", .de, "B1", "Vorstellungsgespräch", en: "Job interview", ru: "Собеседование",
          role: "Personalleiterin eines mittelgroßen Unternehmens",
          situation: "Sie haben sich als Mitarbeiter im Kundenservice beworben. Das Gespräch findet vor Ort statt und dauert etwa zwanzig Minuten.",
          tasks: ["Stellen Sie sich vor und sagen Sie, warum Sie sich beworben haben.",
                  "Beschreiben Sie eine Situation aus Ihrer bisherigen Arbeit.",
                  "Nennen Sie eine Stärke und eine Schwäche.",
                  "Stellen Sie eine Frage zum Team oder zu den Arbeitszeiten."],
          phrases: [("Ich habe drei Jahre im Kundenservice gearbeitet.", "Я три года работал в службе поддержки."),
                    ("Meine Stärke ist, dass ich ruhig bleibe.", "Моя сильная сторона — я сохраняю спокойствие."),
                    ("Ich arbeite noch an meinem Deutsch.", "Я ещё работаю над своим немецким."),
                    ("Wie sieht ein typischer Arbeitstag aus?", "Как выглядит обычный рабочий день?")]),
        s("de-meeting", .de, "B2", "Teambesprechung", en: "Team meeting", ru: "Совещание команды",
          role: "Teamleiter in einer wöchentlichen Besprechung",
          situation: "In der wöchentlichen Besprechung sollen Sie über Ihr Projekt berichten. Ein Lieferant ist zu spät, deshalb wird ein Termin knapp.",
          tasks: ["Berichten Sie kurz über den Stand Ihres Projekts.",
                  "Erklären Sie das Problem mit der Verspätung.",
                  "Machen Sie einen Vorschlag, wie das Team reagieren kann.",
                  "Übernehmen Sie eine Aufgabe und nennen Sie einen Termin."],
          phrases: [("Kurz zum Stand meines Projekts:", "Коротко о статусе моего проекта:"),
                    ("Leider hat sich die Lieferung verzögert.", "К сожалению, поставка задержалась."),
                    ("Ich schlage vor, dass wir …", "Я предлагаю, чтобы мы …"),
                    ("Ich kümmere mich bis Freitag darum.", "Я займусь этим до пятницы.")]),
        // English: work and travel.
        s("en-interview", .en, "B1", "Job interview", en: "Job interview", ru: "Собеседование",
          role: "hiring manager at a software company",
          situation: "You applied for a job in an international team. The interview is a video call and takes about twenty minutes.",
          tasks: ["Introduce yourself and say why you applied.",
                  "Describe a project you are proud of.",
                  "Answer the question about a weakness.",
                  "Ask a question about the team or the next steps."],
          phrases: [("I've been working as … for three years.", "Я работаю … уже три года."),
                    ("One project I'm proud of is …", "Один проект, которым я горжусь, — …"),
                    ("I'm working on being more concise.", "Я работаю над тем, чтобы говорить короче."),
                    ("What are the next steps?", "Какие следующие шаги?")]),
        s("en-meeting", .en, "B1", "Weekly meeting", en: "Weekly meeting", ru: "Еженедельное совещание",
          role: "project manager leading the weekly meeting",
          situation: "In the weekly meeting you give an update on your task. A colleague's part is late, so your deadline is at risk.",
          tasks: ["Give a short update on your task.",
                  "Explain the risk to the deadline.",
                  "Suggest a solution.",
                  "Agree on who does what and by when."],
          phrases: [("Quick update on my side:", "Коротко по моей части:"),
                    ("There's a risk we'll miss the deadline.", "Есть риск, что мы не успеем к сроку."),
                    ("What if we …?", "А что если мы …?"),
                    ("I can have it ready by Thursday.", "Я могу подготовить это к четвергу.")]),
        s("en-small-talk", .en, "A2", "Small talk at work", en: "Small talk at work", ru: "Разговор с коллегой",
          role: "a friendly colleague at the coffee machine",
          situation: "It is Monday morning. A colleague from another team is at the coffee machine and starts a conversation.",
          tasks: ["Say how your weekend was.",
                  "Ask about the colleague's plans.",
                  "Recommend something: a place, a film or a book.",
                  "End the conversation politely."],
          phrases: [("How was your weekend?", "Как прошли выходные?"),
                    ("Have you got any plans for the week?", "Есть планы на неделю?"),
                    ("You should try …", "Тебе стоит попробовать …"),
                    ("Anyway, I'd better get back to work.", "Ладно, мне пора возвращаться к работе.")]),
        s("en-phone", .en, "B1", "Rescheduling by phone", en: "Rescheduling by phone", ru: "Перенос записи по телефону",
          role: "receptionist at a dental clinic",
          situation: "You have a dentist appointment tomorrow at ten, but you have to work. You call the clinic to move it.",
          tasks: ["Say who you are and why you are calling.",
                  "Suggest two other times.",
                  "Spell your surname.",
                  "Confirm the new date and time."],
          phrases: [("I'm calling to reschedule my appointment.", "Я звоню, чтобы перенести запись."),
                    ("Would Thursday afternoon work?", "Подойдёт четверг после обеда?"),
                    ("Let me spell that for you.", "Давайте я продиктую по буквам."),
                    ("So that's Thursday at three, right?", "Значит, в четверг в три, верно?")]),
        s("en-airport", .en, "A2", "Check-in at the airport", en: "Check-in at the airport", ru: "Регистрация в аэропорту",
          role: "airline check-in agent",
          situation: "You are checking in for a flight to London. Your suitcase is a little heavier than allowed and you would like a window seat.",
          tasks: ["Give your destination and passport.",
                  "Deal with the heavy suitcase.",
                  "Ask for a window seat.",
                  "Ask about the gate and boarding time."],
          phrases: [("I'm flying to London.", "Я лечу в Лондон."),
                    ("Can I take something out of the suitcase?", "Можно я достану что-то из чемодана?"),
                    ("Could I have a window seat, please?", "Можно место у окна?"),
                    ("What time does boarding start?", "Во сколько начинается посадка?")]),
        s("en-doctor", .en, "A2", "At the doctor's", en: "At the doctor's", ru: "У врача",
          role: "general practitioner",
          situation: "You have had a bad cough for a week and you cannot sleep well. You are seeing a doctor for the first time in this city.",
          tasks: ["Describe your symptoms and how long you have had them.",
                  "Answer the questions about allergies and medicine.",
                  "Ask if you need a sick note.",
                  "Ask how to take the medicine."],
          phrases: [("I've had a bad cough for a week.", "У меня неделю сильный кашель."),
                    ("I'm not allergic to anything.", "У меня нет аллергии."),
                    ("Do I need a sick note?", "Мне нужен больничный?"),
                    ("How often should I take it?", "Как часто это принимать?")]),
    ]
}

public extension Scenario {
    /// A scenario session (SR-02): "Free conversation" with the role and the title as topic for older builds.
    func settings(corrections: Set<CorrectionMode>, level: String = "") -> SessionSettings {
        SessionSettings(lang: lang, mode: .free, topic: title, role: role, level: level.isEmpty ? self.level : level,
                        corrections: corrections.isEmpty ? [.inline] : corrections, starter: .assistant, activity: Activity(kind: .scenario, id: id))
    }

    /// A completed task number from a reply's `@task` lines: the leading digits, within 1…tasks.count.
    func completedTasks(in reply: String) -> [Int] {
        // "@task: 0" and negative numbers are not tasks.
        ReplyProtocol.silentValues(reply, tag: "task").compactMap { Int($0.prefix { $0.isNumber }) }.filter { (1...tasks.count).contains($0) }
    }
}

public extension HistoryState {
    /// A scenario is done when one live session of it has all its tasks recorded (SR-03).
    func scenarioDone(_ id: String) -> Bool {
        guard let sc = ScenarioCatalog.scenario(id) else { return false }
        return sessions.values.contains { s in
            !s.deleted && s.settings.scenarioID == id && Set(scenarioTasks[s.id] ?? []).isSuperset(of: Set(1...sc.tasks.count))
        }
    }

    /// The level the learner chose last in a language: the newest live ordinary session (not a warm-up, scenario or exam) with a level;
    /// "" when none. Teacher sessions store levels the learner did not choose, so they never count.
    func learnerChosenLevel(lang: Lang) -> String {
        sessions.values.filter { !$0.deleted && $0.settings.lang == lang && $0.settings.activity == nil
            && !$0.settings.level.trimmingCharacters(in: .whitespaces).isEmpty }
            .max { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }?.settings.level ?? ""
    }

    /// The learner's level in a language (GR-03): the chosen level (above) on the catalogue scale; A1, none or custom text → A2,
    /// C1/C2 → B2.
    func learnerLevel(lang: Lang) -> String {
        switch learnerChosenLevel(lang: lang).trimmingCharacters(in: .whitespaces).uppercased() {
        case "B1": return "B1"
        case "B2", "C1", "C2": return "B2"
        default: return "A2"
        }
    }

    /// The first scenario in catalogue order not done yet at the learner's level, else at the nearest lower level (GR-03).
    func nextScenario(lang: Lang) -> Scenario? {
        let level = learnerLevel(lang: lang)
        let order = Array(Scenario.levels.prefix { $0 != level } + [level]).reversed()
        for l in order {
            if let sc = ScenarioCatalog.scenarios(lang: lang).first(where: { $0.level == l && !scenarioDone($0.id) }) { return sc }
        }
        return nil
    }
}
