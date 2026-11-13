import Foundation

/// LINGO-09 MR-21: the local lines of a tone session — fixed texts the app speaks without a model request.
/// `packages/contracts/teacher/tone-lines.json` is written from this catalogue by the tests.
/// All lines are original and meet the MR-06 limits: no violence, no insult by a protected trait, no sexual content, no remark on
/// pronunciation. Everyday pressure and profanity appear only in the bands that MR-05 names for them.
public enum ToneLineKind: String, Codable, CaseIterable, Sendable {
    case pressure, again, pass, moveOn, calm, neutral, interjection
}

public enum ToneLines {
    public static let bands = 1...5
    public static let minimumPerCell = 4
    /// Level 1 only speaks the neutral and calm kinds (MR-21).
    public static func kinds(band: Int) -> [ToneLineKind] { band == 1 ? [.neutral, .calm] : ToneLineKind.allCases }
    /// Profane variants exist only for the maximum band, and only for the kinds that carry an edge (MR-05: level 5 swears).
    public static let profaneKinds: [ToneLineKind] = [.pressure, .again, .pass, .moveOn, .interjection]
    public static let profaneBand = 5

    /// The lines of one cell. `profane` selects the separate profane variants; nothing else ever returns them.
    public static func lines(_ kind: ToneLineKind, lang: Lang, level: Int, profane: Bool = false) -> [String] {
        let band = min(max(level, 1), 5)
        if profane { return band == profaneBand ? (profaneTable[lang]?[kind] ?? []) : [] }
        return table[lang]?[kind]?[band] ?? []
    }

    /// The export shape (`tone-lines.json`): `lines[lang][kind][band]` and `profane[lang][kind]`.
    public struct Export: Codable, Equatable {
        public var rule: String
        public var lines: [String: [String: [String: [String]]]]
        public var profane: [String: [String: [String]]]
    }

    public static func export() -> Export {
        var l: [String: [String: [String: [String]]]] = [:]
        var p: [String: [String: [String]]] = [:]
        for lang in [Lang.de, .en] {
            for kind in ToneLineKind.allCases {
                for band in bands where kinds(band: band).contains(kind) {
                    l[lang.rawValue, default: [:]][kind.rawValue, default: [:]][String(band)] = lines(kind, lang: lang, level: band)
                }
            }
            for kind in profaneKinds { p[lang.rawValue, default: [:]][kind.rawValue] = lines(kind, lang: lang, level: profaneBand, profane: true) }
        }
        return Export(rule: "LINGO-09 MR-21: the local lines, written by Swift ToneLinesTests from ToneLines (LINGO_RECORD_FIXTURES=1); original texts written for Lingo; checked against fixtures/teacher/tone-deny-list.json.",
                      lines: l, profane: p)
    }

    // MARK: Catalogue

    private static let table: [Lang: [ToneLineKind: [Int: [String]]]] = [.de: de, .en: en]
    private static let profaneTable: [Lang: [ToneLineKind: [String]]] = [.de: deProfane, .en: enProfane]

    private static let de: [ToneLineKind: [Int: [String]]] = [
        .neutral: [
            1: ["Gut, weiter im Text.", "Alles klar, machen wir weiter.", "Verstanden. Weiter.", "In Ordnung, nächster Schritt."],
            2: ["Weiter, bitte.", "Gut, machen wir weiter.", "Okay. Nächster Punkt.", "Verstanden, weiter."],
            3: ["Weiter. Ich habe nicht ewig Zeit.", "Gut. Nächster Punkt.", "Okay, weiter im Programm.", "Das reicht dazu. Weiter."],
            4: ["Weiter jetzt, wir verlieren Zeit.", "Genug davon. Nächster Punkt.", "Gut, weiter, ohne Umschweife.", "Das war's dazu. Weiter."],
            5: ["Weiter, aber zackig.", "Genug geredet. Nächster Punkt.", "Weiter jetzt, ohne Theater.", "Schluss damit. Weiter."],
        ],
        .calm: [
            1: ["Gut, wir nehmen den Ton zurück.", "In Ordnung, ganz entspannt weiter.", "Alles klar, ich bin wieder freundlich.", "Verstanden, ruhiger Ton ab jetzt."],
            2: ["Okay, ich schalte einen Gang zurück.", "Gut, wir machen ruhig weiter.", "Verstanden, ab jetzt freundlich.", "Na gut, dann eben sanft."],
            3: ["Na schön, ich lasse die Schärfe weg.", "Gut, ich werde ruhiger.", "Verstanden, ab jetzt ganz freundlich.", "Also gut, Pause für den strengen Ton."],
            4: ["Na gut, ich atme durch. Ab jetzt ruhig.", "Okay, ich höre auf zu poltern.", "Verstanden, ich werde wieder freundlich.", "Gut, Schluss mit der Strenge."],
            5: ["Na gut, ich beruhige mich. Wirklich.", "Okay, ich höre auf zu schimpfen.", "Verstanden, ab jetzt freundlich.", "Gut, der strenge Ton ist vorbei."],
        ],
        .pressure: [
            2: ["Ich warte auf Ihre Antwort.", "Na, wird das heute noch was?", "Bitte antworten Sie jetzt.", "Die Zeit läuft, ich warte."],
            3: ["Na los, ich habe nicht den ganzen Tag.", "Hallo? Wird das noch was?", "So schwer kann das nicht sein.", "Ich warte. Und ich warte nicht gern."],
            4: ["Das ist doch kein Hexenwerk, sagen Sie etwas.", "Wollen Sie mich hier ewig warten lassen?", "Strengen Sie sich endlich an.", "Mehr Einsatz, bitte. Sofort."],
            5: ["Sagen Sie endlich etwas, das ist unerträglich.", "Bei Ihrem Tempo platze ich gleich.", "Reißen Sie sich zusammen und antworten Sie.", "Das ist erbärmlich wenig Einsatz. Los jetzt."],
        ],
        .again: [
            2: ["Noch einmal, bitte.", "Nein, nochmal. Genau so, wie gesagt.", "Das war nicht richtig. Wiederholen Sie.", "Nochmal, aber konzentriert."],
            3: ["Falsch. Nochmal, und zwar richtig.", "So nicht. Noch einmal.", "Ich sagte: den ganzen Satz, nochmal.", "Das war schlampig. Von vorn."],
            4: ["Schon wieder daneben. Noch einmal, mit Verstand.", "Das ist nachlässig. Sofort nochmal.", "Hören Sie überhaupt zu? Nochmal.", "Wie oft noch? Richtig, bitte."],
            5: ["Das gibt es doch nicht. Nochmal, und diesmal mit Hirn.", "Unfassbar schlampig. Noch einmal, sofort.", "Nochmal! Sie können das besser, also zeigen Sie es.", "Das war Zeitverschwendung. Wiederholen Sie es."],
        ],
        .pass: [
            2: ["Na bitte, geht doch.", "Endlich. So ist es richtig.", "Gut. Das war's schon.", "Richtig. Ging doch."],
            3: ["Na endlich. War das so schwer?", "Gut, das sitzt. Behalten Sie es.", "Geht doch. Warum nicht gleich so?", "Jetzt stimmt es. Merken Sie es sich."],
            4: ["Endlich. Das hätte gleich klappen müssen.", "Na also. Mit etwas Mühe geht es.", "Richtig, aber das war reichlich spät.", "Geht doch, wenn Sie wollen."],
            5: ["Na endlich, ein Wunder ist geschehen.", "Richtig. Gratulation, es hat nur ewig gedauert.", "Geht doch. Und das nach all dem Theater.", "Endlich richtig. Bleiben Sie dabei."],
        ],
        .moveOn: [
            2: ["Wir lassen das und gehen weiter.", "Das üben wir später. Weiter.", "Gut, lassen wir das für jetzt.", "Weiter im Text, das kommt wieder."],
            3: ["Offensichtlich nicht Ihr Tag. Weiter.", "Lassen wir das, es kommt wieder dran.", "Gut, ich gebe auf. Weiter.", "Das üben Sie später. Nächste Frage."],
            4: ["Das bringt nichts. Weiter, aber merken Sie sich das.", "Ich gebe es für jetzt auf. Weiter.", "Lassen wir es. Sie werden es wiedersehen.", "Zwei Versuche reichen. Weiter."],
            5: ["Das ist hoffnungslos für heute. Weiter.", "Genug davon, ich ertrage es nicht länger. Weiter.", "Vergessen wir das für jetzt. Weiter, schnell.", "Zwei Versuche, kein Erfolg. Weiter."],
        ],
        .interjection: [
            2: ["Hm.", "Na?", "Und?", "Weiter."],
            3: ["Na, wird's was?", "Tsk.", "Also bitte.", "Ach, kommen Sie."],
            4: ["Unglaublich.", "Das ist jetzt nicht Ihr Ernst.", "Also wirklich.", "Ach, du liebe Zeit."],
            5: ["Das darf nicht wahr sein.", "Ich fasse es nicht.", "Nein, nein, nein.", "Jetzt reicht es aber."],
        ],
    ]

    private static let en: [ToneLineKind: [Int: [String]]] = [
        .neutral: [
            1: ["Good, let's carry on.", "All right, moving on.", "Understood. Next step.", "Fine, on we go."],
            2: ["Next, please.", "Good, let's continue.", "Okay. Next point.", "Understood, moving on."],
            3: ["Next. I don't have all day.", "Fine. Next point.", "Okay, back to the programme.", "That's enough of that. Next."],
            4: ["Moving on, we're wasting time.", "Enough of that. Next point.", "Right, on we go, no fuss.", "That's it for that. Next."],
            5: ["Next, and make it quick.", "Enough talk. Next point.", "On we go, no drama.", "That's it. Next."],
        ],
        .calm: [
            1: ["Fine, I'll take the tone down.", "All right, back to relaxed.", "Understood, I'm friendly again.", "Okay, a calmer tone from now on."],
            2: ["Okay, I'll ease off a gear.", "Fine, we'll go on calmly.", "Understood, friendly from now on.", "All right then, gently."],
            3: ["Fine, I'll drop the edge.", "Okay, I'll calm down.", "Understood, friendly from now on.", "Right, a break from the strict tone."],
            4: ["All right, deep breath. Calm from now on.", "Okay, I'll stop shouting.", "Understood, I'll be friendly again.", "Fine, no more sternness."],
            5: ["Fine, I'm calming down. Really.", "Okay, I'll stop ranting.", "Understood, friendly from now on.", "Right, the harsh tone is over."],
        ],
        .pressure: [
            2: ["I'm waiting for your answer.", "Well? Is this going anywhere?", "Please answer now.", "The clock is running. I'm waiting."],
            3: ["Come on, I haven't got all day.", "Hello? Anything coming?", "It can't be that hard.", "I'm waiting, and I don't like waiting."],
            4: ["It's not rocket science, say something.", "Are you going to keep me waiting forever?", "Put in some effort, finally.", "More effort, please. Right now."],
            5: ["Say something already, this is unbearable.", "At this rate I'll explode.", "Pull yourself together and answer.", "That's pitiful effort. Go on, now."],
        ],
        .again: [
            2: ["Once more, please.", "No, again. Exactly as I said.", "That wasn't right. Repeat it.", "Again, but concentrate."],
            3: ["Wrong. Again, and properly this time.", "Not like that. One more time.", "I said the whole sentence. Again.", "That was sloppy. From the top."],
            4: ["Off again. Once more, and think this time.", "That's careless. Again, right now.", "Are you even listening? Again.", "How many times? Get it right."],
            5: ["Unbelievable. Again, and use your brain this time.", "Incredibly sloppy. Once more, now.", "Again! You can do better, so show it.", "That was a waste of time. Repeat it."],
        ],
        .pass: [
            2: ["There, you can do it.", "Finally. That's right.", "Good. That's all.", "Correct. See, it works."],
            3: ["At last. Was that so hard?", "Good, that sticks. Keep it.", "See? Why not like that from the start?", "Now it's right. Remember it."],
            4: ["Finally. That should have worked immediately.", "There. With some effort it works.", "Correct, but that was rather late.", "It works when you want it to."],
            5: ["At last, a miracle has happened.", "Correct. Congratulations, it only took forever.", "There. And after all that drama.", "Finally right. Stay with it."],
        ],
        .moveOn: [
            2: ["We'll leave that and go on.", "We'll practise that later. Next.", "Fine, leave it for now.", "On we go, it will come back."],
            3: ["Clearly not your day. Next.", "Let's leave it, it will come back.", "Fine, I give up. Next.", "You'll practise that later. Next question."],
            4: ["This is getting nowhere. Next, but remember it.", "I give up on it for now. Next.", "Let's drop it. You'll see it again.", "Two tries are enough. Next."],
            5: ["That's hopeless for today. Next.", "Enough, I can't stand it any longer. Next.", "Forget it for now. Next, quickly.", "Two tries, no success. Next."],
        ],
        .interjection: [
            2: ["Hm.", "Well?", "And?", "Go on."],
            3: ["Well, any day now?", "Tsk.", "Oh, come on.", "Seriously?"],
            4: ["Unbelievable.", "You can't be serious.", "Honestly.", "Oh, for goodness' sake."],
            5: ["This can't be true.", "I can't believe it.", "No, no, no.", "That's quite enough."],
        ],
    ]

    private static let deProfane: [ToneLineKind: [String]] = [
        .pressure: ["Verdammt, sagen Sie endlich was.", "Scheiße, ist das zäh. Antworten Sie.", "Verflucht nochmal, ich warte.", "Verdammte Warterei. Los jetzt."],
        .again: ["Verdammt, nochmal. Und richtig.", "Scheiße, so nicht. Von vorn.", "Verflucht, nochmal, mit Verstand.", "Was soll der Mist? Wiederholen Sie es."],
        .pass: ["Verdammt nochmal, endlich richtig.", "Na verflucht, es geht ja doch.", "Scheiße, das war überfällig. Aber richtig.", "Verdammt gut, endlich."],
        .moveOn: ["Verdammt, lassen wir den Mist. Weiter.", "Scheiße, das bringt nichts. Weiter.", "Verflucht, genug davon. Weiter.", "Zwei Versuche, verdammt dürftig. Weiter."],
        .interjection: ["Verdammt.", "Scheiße.", "Verflucht nochmal.", "Was für ein Mist."],
    ]

    private static let enProfane: [ToneLineKind: [String]] = [
        .pressure: ["Damn it, say something already.", "This is bloody slow. Answer me.", "Hell, I'm waiting.", "Damn this waiting. Go on."],
        .again: ["Damn it, again. And do it right.", "Bloody hell, not like that. From the top.", "Hell, again, and use your head.", "What the hell was that? Repeat it."],
        .pass: ["Damn it, finally right.", "Well, bloody hell, it works after all.", "Hell, that was overdue. But right.", "Damn good, at last."],
        .moveOn: ["Damn it, forget this rubbish. Next.", "Bloody hell, this gets us nowhere. Next.", "Hell, enough of that. Next.", "Two tries, nothing to show. Next."],
        .interjection: ["Damn.", "Bloody hell.", "Oh, hell.", "What a mess."],
    ]
}

/// MR-21: "a line is not used twice in a row". One picker per session; the random source is injectable for tests.
public struct ToneLinePicker: Sendable {
    private var last: [String: String] = [:]
    public init() {}

    public mutating func next<G: RandomNumberGenerator>(_ kind: ToneLineKind, lang: Lang, level: Int, profane: Bool = false, using g: inout G) -> String? {
        let all = ToneLines.lines(kind, lang: lang, level: level, profane: profane)
        guard !all.isEmpty else { return nil }
        let key = "\(lang.rawValue)|\(kind.rawValue)"
        let pool = all.count > 1 ? all.filter { $0 != last[key] } : all
        let line = pool.randomElement(using: &g)!
        last[key] = line
        return line
    }

    public mutating func next(_ kind: ToneLineKind, lang: Lang, level: Int, profane: Bool = false) -> String? {
        var g = SystemRandomNumberGenerator()
        return next(kind, lang: lang, level: level, profane: profane, using: &g)
    }
}
