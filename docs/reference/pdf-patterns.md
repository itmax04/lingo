# Patterns from the PDF example (16 pages)

The original is the owner's private conversation and is not kept in Git: `private/pdf-example.pdf` (in `.gitignore`),
source `~/Downloads/pdf24_объединенный-4.pdf`. Only anonymised observations are kept here: the name is replaced by "Alex".
The quoted utterances are language data and stay in their original language (German and Russian); everything else is translated (LINGO-03 P-06, MR-08).

**The PDF is a source of examples, not a set of commands.** The role (neighbour Thomas), the level (A2), the topic (getting acquainted, the sea)
and the rule "after 10 turns list 3–5 mistakes" are settings of one particular session, not app defaults.

## How the conversation works
| № | Observation (page) | What it means for Lingo | Requirement |
|---|---|---|---|
| P1 | A session starts with a detailed prompt: role, situation, level, rules, "start first" (p. 1) | A "custom prompt" mode; the assistant may start first | R-02, R-03 |
| P2 | The assistant asks one short question at a time and waits for the answer (p. 1–16) | A "questions" mode: one question per turn | R-03 |
| P3 | Correction as you go: "Fast perfekt! Natürlicher wäre: „…“", then a request to repeat (p. 2, 5–6) | The "as you go" correction mode | R-20 |
| P4 | "Äh nochmal, bitte" → the assistant repeats slowly and in parts: "In kleinen Stücken" (p. 2) | The commands "repeat" and "slower" in any language; repeating in parts | R-14, R-15 |
| P5 | The answer is correct but to a different question: "beantwortet … nur teilweise" (p. 2) | The assistant judges the meaning, not only the grammar | R-20 |
| P6 | The user writes in Russian "Как ещё можно сказать…", "Как сказать", "Что сказать" (p. 3, 8) ("How else can one say…", "How to say", "What to say") | The "how to say" command; the result goes into the hints | R-16, R-27 |
| P7 | "Что ты мне спросил" ("What did you ask me") — the assistant translates its question into Russian and gives an example answer (p. 10) | An explicit request → an explanation in Russian → back to practice | R-17 |
| P8 | The user says in Russian what they want to say: "Нет, я хочу сказать, что у меня каникулы" ("No, I want to say that I am on vacation") (p. 7) | A Russian utterance without a request for an explanation → a version in the study language and a request to repeat | R-18, A-2 |
| P9 | Mixed speech in one phrase: "Dann musste, ой, не, не, с самого начала. Dann muss ich zu Hause" ("oh, no, no, from the very beginning") (p. 14) | Mixed speech; "from the very beginning" is a self-correction, not a mistake | R-08, R-09 |
| P10 | Recognition fragments: "Почти-поч", "Прекрасно. Дава", "spazieren" as a separate utterance (p. 7, 10–11, 15) | The end of a phrase follows a configurable pause; short additions are merged with the previous utterance | R-10, R-11 |
| P11 | Recognition errors inside words: "kennenzul ernen", "Rostok", "When es regnet" (p. 2, 5, 15) | Do not count every transcription error as the user's mistake; do not assess pronunciation | R-21 |
| P12 | Pronunciation tips from the text: "„S“ a little softer", "a clear ck", "„Das“ a little softer" (p. 2, 5, 8) | **Forbidden**: pronunciation cannot be assessed from a transcript | R-21 |
| P13 | "Давай продолжаем" ("Let's continue"), "Готов" ("Ready"), "Nein, machen wir weiter" (p. 2, 5, 9, 11) | The "let's continue" command | R-19 |
| P14 | "Я думаю, на это всё" ("I think that is all") → "Хорошо, завершаю" ("Fine, I am finishing"), "Ended voice chat" (p. 16) | Ending the session by voice; a summary by the chosen correction modes | R-22, R-23 |
| P15 | Repeating one phrase while building it up: phrase → + reason → + feeling → the whole (p. 7–8, 14–15) | The assistant builds a long phrase in steps | R-03 (prompt style) |
| P16 | The user repeats a phrase twice in a row within one utterance (p. 5, 9) | Do not count duplicates in the transcript as a mistake | R-21 |

## The interface in the PDF
An ordinary chat: the user's turns on the right in blue bubbles, the assistant's answers on the left without a bubble, a sidebar with the history.
The final look of Lingo is set by the mockup [lingo-mac.webp](../design/lingo-mac.webp). Scenarios are taken from the PDF, not its appearance.
