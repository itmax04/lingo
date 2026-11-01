import type { CommandKind } from "./kind.js";

/**
 * The detector vocabulary, the same data as Swift `CommandDetector` (R-14…R-22). A test compares it with the Swift-written
 * `packages/contracts/fixtures/commands/vocabulary.json`, so the two lists cannot drift apart. Language data: ru, de, en.
 */
export const EXACT: Readonly<Partial<Record<CommandKind, readonly string[]>>> = {
  "repeat": [
    "повтори", "повторите", "повтори еще раз", "еще раз", "повтори что ты сказал", "повтори вопрос", "не расслышал",
    "я не расслышал", "что что", "nochmal", "noch mal", "noch einmal", "wiederhol", "wiederhole", "wiederholen",
    "wiederholen sie", "wiederhol das", "wie bitte", "nochmal bitte", "again", "repeat", "repeat that", "repeat please",
    "say it again", "say that again", "one more time", "pardon", "come again", "sorry what", "what was that",
  ],
  "slower": [
    "медленнее", "помедленнее", "говори медленнее", "говорите медленнее", "чуть медленнее", "немного медленнее",
    "медленнее пожалуйста", "можно медленнее", "можно помедленнее", "давай медленнее", "langsamer", "langsam", "etwas langsamer",
    "sprich langsamer", "sprechen sie langsamer", "langsamer bitte", "bitte langsamer", "langsamer sprechen", "sprich langsam",
    "langsam sprechen", "slower", "more slowly", "slowly", "speak slower", "speak slowly", "speak more slowly", "slow down",
    "slower please", "a bit slower",
  ],
  "explain": [
    "объясни", "объясни по русски", "объясни пожалуйста", "по русски", "скажи по русски", "переведи", "переведи пожалуйста",
    "что ты спросил", "что ты спрашиваешь", "что это значит", "что значит", "почему так", "почему", "erklar mal", "erklar",
    "erklar das", "erklar es", "erklaren sie", "was bedeutet das", "was heisst das", "explain", "explain that", "explain please",
    "what does that mean", "in russian", "what did you ask",
  ],
  "continue": [
    "продолжим", "продолжаем", "продолжай", "продолжайте", "дальше", "давай дальше", "давай продолжим", "давай продолжаем",
    "идем дальше", "поехали дальше", "готов", "я готов", "weiter", "machen wir weiter", "lass uns weitermachen", "weitermachen",
    "mach weiter", "weiter bitte", "gehen wir weiter", "let's continue", "lets continue", "continue", "go on", "next",
    "next question", "let's go on", "lets go on", "let's move on", "move on",
  ],
  "mistakes": [
    "были ошибки", "есть ошибки", "какие были ошибки", "какие ошибки", "проверь меня", "исправь меня", "где я ошибся",
    "я делал ошибки", "я ошибался", "korrigiere mich", "korrigier mich", "gab es fehler", "hab ich fehler gemacht",
    "habe ich fehler gemacht", "welche fehler", "any mistakes", "did i make any mistakes", "did i make mistakes", "correct me",
    "check me", "what were my mistakes",
  ],
  "finish": [
    "на этом все", "на этом всё", "закончим", "заканчиваем", "давай закончим", "все хватит", "хватит на сегодня",
    "на сегодня все", "das war's", "das wars", "das war es", "das reicht", "schluss", "schluss fur heute", "lass uns aufhoren",
    "das war es fur heute", "that's all", "thats all", "let's stop", "lets stop", "let's finish", "lets finish", "i'm done",
    "im done", "that's it for today",
  ],
};

/** Commands with an argument: the start of the utterance, exact words (no tolerance), in this order. */
export const PREFIXES: readonly (readonly [CommandKind, string])[] = [
  ["how_to_say", "как сказать"],
  ["how_to_say", "как будет"],
  ["how_to_say", "как еще можно сказать"],
  ["how_to_say", "как еще сказать"],
  ["how_to_say", "как правильно сказать"],
  ["how_to_say", "как по немецки"],
  ["how_to_say", "как по английски"],
  ["how_to_say", "как это будет"],
  ["how_to_say", "как мне сказать"],
  ["how_to_say", "wie sagt man"],
  ["how_to_say", "wie heisst auf deutsch"],
  ["how_to_say", "wie kann ich sagen"],
  ["how_to_say", "how do i say"],
  ["how_to_say", "how do you say"],
  ["how_to_say", "how to say"],
  ["how_to_say", "how can i say"],
  ["explain", "что значит"],
  ["explain", "что такое"],
  ["explain", "переведи"],
  ["explain", "объясни"],
  ["explain", "почему"],
  ["explain", "was bedeutet"],
  ["explain", "was heisst"],
  ["explain", "erklar mal"],
  ["explain", "erklar mir"],
  ["explain", "what does"],
  ["explain", "what is the meaning of"],
  ["explain", "explain"],
];

/** Fillers and polite additions that do not change the meaning of a command. */
export const FILLERS: ReadonlySet<string> = new Set([
  "ah", "ahm", "alright", "also", "bitte", "can", "could", "denke", "doch", "du", "glaube", "guess", "gut", "hm", "hmm", "i",
  "ich", "ja", "kannst", "konnen", "mal", "nein", "no", "oh", "ok", "okay", "please", "right", "so", "think", "uh", "um", "well",
  "you", "äh", "ähm", "а", "думаю", "кажется", "ладно", "мне", "можете", "можешь", "наверное", "нет", "ну", "ой", "ок", "окей",
  "плиз", "пожалуйста", "так", "хорошо", "э", "эм", "я",
]);
