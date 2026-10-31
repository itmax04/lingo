import Foundation

/// A recognized command. `argument` — "what to say" for "how to say …" or "what to explain" for "what does … mean".
public struct CommandMatch: Sendable, Equatable {
    public var kind: CommandKind
    public var argument: String?
    public init(_ kind: CommandKind, argument: String? = nil) { self.kind = kind; self.argument = argument }
}

/// Local command detector (R-14…R-22): rules and vocabularies for ru, de, en, tolerant of transcription errors.
/// A command is the whole utterance (after fillers and polite additions), not a word inside a sentence: "я повторил урок" ("I revised the lesson") is not a command.
/// If the detector is unsure it returns nil and the utterance goes to the model as usual (the model knows the commands too, R-25).
public enum CommandDetector {
    /// Whole-utterance commands (after normalization). Typo tolerance depends on length (see `tolerance`).
    static let exact: [CommandKind: [String]] = [
        .repeatLast: [
            "повтори", "повторите", "повтори еще раз", "еще раз", "повтори что ты сказал", "повтори вопрос",
            "не расслышал", "я не расслышал", "что что",
            "nochmal", "noch mal", "noch einmal", "wiederhol", "wiederhole", "wiederholen", "wiederholen sie", "wiederhol das",
            "wie bitte", "nochmal bitte",
            "again", "repeat", "repeat that", "repeat please", "say it again", "say that again", "one more time", "pardon",
            "come again", "sorry what", "what was that",
        ],
        .slower: [
            "медленнее", "помедленнее", "говори медленнее", "говорите медленнее", "чуть медленнее", "немного медленнее",
            "медленнее пожалуйста", "можно медленнее", "можно помедленнее", "давай медленнее",
            "langsamer", "langsam", "etwas langsamer", "sprich langsamer", "sprechen sie langsamer", "langsamer bitte", "bitte langsamer",
            "langsamer sprechen", "sprich langsam", "langsam sprechen",
            "slower", "more slowly", "slowly", "speak slower", "speak slowly", "speak more slowly", "slow down", "slower please", "a bit slower",
        ],
        .continuePractice: [
            "продолжим", "продолжаем", "продолжай", "продолжайте", "дальше", "давай дальше", "давай продолжим", "давай продолжаем",
            "идем дальше", "поехали дальше", "готов", "я готов",
            "weiter", "machen wir weiter", "lass uns weitermachen", "weitermachen", "mach weiter", "weiter bitte", "gehen wir weiter",
            "let's continue", "lets continue", "continue", "go on", "next", "next question", "let's go on", "lets go on", "let's move on", "move on",
        ],
        .mistakes: [
            "были ошибки", "есть ошибки", "какие были ошибки", "какие ошибки", "проверь меня", "исправь меня", "где я ошибся",
            "я делал ошибки", "я ошибался",
            "korrigiere mich", "korrigier mich", "gab es fehler", "hab ich fehler gemacht", "habe ich fehler gemacht", "welche fehler",
            "any mistakes", "did i make any mistakes", "did i make mistakes", "correct me", "check me", "what were my mistakes",
        ],
        .finish: [
            "на этом все", "на этом всё", "закончим", "заканчиваем", "давай закончим", "все хватит", "хватит на сегодня", "на сегодня все",
            "das war's", "das wars", "das war es", "das reicht", "schluss", "schluss fur heute", "lass uns aufhoren", "das war es fur heute",
            "that's all", "thats all", "let's stop", "lets stop", "let's finish", "lets finish", "i'm done", "im done", "that's it for today",
        ],
        .explain: [
            "объясни", "объясни по русски", "объясни пожалуйста", "по русски", "скажи по русски", "переведи", "переведи пожалуйста",
            "что ты спросил", "что ты спрашиваешь", "что это значит", "что значит", "почему так", "почему",
            "erklar mal", "erklar", "erklar das", "erklar es", "erklaren sie", "was bedeutet das", "was heisst das",
            "explain", "explain that", "explain please", "what does that mean", "in russian", "what did you ask",
        ],
    ]

    /// Commands with an argument: the start of the utterance (exact words, no tolerance — otherwise "как сказал" would become "как сказать").
    static let prefixes: [(CommandKind, String)] = [
        (.howToSay, "как сказать"), (.howToSay, "как будет"), (.howToSay, "как еще можно сказать"), (.howToSay, "как еще сказать"),
        (.howToSay, "как правильно сказать"), (.howToSay, "как по немецки"), (.howToSay, "как по английски"),
        (.howToSay, "как это будет"), (.howToSay, "как мне сказать"),
        (.howToSay, "wie sagt man"), (.howToSay, "wie heisst auf deutsch"), (.howToSay, "wie kann ich sagen"),
        (.howToSay, "how do i say"), (.howToSay, "how do you say"), (.howToSay, "how to say"), (.howToSay, "how can i say"),
        (.explain, "что значит"), (.explain, "что такое"), (.explain, "переведи"), (.explain, "объясни"), (.explain, "почему"),
        (.explain, "was bedeutet"), (.explain, "was heisst"), (.explain, "erklar mal"), (.explain, "erklar mir"),
        (.explain, "what does"), (.explain, "what is the meaning of"), (.explain, "explain"),
    ]

    /// Fillers and polite additions that do not change the meaning of a command.
    static let fillers: Set<String> = [
        "ну", "а", "ой", "э", "эм", "так", "ладно", "хорошо", "окей", "ок", "пожалуйста", "плиз", "можешь", "можете", "мне",
        "äh", "ah", "ahm", "ähm", "hm", "hmm", "bitte", "mal", "doch", "also", "okay", "ok", "ja", "gut", "kannst", "du", "konnen",
        "um", "uh", "please", "could", "can", "you", "well", "so", "oh", "alright", "right",
        "нет", "nein", "no",
        // Parenthetical words: "Я думаю, на этом всё" ("I think that's all", P14).
        "я", "думаю", "кажется", "наверное", "ich", "glaube", "denke", "i", "think", "guess",
    ]

    public static func detect(_ text: String) -> CommandMatch? {
        let norm = normalize(text)
        guard !norm.isEmpty else { return nil }
        let words = norm.split(separator: " ").map(String.init)
        guard words.count <= 12 else { return nil }
        // 1. Command with an argument: "как сказать …", "wie sagt man …" (exact start; the argument is the rest of the original text).
        for (kind, p) in prefixes {
            let pw = p.split(separator: " ").map(String.init)
            if let rest = stripPrefix(words, pw), !rest.isEmpty {
                let arg = rest.joined(separator: " ")
                // "почему так" and "объясни по русски" are exact commands below; "почему ты …" ("why do you …") is a normal question for the model.
                if kind == .explain, p == "почему", rest.count > 2 { continue }
                if kind == .explain, ["объясни", "explain"].contains(p), rest.count > 4 { continue }
                return CommandMatch(kind, argument: argumentText(original: text, prefixWords: pw.count) ?? arg)
            }
        }
        // 2. The whole utterance is a command (without fillers), tolerant of transcription errors.
        let core = words.filter { !fillers.contains($0) }.joined(separator: " ")
        let candidates = Set([norm, core]).filter { !$0.isEmpty }
        var best: (CommandKind, Int)?
        for (kind, list) in exact {
            for p in list {
                let pn = normalize(p)
                for c in candidates {
                    let d = levenshtein(c, pn)
                    if d <= tolerance(pn), best == nil || d < best!.1 { best = (kind, d) }
                }
            }
        }
        return best.map { CommandMatch($0.0) }
    }

    /// Transcription typo tolerance: short commands match only exactly.
    static func tolerance(_ s: String) -> Int {
        switch s.count {
        case ..<5: 0
        case ..<9: 1
        default: 2
        }
    }

    public static func normalize(_ s: String) -> String {
        var t = s.lowercased()
        let map: [Character: String] = ["ё": "е", "ä": "a", "ö": "o", "ü": "u", "ß": "ss", "’": "'", "`": "'"]
        t = String(t.flatMap { map[$0].map(Array.init) ?? [$0] })
        // Punctuation → space; an apostrophe inside a word is kept (let's, das war's).
        t = t.unicodeScalars.map { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) || $0 == "'" ? String($0) : " " }.joined()
        t = t.replacingOccurrences(of: " '", with: " ").replacingOccurrences(of: "' ", with: " ")
        return t.split(separator: " ").joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: "' "))
    }

    static func stripPrefix(_ words: [String], _ prefix: [String]) -> [String]? {
        // Leading fillers ("ну, как сказать …") are skipped.
        var w = words[...]
        while let f = w.first, fillers.contains(f), !prefix.contains(f) { w = w.dropFirst() }
        guard w.count >= prefix.count, Array(w.prefix(prefix.count)) == prefix else { return nil }
        return Array(w.dropFirst(prefix.count))
    }

    /// The argument from the original text (with case and punctuation), without the command words.
    static func argumentText(original: String, prefixWords n: Int) -> String? {
        var words = original.split(whereSeparator: { $0 == " " }).map(String.init)
        while let f = words.first, fillers.contains(normalize(f)) { words.removeFirst() }
        guard words.count > n else { return nil }
        let arg = words.dropFirst(n).joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ?!.,:;—-"))
        let cleaned = arg.trimmingCharacters(in: CharacterSet(charactersIn: "\"'«»„“”"))
        return cleaned.isEmpty ? nil : cleaned
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        var cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }
}
