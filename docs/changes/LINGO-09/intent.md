# LINGO-09: Intent — harsh tutor and conflict practice on the Mac

ID: LINGO-09-intent · Status: **draft**, waiting for the owner (H-09-0) · Version: 1.1 · Date: 2026-11-13 · Owner: itmax04 · Risk: **R2**
Links: [spec.md](spec.md) · [plan.md](plan.md) · [handoff.md](handoff.md) · prior: [LINGO-05](../LINGO-05/intent.md) (Q-04: teacher first,
then these modes) · [completion plan](../../plans/COMPLETION-PLAN-2026-11.md) row B

## Problem
Lingo is always a friendly tutor. The owner wants to practise German and English under pressure: to recall and say a phrase such as
„Ich bin damit nicht einverstanden“ at the moment somebody pushes him, not only to know it. Two ideas came from the owner's concept
papers (2026-11-01):
- **Hostile Feedback Learning (HFL):** a harsh tutor who reacts sharply to mistakes, swears if allowed, and demands the corrected form.
- **Stand Your Ground:** a conflict simulator. Lingo plays an aggressive counterpart, and the learner defends a position and personal
  boundaries in the foreign language.

Today neither works. The base prompt starts with "a friendly tutor", and rule 7 treats the learner's own prompt as data that cannot
change the rules, so a custom prompt cannot make Lingo harsh.

A third need (owner, 2026-11-13): in any conversation the learner sometimes does not know what to answer. Today the only way out is
"how to say" in Russian, which needs an idea of the answer first. Other voice tutors show a few possible answers under the last reply.

## Desired outcome
1. **Two levels on any session:** tutor harshness 0–5 and character hostility 0–5, plus a profanity switch. Presets: Strict teacher,
   Conflict, Combined. Level 0/0 is today's Lingo, unchanged.
2. **Honest harshness:** the tutor criticises only real mistakes. A reply that blames without a recorded correction is filtered.
3. **Drive without quota:** the repeat after a correction is checked on the Mac, and pressure during silence comes from fixed lines.
4. **Conflict scenarios** from real life in Germany: authorities, housing, work, shopping and services, in German and English.
5. **Help in three steps** (strategy, first words, full phrase), revealed one step at a time, with the step recorded.
6. **Control and safety:** levels can be changed during the conversation; one word or key drops them to 0; a hard session ends calmly
   with a short debrief and a self-rating.
7. **A personal experiment** that can answer whether harshness helps the owner remember: 2 conditions × 32 expressions, blind grading.
8. **Nothing else changes:** warm-up, exams, Goethe, vocabulary and every old session work as before (with the reply options switch
   of item 9 off, which is the default).
9. **Reply options on request:** in a session without a tone the learner can switch on two or three possible answers under the last
   reply of Lingo. They open one step at a time (first words, then the full phrase with a translation) and are never sent by
   themselves, so the learner still says the answer.

## Scope
- In: Lingo for Mac; `packages/contracts` (settings, events, protocol and command fixtures, catalogues, prompt snapshots);
  `packages/core-ts` decoding of the new fields, events, tags and commands (AGENTS.md §6.9); docs.
- Out, decided by the owner: storage limits and deletion of transcripts (B-17, with the account, LINGO-03/04); the web and iOS clients;
  real-time speech-to-speech and interruptions by meaning (LINGO-06).
- Out, proposed by the executor (see "Open for H-09-0"): file import into the vocabulary (B-18); integration of a non-system voice.
- Not touched: warm-up, exams (IELTS, Goethe), the FSRS grading of the warm-up, the ordinary Hints panel of sessions without a tone
  (reply options live in the conversation, not in that panel).

## Constraints
- $0 (AGENTS.md §6.1): system voices; no paid speech service.
- No pronunciation assessment in any form (§6.7). Rule 3 of the prompt stays as it is, at every level.
- Quota (§6.5, ADR-0005): the modes must not cost more model requests per learner turn than an ordinary session.
- Dependencies only from ADR-0001. Any other voice engine needs an ADR entry first and the owner's consent before installation.
- Every settings, journal and protocol change is additive; a session with level 0/0 produces the same prompt and events as today.
- Repository files are English; the owner is addressed in Russian. DESIGN.md is the only source of colours, type and spacing.

## Owner decisions (brainstorm 2026-11-01, recorded outside the repository then; carried over unchanged)
| ID | Question | Owner's answer | Effect |
|---|---|---|---|
| B-01 | Structure | Parameters (harshness 0–5, hostility 0–5, profanity) plus presets | MR-01…MR-05 |
| B-02 | Voice | Find a free open option; a free one is enough for testing | Probe of Piper `thorsten_emotional` and Chatterbox Multilingual on the same 10 lines; installation asked separately; without a choice the system voice stays (MR-30…MR-32) |
| B-03 | Limit of rudeness | "No limits, with threats and discrimination; the user picks the level" | Done: profanity, hard personal insults, pressure, realistic everyday threats (police, ban from the premises, dismissal, eviction), contempt such as "learn German first". **Not done** (executor's decision, owner informed on 2026-11-01): threats of violence, insults by nationality, race or similar traits, bypassing the providers' safety. MR-06 |
| B-04, B-05 | LINGO-05 and order | Finish the teacher completely, then the modes | Done: LINGO-05 accepted 2026-11-12 |
| B-06 | Languages | German and English | Lines and scenarios in both; German first |
| B-07 | Experiment | 2 conditions × 32 expressions | Calm and harsh with the same timer; blind grading by a separate request (MR-37…MR-43) |
| B-08 | Lingo interrupts | Local interjections | Fixed lines by level, no model; never after a conjunction or preposition ("weil …") (MR-33, MR-34) |
| B-09 | Codex prototype | None was built | Built in this repository |
| B-10 | Model check | A small daytime run | One exception to "no live batches": 30–40 requests on the 20b model with a budget (MR-35) |
| B-11 | Lowering the tension | Stop word plus debrief | A word or key sets the levels to 0; a hard session ends with a successful step and a debrief (MR-28, MR-29) |
| B-12 | Silence | Pressure, then a hint | 8 s: a rude fixed line; 8 s more: help step 1; no model; adjustable (MR-20) |
| B-13 | Correction | At once, plus "repeat" up to 2 times | The repeat is checked locally; after two failures the session moves on and the phrase becomes a card (MR-16…MR-19) |
| B-14 | Help | Key or word, text in the panel | Each call opens the next step; speaking by button; the step is recorded with the turn (MR-22, MR-23) |
| B-15 | Live prompt | Field and sliders in the voice panel | Saving cuts the current reply; the next reply uses the new version; the version is in the journal (MR-27) |
| B-16 | Scenarios | Real life: authorities, housing, work, shopping and services | A catalogue of these four groups, German and English (MR-24) |
| B-17 | Transcript storage | Later, with the account | Out of scope |
| B-18 | Vocabulary import | Pasted list plus CSV/TXT | Pasting a list exists since LINGO-08; the file import is proposed as its own change (O-3) |
| B-19 | Reply options (2026-11-13, with a screenshot of another tutor as the example) | Add them to LINGO-09: a learner who does not know what to say switches on answer options after each reply | MR-49…MR-54, steps M-11a and M-11b; placement and behaviour are proposal O-7 |

## Open for H-09-0 (the executor's proposals; the owner confirms or changes them when accepting these documents)
| ID | Question | Proposal | Why |
|---|---|---|---|
| O-1 | B-03 allowed contemptuous remarks about the accent. | **Not built.** The character may attack language skill in general ("Lernen Sie erst mal Deutsch"), never accent, sounds or pronunciation. | AGENTS.md §6.7 is a rule that is never relaxed, and the `no_pronunciation` eval must stay at 100 % |
| O-2 | B-10 allowed one daytime run of 30–40 requests. | Confirm it once more for step M-2: one run, at most 40 requests, on the 20b model, with a budget. Otherwise the run happens at night. | AGENTS.md §6.5 allows batches only at night |
| O-3 | B-18 file import into the vocabulary. | Its own small change after LINGO-09. | It is not a conversation mode; pasting a list already works |
| O-4 | Language of the experiment. | German only; it starts after the owner has tried the modes (H-09-1). | One language keeps 64 expressions comparable |
| O-6 | Provider policy risk of levels 4–5 on the free account. | The owner accepts that abuse and profanity are generated through the same free account(s); a suspension is possible. | Groq's terms were not checked in this review; AGENTS.md §8 treats extra accounts as an accepted risk |
| O-5 | The calm-down words. | The owner names one Russian, one German and one English word or phrase in step M-4; until then only the key and the button work. | A word the owner will remember under pressure must be his own |
| O-7 | Placement and behaviour of the reply options (B-19). | Under the latest assistant message in the conversation; off by default; each option shows its first words and opens on a click; ▶ and ★ as in the Hints panel; never sent automatically; options come in the same reply (`@reply`), refresh is one request; hidden in tone, trial, warm-up and exam sessions, where Help (MR-22) or the task itself serves. | The options belong to one turn, so they sit next to it; the Hints panel holds the topic and collapses below 1280 pt; a full answer shown at once is read aloud instead of recalled; no extra request per turn |

## Assumptions (executor, R2: recorded, not blocking)
- A-01: Harshness applies to ordinary sessions and scenarios. Warm-up and exams never have a tone.
- A-02: A level is a setting of the session, chosen in the interface. The learner's own prompt cannot raise it (rule 7 stays).
- A-03: The model may soften or refuse a rude role. Lingo shows what the model returned and never tries to get around a refusal. Step
  M-2 measures how often this happens before anything else is built.
- A-04: An older build opens a session with a tone, or a trial session, as an ordinary friendly session.
- A-05: The debrief of a hard session is one request at the end and gives no score.
- A-06: The self-rating is the learner's own number. Lingo never derives confidence from the voice.
- A-07: The experiment needs at least 21 days of calendar time. The change is accepted on the working tools; the result is added to the
  report later as a dated note.
- A-08: Fixed lines, scenarios and expressions are original texts written for Lingo.

## Definition of done
All MAC criteria of [spec.md](spec.md) have evidence (PASS, or NOT RUN with a reason); `swift test`, `npm test`, `check-design`,
`check-english` and `secret-scan` pass; an independent AI review has no open P0/P1 on the documents and on each PR; the owner has tried
the modes at H-09-1 and accepted the change at H-09-3.
