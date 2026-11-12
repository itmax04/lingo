import Foundation

/// Original Lingo practice material (XR-01), exported to contracts by ExamTests.
public struct ExamTask: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var exam: ExamKind
    public var part: Int
    public var task: String
    /// Goethe planning points / five slide titles; IELTS cue-card prompts are in `task`.
    public var points: [String]
    public var questions: [String]
    /// Part 3 is linked to this Part 2 id; Part 2's one IELTS follow-up is in `questions`.
    public var linkedTo: String?
    /// LINGO-10 BR-04: Goethe-only optional fields. Absent for IELTS, so those catalogue entries encode byte-identically.
    public var title: String?
    public var gloss: String?
    public var category: ExamCategory?
    public var talk: String?
    public var talkSummary: String?

    public init(id: String, exam: ExamKind, part: Int, task: String, points: [String], questions: [String], linkedTo: String? = nil,
                title: String? = nil, gloss: String? = nil, category: ExamCategory? = nil, talk: String? = nil, talkSummary: String? = nil) {
        self.id = id; self.exam = exam; self.part = part; self.task = task; self.points = points; self.questions = questions
        self.linkedTo = linkedTo; self.title = title; self.gloss = gloss; self.category = category
        self.talk = talk; self.talkSummary = talkSummary
    }
}

public enum ExamCategory: String, Codable, Sendable, CaseIterable { case alltag, arbeit, freizeit, umwelt, gesundheit }

/// LINGO-10 BR-05: a useful phrase for one Teil, shown in Training only.
public struct GoethePhrase: Codable, Sendable, Hashable {
    public var de: String
    public var ru: String
    public init(de: String, ru: String) { self.de = de; self.ru = ru }
}

/// LINGO-10 BR-05a: fixed lines spoken by the app as the Examiner; never stored and never sent to a model.
/// Raw values are the catalogue keys: the `exam.part` value the line opens, plus the thanks that closes the introduction.
public enum GoetheExaminerLine: String, Codable, Sendable, CaseIterable {
    case intro = "goethe_b1.intro", introEnd = "goethe_b1.intro.end"
    case teil1 = "goethe_b1.1", teil2 = "goethe_b1.2", teil3 = "goethe_b1.3"
    case partnerTalk = "goethe_b1.2.partner", feedback = "goethe_b1.3.feedback"
    public var text: String { GoetheContent.examinerLines[self] ?? "" }
}

public enum ExamKind: String, Codable, Sendable, CaseIterable {
    case goetheB1 = "goethe_b1", ielts
    public var lang: Lang { self == .goetheB1 ? .de : .en }
    public var title: String { self == .goetheB1 ? "Deutsch B1: Sprechen" : "IELTS Speaking" }
    public var role: String { self == .goetheB1 ? "Prüfer" : "Examiner" }

    /// Three ordered ids, with a Part 3 linked to the drawn presentation/cue card.
    public func drawTasks() -> [String] {
        let first = ExamCatalog.tasks(self, part: 1).randomElement()!
        let second = ExamCatalog.tasks(self, part: 2).randomElement()!
        let third = ExamCatalog.tasks(self, part: 3).first { $0.linkedTo == second.id }!
        return [first.id, second.id, third.id]
    }

    /// BR-02: a session with a format stores the partner's role, and inline corrections in Training.
    public func settings(tasks: [String], format: Activity.Format? = nil, teil: Int? = nil, partnerTask: String? = nil) -> SessionSettings? {
        guard ExamCatalog.valid(self, ids: tasks, format: format, teil: teil, partnerTask: partnerTask) else { return nil }
        return SessionSettings(lang: lang, mode: .free, topic: title, role: format == nil ? role : "Gesprächspartner",
                               level: self == .goetheB1 ? "B1" : "",
                               corrections: [format == .training ? .inline : .after], starter: .assistant, useVocabulary: false,
                               activity: Activity(kind: .exam, exam: rawValue, tasks: tasks, format: format, teil: teil, partnerTask: partnerTask))
    }
}

public enum ExamCatalog {
    public static func task(_ id: String) -> ExamTask? { all.first { $0.id == id } }
    public static func tasks(_ exam: ExamKind, part: Int) -> [ExamTask] { all.filter { $0.exam == exam && $0.part == part } }
    /// LINGO-10 BR-01: a Goethe Training session holds exactly one task, of the chosen Teil.
    public static func validTraining(teil: Int, ids: [String]) -> Bool {
        guard (1...3).contains(teil), ids.count == 1, let t = task(ids[0]) else { return false }
        return t.exam == .goetheB1 && t.part == teil
    }
    /// LINGO-10 BR-01: a Mock holds the linked triple and a partner's talk (a Teil 2 id other than the learner's own).
    public static func validMock(ids: [String], partnerTask: String) -> Bool {
        guard validSelection(.goetheB1, ids: ids), let p = task(partnerTask) else { return false }
        return p.exam == .goetheB1 && p.part == 2 && partnerTask != ids[1]
    }
    /// BR-01: the content of an exam activity for its format (the table of valid combinations).
    public static func valid(_ exam: ExamKind, ids: [String], format: Activity.Format?, teil: Int?, partnerTask: String?) -> Bool {
        switch format {
        case nil: teil == nil && partnerTask == nil && validSelection(exam, ids: ids)
        case .mock: exam == .goetheB1 && teil == nil && partnerTask.map { validMock(ids: ids, partnerTask: $0) } == true
        case .training: exam == .goetheB1 && partnerTask == nil && teil.map { validTraining(teil: $0, ids: ids) } == true
        }
    }
    public static func validSelection(_ exam: ExamKind, ids: [String]) -> Bool {
        guard ids.count == 3 else { return false }
        return ids.enumerated().allSatisfy { i, id in task(id).map { $0.exam == exam && $0.part == i + 1 } == true }
            && task(ids[2])?.linkedTo == ids[1]
    }

    /// LINGO-10 BR-05: 8–12 original phrases for Teil 1, 2 or 3; empty for any other number.
    public static func goethePhrases(teil: Int) -> [GoethePhrase] { GoetheContent.phrases[teil] ?? [] }
    /// The export shape of the phrases and Examiner lines (`exams.json`): keys "1"…"3" and the `GoetheExaminerLine` raw values.
    public static var goethePhrasesByTeil: [String: [GoethePhrase]] {
        Dictionary(uniqueKeysWithValues: GoetheContent.phrases.map { (String($0.key), $0.value) })
    }
    public static var goetheExaminerLines: [String: String] {
        Dictionary(uniqueKeysWithValues: GoetheExaminerLine.allCases.map { ($0.rawValue, $0.text) })
    }

    /// Title, gloss and category (BR-04) come from `GoetheContent.planning`, so the task lines below keep their text.
    private static func planning(_ id: String, _ task: String, _ points: [String]) -> ExamTask {
        let meta = GoetheContent.planning[id]
        return ExamTask(id: "b1-plan-" + id, exam: .goetheB1, part: 1, task: task, points: points, questions: [],
                        title: meta?.title, gloss: meta?.gloss, category: meta?.category)
    }
    /// The topic is also the title of both tasks (BR-04); gloss, category, talk and summary come from `GoetheContent.topics`.
    private static func presentation(_ id: String, _ topic: String, _ question: String) -> [ExamTask] {
        let key = "b1-talk-" + id, meta = GoetheContent.topics[id]
        return [ExamTask(id: key, exam: .goetheB1, part: 2, task: "Präsentieren Sie das Thema: " + topic,
                         points: ["Thema und Aufbau", "Meine persönliche Erfahrung", "Die Situation in meinem Heimatland",
                                  "Vor- und Nachteile; meine Meinung", "Zusammenfassung und Dank"], questions: [],
                         title: topic, gloss: meta?.gloss, category: meta?.category,
                         talk: meta?.slides.joined(separator: "\n"), talkSummary: meta?.summary),
                ExamTask(id: "b1-discuss-" + id, exam: .goetheB1, part: 3, task: "Sprechen Sie über das Thema: " + topic,
                         points: [], questions: [question], linkedTo: key, title: topic, gloss: meta?.gloss, category: meta?.category)]
    }
    private static func topic(_ id: String, _ title: String, _ questions: [String]) -> ExamTask {
        ExamTask(id: "ielts-topic-" + id, exam: .ielts, part: 1, task: title, points: [], questions: questions)
    }
    private static func cue(_ id: String, _ card: String, _ followUp: String, _ questions: [String]) -> [ExamTask] {
        let key = "ielts-cue-" + id
        return [ExamTask(id: key, exam: .ielts, part: 2, task: card, points: [], questions: [followUp]),
                ExamTask(id: "ielts-discuss-" + id, exam: .ielts, part: 3, task: "Discuss the wider topic related to the cue card.",
                         points: [], questions: questions, linkedTo: key)]
    }

    public static let all: [ExamTask] = planningTasks + presentationTasks + topics + cueTasks
    private static let planningTasks = [
        planning("park", "Sie möchten mit Ihrem Sprachkurs einen Nachmittag im Park verbringen. Planen Sie gemeinsam.",
                 ["Tag und Uhrzeit", "Treffpunkt und Anfahrt", "Essen und Getränke", "Aktivitäten bei Regen"]),
        planning("repair", "Sie organisieren mit einem Nachbarn einen Reparaturtag im Haus. Planen Sie gemeinsam.",
                 ["Termin und Raum", "Werkzeug und Material", "Einladung der Nachbarn", "Aufgaben und Aufräumen"]),
        planning("welcome", "Eine neue Kollegin kommt in Ihr Team. Organisieren Sie gemeinsam einen Willkommensabend.",
                 ["Ort und Termin", "Einladung des Teams", "Essen und Kosten", "Kleines Geschenk"]),
        planning("books", "Ihr Kurs möchte gebrauchte Bücher tauschen. Planen Sie gemeinsam einen Büchertausch.",
                 ["Ort und Uhrzeit", "Werbung für den Tausch", "Sortieren der Bücher", "Übrig gebliebene Bücher"]),
        planning("walk", "Sie möchten für neue Nachbarn einen Spaziergang durch das Viertel organisieren. Planen Sie gemeinsam.",
                 ["Treffpunkt und Dauer", "Interessante Stationen", "Einladung und Anmeldung", "Pause unterwegs"]),
        planning("cooking", "Ihr Sprachkurs möchte zusammen kochen. Organisieren Sie gemeinsam den Kochabend.",
                 ["Termin und Küche", "Gerichte und Allergien", "Einkauf und Kosten", "Verteilung der Aufgaben"]),
        // LINGO-10 BR-03: six more planning tasks.
        planning("cleanup", "Am Flussufer in Ihrem Viertel liegt viel Müll. Organisieren Sie gemeinsam eine Aufräumaktion.",
                 ["Termin und Treffpunkt", "Handschuhe und Müllsäcke", "Hilfe finden", "Abtransport des Mülls"]),
        planning("courtyard", "Der Innenhof Ihres Hauses ist grau und leer. Planen Sie gemeinsam, wie Sie ihn mit den Nachbarn bepflanzen.",
                 ["Termin und Helfer", "Pflanzen und Erde", "Kosten und Einkauf", "Gießen im Sommer"]),
        planning("running", "Sie möchten mit Kolleginnen und Kollegen eine Laufgruppe gründen. Planen Sie gemeinsam.",
                 ["Wochentag und Uhrzeit", "Strecke und Treffpunkt", "Tempo für Einsteiger", "Plan bei schlechtem Wetter"]),
        planning("firstaid", "Ihr Sportverein möchte einen Erste-Hilfe-Kurs für seine Mitglieder anbieten. Organisieren Sie ihn gemeinsam.",
                 ["Termin und Raum", "Kursleitung finden", "Kosten und Anmeldung", "Material und Pausen"]),
        planning("move", "Ihr Team zieht in ein neues Büro um. Planen Sie gemeinsam den Umzugstag.",
                 ["Termin und Reihenfolge", "Kartons und Packen", "Technik und Telefon", "Einrichtung der Arbeitsplätze"]),
        planning("interns", "In Ihrer Firma beginnen drei Praktikantinnen und Praktikanten. Planen Sie gemeinsam ihren ersten Arbeitstag.",
                 ["Begrüßung und Rundgang", "Arbeitsplatz und Technik", "Gemeinsames Mittagessen", "Erste Aufgaben"]),
    ]
    private static let presentationTasks = [
        presentation("bicycle", "Mit dem Fahrrad zur Arbeit?", "Was würde mehr Menschen motivieren, mit dem Fahrrad zu fahren?"),
        presentation("online", "Online einkaufen oder im Geschäft?", "Welche Geschäfte sollte es auch in Zukunft im Viertel geben?"),
        presentation("cooking", "Selbst kochen im Alltag?", "Wie kann man auch an Arbeitstagen frisch kochen?"),
        presentation("courses", "Gemeinsam oder allein eine Sprache lernen?", "Was kann eine Lerngruppe besser als eine App?"),
        presentation("garden", "Ein gemeinsamer Garten in der Stadt?", "Wie sollten Nachbarn die Arbeit im Garten verteilen?"),
        presentation("travel", "Urlaub in der Nähe oder weit weg?", "Was könnte Urlaub in der eigenen Region interessanter machen?"),
        // LINGO-10 BR-03: six more topics.
        presentation("homeoffice", "Zu Hause arbeiten oder im Büro?", "Welche Regeln braucht ein Team, das oft zu Hause arbeitet?"),
        presentation("parttime", "Weniger arbeiten, mehr freie Zeit?", "Für wen ist Teilzeitarbeit besonders sinnvoll?"),
        presentation("club", "Sport im Verein oder allein?", "Wie kann man Menschen motivieren, regelmäßig Sport zu machen?"),
        presentation("screens", "Abends ohne Bildschirm?", "Was hilft Ihnen, am Abend zur Ruhe zu kommen?"),
        presentation("secondhand", "Gebraucht kaufen statt neu?", "Welche Dinge würden Sie nie gebraucht kaufen, und warum?"),
        presentation("neighbours", "Braucht man gute Nachbarn?", "Wie kann man neue Nachbarn am besten kennenlernen?"),
    ].flatMap { $0 }
    private static let topics = [
        topic("home", "Your home and neighbourhood", [
            "What do you like about the place where you live?", "Which room do you spend most time in?",
            "What can you see from your window?", "Where do you usually buy food nearby?",
            "How do you get to know your neighbours?", "Is there a quiet place near your home?",
            "Has your neighbourhood changed recently?", "What would you improve about your home?"]),
        topic("work", "Work and study", [
            "What do you do on a typical working or study day?", "When do you concentrate best?",
            "Who do you usually work or study with?", "What helps you organise your tasks?",
            "Which task do you enjoy most?", "Where do you prefer to take a break?",
            "What skill would you like to learn next?", "How has your routine changed since last year?"]),
        topic("food", "Everyday food", [
            "What do you usually have for breakfast?", "Who cooks most often in your home?",
            "What meal do you enjoy preparing?", "Where do you buy fresh ingredients?",
            "Do you prefer eating alone or with others?", "What food did you dislike as a child?",
            "How do you choose a new restaurant?", "Would you like to learn to cook something new?"]),
        topic("transport", "Getting around", [
            "How do you usually travel around your area?", "What do you do during a long journey?",
            "Do you enjoy walking?", "When did you last use public transport?",
            "What makes a journey comfortable for you?", "Do you prefer travelling early or late?",
            "How do you find your way in a new place?", "Would you change your usual way of travelling?"]),
        topic("free-time", "Free time", [
            "What do you like doing after a busy day?", "Do you plan your weekends in advance?",
            "Where do you meet your friends?", "What hobby did you have as a child?",
            "Do you enjoy trying new activities?", "How much time do you spend outdoors?",
            "What do you like doing on a rainy day?", "Is there an activity you would like to do more often?"]),
        topic("technology", "Everyday technology", [
            "Which device do you use most often?", "What do you use it for in the morning?",
            "How did you learn to use your current phone?", "Do you prefer typing or writing by hand?",
            "What app saves you time?", "When do you put your phone away?",
            "Who do you ask when a device stops working?", "Would you like to learn a new technical skill?"]),
        topic("seasons", "Seasons and weather", [
            "Which season do you enjoy most?", "How does the weather affect your daily plans?",
            "What do you do on a very hot day?", "Do you check the forecast before going out?",
            "What clothes do you like wearing in winter?", "Did you play outside in winter as a child?",
            "Where would you spend a sunny afternoon?", "Would you like to live in a different climate?"]),
        topic("reading", "Reading and stories", [
            "What do you read most often?", "When do you find time to read?",
            "Do you prefer paper books or a screen?", "Who recommended something good to you recently?",
            "What stories did you enjoy as a child?", "Do you visit a library?",
            "How do you choose your next book or article?", "Would you like to read more in another language?"]),
    ]
    private static let cueTasks = [
        cue("skill", "Describe a practical skill you learned from another person. Say who taught you, how you practised, what was difficult, and why this skill is useful to you.",
            "Do you still use that skill?", ["Why do people enjoy teaching practical skills?", "How can schools connect theory with practice?",
            "What can young and older people learn from each other?", "Should employers provide time for learning?",
            "How has technology changed practical training?", "What makes a teacher effective?"]),
        cue("place", "Describe a public place where you like spending time. Say where it is, what you do there, who goes there, and why you enjoy it.",
            "Would you recommend it to a visitor?", ["What makes public spaces welcoming?", "How can cities provide quieter places?",
            "Who should decide how public spaces are used?", "Why do some places bring different generations together?",
            "How can a city improve access to public places?", "Should commercial activities be allowed in every public space?"]),
        cue("project", "Describe a small project you completed with others. Say what you made, who took part, how you shared the work, and what you learned.",
            "Would you work with that group again?", ["What makes teamwork successful?", "How should teams divide responsibilities?",
            "Why do disagreements happen in groups?", "How can schools teach cooperation?",
            "Has remote working changed teamwork?", "When is working alone more effective?"]),
        cue("journey", "Describe a journey that was different from what you expected. Say where you went, how you travelled, what changed, and how you felt about the experience.",
            "Would you make the same journey again?", ["Why do people choose different forms of transport?", "How can travel change people's views?",
            "What are the benefits of slower travel?", "How should cities respond to increased tourism?",
            "How has trip planning changed?", "Should governments encourage local tourism?"]),
        cue("object", "Describe an everyday object you have kept for a long time. Say what it is, how you got it, how you use it, and why you have kept it.",
            "Would it be easy to replace?", ["Why do people keep old objects?", "What makes a product last a long time?",
            "Should companies make repairs easier?", "How has advertising affected buying habits?",
            "What can communities do to reduce waste?", "Is buying fewer things always practical?"]),
        cue("event", "Describe a local event you enjoyed. Say where it happened, who you went with, what you did, and why you remember it.",
            "Would you attend a similar event?", ["How do local events help communities?", "Who should organise community events?",
            "How can organisers attract different age groups?", "What are the drawbacks of very large events?",
            "How has technology changed participation?", "Should local events be free to attend?"]),
        cue("decision", "Describe a decision that improved your daily routine. Say what you changed, why you decided to do it, what helped you continue, and how it affected your day.",
            "Was it difficult to keep the change?", ["Why are habits difficult to change?", "How can workplaces support better routines?",
            "Should schools teach time management?", "How does technology affect people's use of time?",
            "What helps people make long-term plans?", "Is a strict routine useful for everyone?"]),
        cue("story", "Describe a story you enjoyed reading or hearing. Say what it was about, how you discovered it, which part you remember best, and why it interested you.",
            "Have you shared that story with anyone?", ["Why do people tell stories?", "How can stories help children learn?",
            "Has digital media changed storytelling?", "Why are some old stories still popular?",
            "Should schools include stories from other cultures?", "What responsibilities do storytellers have?"]),
    ].flatMap { $0 }
}
