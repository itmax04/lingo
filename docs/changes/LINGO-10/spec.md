# LINGO-10: Specification — Goethe-Zertifikat B1 Sprechen on the Mac

ID: LINGO-10-spec · Status: **accepted** by the owner (2026-11-09) · Version: 1.1 (AI review findings F-01…F-20 answered) · Date: 2026-11-09 · Owner: itmax04 · Risk: R2
Links: [intent.md](intent.md) (decisions Q1…Q19, assumptions A-01…A-13) · [plan.md](plan.md) · [handoff.md](handoff.md) ·
[contracts](../../../packages/contracts/README.md) · [DESIGN.md](../../../DESIGN.md) · mockups `design/goethe-b1-2026/`
Requirements of this change are defined only here: BR (requirements), BAC (acceptance). The web and iOS clients are out of scope.
**Amends** for the German exam only: LINGO-05 XR-01 (catalogue size and fields), XR-02 (parts, roles, timers), XR-03 (debrief), PX-03 and
PX-04 (limits of the new blocks and of the Goethe debrief), and the Goethe part of TAC-06. IELTS keeps every one of them unchanged.

Common definitions, in addition to those of LINGO-05 spec:
- **Format**: `mock` or `training`, stored in the session's activity. A German exam session without a format is **legacy** (built before this change).
- **Examiner line**: fixed catalogue text, spoken by the app and never stored as a message. Examiner lines are not sent to a model; the one exception is the task's catalogue question in Training (BR-24a, A-06).
- **Partner**: the role Lingo plays. Every model reply in a Goethe exam, and the pre-written talk, is the partner's.
- Event order is (ts, device, seq, id), as in the merger.

## 1. Sessions and data
- **BR-01. Activity** (additive to XR-02). `Activity` gets three optional fields:
  - `format`: `"mock"` or `"training"`;
  - `teil`: 1, 2 or 3 (training only);
  - `partnerTask`: the id of the partner's talk (mock only).

  Valid content, checked by the tolerant decoder of PX-05:
  | Format | `tasks` | Other fields |
  |---|---|---|
  | absent (legacy, and IELTS) | as today: three linked ids | none |
  | `mock` | as today: three linked ids `[plan, talk, discuss]` for the chosen topic | `partnerTask` is a part 2 id different from `tasks[1]`; exam is `goethe_b1` |
  | `training` | exactly one id, of part `teil` | `teil` is present; exam is `goethe_b1` |

  Anything else, including an unknown format value, decodes as no activity, and the session opens as its stored mode (PX-05).
- **BR-02. Stored settings** stay as in XR-02 (mode "Free conversation", topic = the exam title, level B1, `useVocabulary` off), so an
  older build can read the session. Corrections are `after` in Mock and `inline` in Training. The stored role of a session with a format is `Gesprächspartner` (the system prompt says "Stay in it", and Lingo plays the partner); legacy and IELTS sessions keep their roles. An exam still cannot be resumed.
- **BR-02a. Part events.** Additive `exam.part` values (`ExamPhase` raw values):
  `goethe_b1.intro`, `goethe_b1.2.partner`, `goethe_b1.3.feedback`, `goethe_b1.end`. `goethe_b1.end` is not a timed part: it is written once,
  only when a run reaches its natural end (the last part ended by its timer or by Done). Finish, "That's all" or leaving the session never
  writes it. The value `goethe_b1.1.prep` remains for reading legacy sessions; no new session writes it.

## 2. Catalogue
All content stays in `ExamCatalog` (Swift source) and is exported to `packages/contracts/teacher/exams.json` by the existing recording test.
- **BR-03. Tasks.** 12 tasks for each Goethe part: 12 planning tasks, 12 presentation tasks and 12 discussion tasks linked one to one (as
  today, by `linkedTo`). The six existing tasks of each part and their ids stay, with unchanged text. Six new ones are added per part.
- **BR-04. New optional task fields** (absent from IELTS tasks, so those JSON entries stay byte-identical):
  | Field | On | Limit |
  |---|---|---|
  | `title` | Goethe tasks of all parts | German, ≤ 60 characters; a discussion task repeats the title of its linked talk |
  | `gloss` | Goethe tasks of all parts | Russian, ≤ 60 characters (language data) |
  | `category` | Goethe tasks of all parts | one of `alltag`, `arbeit`, `freizeit`, `umwelt`, `gesundheit`; at least 2 tasks of each category per part |
  | `talk` | presentation tasks | German, 360–440 words, ≤ 3 200 characters; follows the five slides, at B1 level |
  | `talkSummary` | presentation tasks | German, ≤ 300 characters; the only part of the talk sent to a model |

  The limits of XR-01 stay for the existing fields. Each planning task keeps 4 points; the "open point" of the official format is added by
  the screen and the role text (BR-12, BR-24), not by the catalogue.
- **BR-05. Useful phrases.** A top-level `goethePhrases` in the catalogue: 8–12 phrases per Teil, each `{ de ≤ 80, ru ≤ 80 }`, original text.
- **BR-05a. Examiner lines.** A top-level `goetheExaminerLines`, German, each ≤ 200 characters, original text: greeting and request to
  introduce oneself (intro), thanks (end of the intro), and one instruction line for each of `goethe_b1.1`, `goethe_b1.2`, `goethe_b1.3`,
  `goethe_b1.2.partner` and `goethe_b1.3.feedback`.
- **BR-06. Originality** (XR-01). No task title or task text may repeat a task of the three listed official sources (see
  [handoff](handoff.md), "Facts"). "Ohne Auto leben" (Übungssatz p. 28) is therefore excluded, although a mockup shows it. A validation test
  rejects a list of official titles kept in the test (at least those read from the Übungssatz). Plan step G-2 has an independent review compare
  the new content with the sources.

## 3. Flows
- **BR-07. Parts per format.** The app runs these parts in order. Times are seconds.
  | Part (`exam.part`) | Mock | Training | Speaking | Time | Model call at the start |
  |---|---|---|---|---|---|
  | preparation | before the session | none | nobody; microphone off | 900 | none |
  | `goethe_b1.intro` | 1st | none | Examiner line, then the learner (held) | 60 | none |
  | `goethe_b1.1` | 2nd | Teil 1 | Examiner line, then partner and learner in normal turns | 180 | partner opens |
  | `goethe_b1.2` | 3rd | Teil 2 | Examiner line, then the learner's monologue (held, as today) | 240, labelled "3-4 min" | none |
  | `goethe_b1.3` (mock) | 4th | none | Examiner line; the partner reacts and asks one question; the learner answers; the Examiner asks the task's catalogue question; the learner answers | 120 | partner's reaction |
  | `goethe_b1.2.partner` | 5th | Teil 3, 1st | Examiner line, then the partner's talk; microphone off | until the speech ends; safety limit 300 | none |
  | `goethe_b1.3.feedback` | 6th | Teil 3, 2nd | Examiner line; the learner gives feedback and asks a question; the partner answers in normal turns | 120 | none, the learner starts |
  | `goethe_b1.3` (training) | none | Teil 3, 3rd | the Examiner asks the task's catalogue question; the learner answers; the partner reacts in normal turns | 120 | none |
  | `goethe_b1.end` | last | last | marker only (BR-02a) | | none |

  In Mock the sum is 15 + 1 + 3 + 4 + 2 + about 3 + 2 ≈ 30 minutes. `ExamPhase.goethe2.seconds` becomes 240. The speech buffer of
  `TurnController` derives from it (245 s), which is what keeps a 4-minute monologue whole.
- **BR-08. Mock start.** The Mock tab draws one planning task and two different presentation topics at random, shown with Teil 2's five
  slides and German text only. The first topic is preselected. The learner may change it until preparation ends; the topic not chosen becomes
  `partnerTask` (A-03).
- **BR-08a. Preparation** runs on the Goethe screen (no session exists yet, A-01). Microphone off, 15:00 countdown, tasks and notes visible. Done or
  the timer ends it. Then the session is created with the frozen selection and the intro begins. Voice setup starts when preparation starts, so
  that the end of preparation does not wait for it. Finish, or leaving the screen, discards the preparation: no session, no event, no debrief,
  as leaving a live exam does today. If the session cannot be created, a banner with Retry says so and the screen stays in preparation with its notes, at 00:00 when the time is up, microphone off, until Retry succeeds or the learner leaves.
- **BR-09. Mock timers are strict.** Every part ends at zero, as `ExamRun` does today, including the wait for a running capture or reply. Done
  ends a part early (Q19). The monologue words `fertig`, `done`, `finished` work as today in `goethe_b1.intro` and `goethe_b1.2`.
- **BR-10. Speech and microphone.** The microphone is closed while an Examiner line or the partner's talk is being spoken; there is no barge-in on
  them. It opens when the speech ends, except in `goethe_b1.2.partner`, where it stays closed for the whole part (also after the speech has ended in Training). The Examiner line of a part is spoken before that part's model request, and the part's timer starts
  when the line has ended.
- **BR-11. Introduction.** Examiner greeting; the learner speaks; at Done or the timer the Examiner's thanks is spoken, and Teil 1 begins. No
  model call. The learner's utterances are stored like any other but belong to `goethe_b1.intro` and never reach the debrief (BR-26).
- **BR-12. Teil 1.** As XR-02, plus the open point: the screen shows a fifth, empty row "…", and the partner accepts another point if the learner brings one.
- **BR-13. Partner's talk** (Mock). The text comes from the `partnerTask` catalogue entry, is split into sentences for speech, and is **not shown and not stored
  as a message** (Q14). The part ends when the speech has ended, at the safety limit, or at Done (which stops the speech). Notes stay editable.
- **BR-14. Teil 3 in Mock.** In `goethe_b1.3` the partner makes one short reaction and asks one question. Its request carries the whole learner talk, not the usual window of the last 8 turns: all `goethe_b1.2` lines joined as one learner turn of at most 4 000 characters, shortened evenly. After the learner's first answer the Examiner
  asks the catalogue question (no model call). The second answer gets no reply; the part waits for the timer or Done. In
  `goethe_b1.3.feedback` the model answers the learner's question from `talkSummary`.
- **BR-15. Transitions.** In a Goethe run with a format the Examiner line is the transition: the `time is up` field of `<exam>` is not sent. IELTS keeps it.
- **BR-16. Training start.** The learner picks a Teil and a task on the Training tab and presses Start. There is no preparation phase.
- **BR-17. Training Teil 3** runs the parts of BR-07 (Q16). The talk comes from the task linked by `linkedTo`, is visible, is **not stored as a message**, and has a Replay button in that part (Replay restarts the speech). The microphone stays closed.
  The part does not end by itself: the learner moves on with Done.
- **BR-18. Training timers** are shown, but dialogue parts do not end at zero (A-05); the learner ends them with Done. A Teil 2 monologue does end at its
  240 s limit (BR-07).
- **BR-19. Training aids.** Hints column, Translate and In Russian as in a normal session, with "Useful phrases for Teil N" from the catalogue in place of the
  topic phrases (no model call; the topic-phrases request stays skipped, PX-04). Corrections are immediate where there are turns; a monologue has no turns,
  so its corrections appear in the debrief only.
- **BR-20. Mock aids** are off from the start of preparation to the end of the run: no Hints column, no Translate, no In Russian (the button and the global ⌥R shortcut), no typing (the input bar is hidden).
  Replies to the partner stay as bubbles. Task content is German only; the interface stays in the app's language, which is Russian for the owner (Q11).
- **BR-21. Finishing.** Finish or "That's all" ends the run at once, as today. The debrief then follows BR-31.
- **BR-22. Notes.** One plain text field per run, at most 2 000 characters: "My notes" in Mock and in Training Teil 3, "My presentation plan" in Training Teil 2 (Q10). It stays on
  screen for the whole run and stays editable, also while listening (Q14). Training Teil 1 has no notes. Notes live in memory for that run only (A-04). They are never sent to a model, written to the
  journal or to a file, or logged.

## 4. Voices and prompts
- **BR-23. Voices** (Q13). The Examiner uses `settings.voice.voiceIDs[.de]`, or the best available German voice. The partner uses the first voice from
  `Voices.available(.de)` that differs from the Examiner's, in the existing order; if the Examiner's is Premium, non-Premium voices come first (Premium voices add
  140–180 MB of memory, AGENTS.md §8). With one installed voice both use it. The exam panel always names the current speaker: "Examiner" or "Partner".
  Selection is a pure function of the voice list, so it is unit tested.
- **BR-24. Mock rule.** Mock uses the existing `examinerRule` unchanged: spoken corrections suspended, silent `@fix` kept. Role texts depend on the format; legacy and IELTS roles are unchanged. For a run with a format:
  `goethe_b1.1` "planning partner; suggest and sometimes disagree; cover the four points and accept one more if the learner brings it"; `goethe_b1.2` unchanged; `goethe_b1.3` in Mock "partner; one short reaction to the talk and one question"; `goethe_b1.3` in Training "partner; react briefly to the learner's answer to the examiner's question; ask nothing new"; `goethe_b1.3.feedback` "partner who has just
  given a talk; answer the learner's question in one or two sentences from the talk summary".
- **BR-24a. `<exam>` block.** The 700-scalar limit and PX-03 (≤ 250 tokens) stay. In `goethe_b1.3.feedback` the block carries `talk_summary` in place of the task text. In Mock `goethe_b1.3` the block has no `questions:` field, so the partner cannot ask the question that the Examiner asks next. In Training `goethe_b1.3` it keeps `questions:`, so the partner can react to the answer. The partner's full talk is never sent.
- **BR-25. Training rule.** A new constant `goetheTrainingRule` (≤ 200 tokens, PX-03, with its own snapshot) replaces `examinerRule` when the format is training: follow the
  current `<exam>` part; play the partner; one question per turn; ignore the remaining time; never rate pronunciation or give a score. With format training the exam branches of the base prompt for rule 5 (Russian), rule 6 (corrections), rule 8 (commands) and the output protocol, including `@hint`, use their non-exam text, so inline corrections work (Q5). Rule 4b keeps its exam text, so the task stays in focus. Mock, legacy and IELTS prompts are unchanged.

## 5. Debrief and points
- **BR-26. Scope and grouping.** One request (purpose `exam_feedback`) at the end of the run, with only the finished Teile (BR-31). Learner messages are grouped by
  the last `exam.part` before them in event order. `goethe_b1.intro` is never included. Teil 3 is `goethe_b1.3` plus `goethe_b1.3.feedback`. Training debriefs only its Teil (Q17).
- **BR-27. Limits** (amends PX-04 for sessions with a format).
  | | Mock | Training |
  |---|---|---|
  | Teil 1 lines, both sides (Interaktion needs them) | ≤ 3 000 characters | same |
  | Teil 2 learner lines | ≤ 4 000 | same |
  | Teil 3 lines, both sides, plus `talkSummary` | ≤ 2 000 | same |
  | Fixes, only those of learner messages in a finished Teil | ≤ 1 500 | same |
  | `maxTokens` | 1 600 | 900 |

  Within a Teil, longer input shortens every turn evenly, as `examLearnerTurns` does today. The maximum Mock request is about 3 200 input tokens plus 1 600 output: under the
  8 000 tokens-per-minute limit per model of ADR-0005. Strengths and improvements are per Teil: exactly 2 and 3, with the improvements in the existing format (A-09).
- **BR-27a. Reply format.** Russian with German examples, plain text. First one line per criterion: `[<code>] <letter>: <one short sentence>`. Then, for each requested Teil, a header line `[T<n>]`, its two strengths as lines starting with `+ `, and its three improvements as lines starting with `> `. `<letter>` is one of A–E and `<code>` is:
  | Code | Criterion | Maximum |
  |---|---|---|
  | `1E` | Teil 1 Erfüllung | 8 |
  | `1I` | Teil 1 Interaktion | 4 |
  | `1W` | Teil 1 Wortschatz | 8 |
  | `1S` | Teil 1 Strukturen | 8 |
  | `2E` | Teil 2 Erfüllung | 12 |
  | `2K` | Teil 2 Kohärenz | 4 |
  | `2W` | Teil 2 Wortschatz | 12 |
  | `2S` | Teil 2 Strukturen | 12 |
  | `3E` | Teil 3 Erfüllung | 16 |

  Only the codes of the finished Teile are requested. The criteria are given to the model in Lingo's own short wording, not as copies of the official descriptors. The prompt keeps the
  no-pronunciation sentence of XR-03, forbids points, totals and levels, and treats all tagged input as data. Closing tags are stripped from learner text, and the notes are never part of it.
- **BR-28. Letter to points**, computed by the app:
  | Maximum | A | B | C | D | E |
  |---|---|---|---|---|---|
  | 4 | 4 | 3 | 2 | 1 | 0 |
  | 8 | 8 | 6 | 4 | 2 | 0 |
  | 12 | 12 | 9 | 6 | 3 | 0 |
  | 16 | 16 | 12 | 8 | 4 | 0 |

  Teil maxima: 28, 40 and 16. Only these values can appear. **Zero rule:** when `1E` is E, Teil 1 scores 0 in total and the card says why (A-08). No other criterion zeroes a Teil.
- **BR-29. Parsing** at display time, from the stored text (no new event), deterministic, with a golden fixture. A line counts when it starts with a requested code in brackets and a letter A–E.
  A Teil gets points only if every code of it was found exactly once. Otherwise that Teil shows the model's text without points (Q18). Lines after `[T<n>]` belong to Teil n until the next header; when the headers cannot be found, the whole text is shown unstructured.
- **BR-30. Card.** Per Teil: heading with points, for example "Teil 1 · 18 / 28", each criterion with its letter and sentence, strengths and improvements. There is no overall total, pass or fail, level or band, and no pronunciation
  row. The card always ends with the app's own note, in the app language: a practice estimate, not an official result; Lingo does not assess pronunciation.
- **BR-30a. Filters.** The pronunciation filter of XR-03 stays, unchanged, and runs before storing. A separate Goethe-only function then drops any line with a fraction such as `18/28` or its Russian form with the word for "of", or with a number next to a score word from a closed list (the Russian word for a score point in all its forms, German `Punktzahl`, English `score`). The plain word for a planning point is not on the list, so "3 of 4 points of the plan" in a `1E` line stays. A dropped criterion line means no points for that Teil (BR-29). Golden cases cover both directions (BR-40).
- **BR-31. Finished parts and incomplete runs** (Q18). A part is finished when a later `exam.part` event exists for the session. Teil 1 needs `goethe_b1.1`, Teil 2 needs `goethe_b1.2`, Teil 3 needs both of its parts (BR-26).
  A finished Teil with no learner text is shown as not assessed and is not requested. If at least one Teil is requested but some are not finished, the card lists the unfinished Teile and is marked "Incomplete". If none can be requested, there is no request and the
  session shows "Nothing finished to assess" (also for a Training run ended with Finish rather than Done). The Training panel says so next to its buttons: Done completes the part and gives the debrief; Finish stops without assessing what is unfinished.
- **BR-32. Failure.** The existing behaviour stays: "Debrief not available" with Retry, one request per click, no automatic retry, at most one stored debrief per session.

## 6. Goethe screen
All values come from DESIGN.md. Layout follows the mockups, corrected as listed in the intent.
- **BR-33. Entry.** In Teacher the German exam card opens the Goethe screen instead of starting an exam. The IELTS card is unchanged. The start conditions of `startExam` apply to Start and to the start of preparation (no start while finishing, while offline or when read-only; a refused click says why).
- **BR-34. Training tab.** Steps strip (preparation, introduction, Teil 1, Teil 2 "3-4 min", Teil 3), Teil segments 1, 2 and 3, category chips, task cards with title, Russian gloss and the real practice count and last date. The count is the number of live German exam sessions, legacy ones included, with at least one learner message and this task id in `tasks`. No stars, no search. An empty count reads "Not practised yet".
- **BR-35. Right panel** (272 pt, collapses below 1280 pt): the selected task, what will happen, the assessed criteria of that Teil, the sentence that Lingo does not assess pronunciation, "Useful phrases for Teil N", "My presentation plan" (Teil 2 only), and Start.
- **BR-36. Debriefs tab.** A plain list, newest first: date, mode (Training Teil N or Mock exam) and topic title. It holds sessions with a format that have ended, including those whose debrief failed. Opening one shows the stored session with its debrief card and Retry when applicable. No charts. Empty state with a short hint.
- **BR-37. Mock tab and locking.** The Mock tab shows the format and Start; during preparation it shows the preparation panel, tasks and notes as in the mockup. While a Mock runs (preparation and live parts) the other tabs and every Start control on the screen are disabled (visibly, not hidden), so returning through the sidebar cannot stop a running Mock by accident; Finish is the way out. The live parts run in the conversation view with the exam panel. Interface strings are English in code and Russian in the catalog. Keyboard focus, VoiceOver labels, Reduce Motion and contrast follow DESIGN.md §6.

## 7. Contracts, compatibility and IELTS
- **BR-38. Contracts** (AGENTS.md §6.9), in the same PR as the Swift change that writes them: `event.schema.json` and `packages/core-ts/src/events/payloads.ts` accept the new part values; the schema describes `format`, `teil` and `partnerTask`; `fixtures/teacher/exam-events.jsonl` gets the new values.
- **BR-39. Compatibility of old data.** Old journals give the same state. A legacy German session opens read-only as today, with its stored debrief. Its Retry uses the legacy request (`examCriteria(.goetheB1)`, the existing format and limits), and the card renders as before. No new legacy session can be started from the screen.
- **BR-39a. Older builds** (rollback). An older build validates ids against its own catalogue. A Mock session whose three ids are all from the 18 old Goethe ids decodes as a normal exam and opens read-only. A Mock with any new id, and every Training session (one id), decodes as no activity and opens as its stored "Free conversation" (PX-05), where the older build also offers Resume; this is accepted for a rollback, since one owner and one device are affected. New `exam.part` values count as unknown events and everything else is kept (`Merger`). The debrief text shows as plain text. The rollback limit of PX-05 still applies.
- **BR-40. Scoring contract.** `packages/contracts/fixtures/teacher/goethe-scoring.json` holds the table of BR-28, the zero rule and the parser's golden cases. The web has no exams today, so no TypeScript implementation is required now (A-11).
- **BR-41. IELTS unchanged.** IELTS phases, durations, roles, catalogue entries, `examinerRule`, `<exam>` output including `time is up`, debrief request, criteria and limits stay byte-identical, confirmed by the existing tests and snapshots without re-recording. The only shared effect is a longer retention of the speech buffer (BR-07), with no observable change.
- **BR-42. Threat model.** Learner text, notes and catalogue data are data. `<exam>` and all debrief input are in tagged blocks that rule 7 and the debrief prompt treat as data. Notes cannot leak, because no code path gives them to a request, an event, a file or a log (BR-22). Utterances and notes never appear in logs (AGENTS.md §6.10). A malformed letter or code cannot yield invented points (BR-29). There is no new provider, key, account or dependency. Quota: at most one debrief per run, and the intro, Examiner lines and partner's talk cost no model call.

## 8. Acceptance
| ID | Criterion | How |
|---|---|---|
| BAC-01 | Catalogue validates per BR-03…BR-06: 12 tasks per part, links, categories, limits, word counts, the six original tasks of each part unchanged, phrases and Examiner lines, no official title | unit tests; independent content review in G-2 |
| BAC-02 | `ExamCatalog` IELTS entries in `exams.json` are byte-identical to `030eaa3` | diff check in a test |
| BAC-03 | Activity: valid and invalid content per BR-01 decode as specified, unknown format → no activity | unit tests |
| BAC-04 | Mock runs its parts in order with the timers of BR-07; Done and timer end a part; a stale Done does nothing; `goethe_b1.end` only at a natural end; no model call in intro, in the partner's talk or for Examiner lines; corrections `after`, role `Gesprächspartner`; the talk is not stored or shown; the second answer in `goethe_b1.3` gets no reply | `ExamController` tests with a fake sink and engine |
| BAC-05 | Microphone closed during preparation, Examiner lines and the partner's talk; the part timer starts after the line (BR-10) | `ExamController` tests |
| BAC-06 | A 4-minute monologue is held and released whole (BR-07) | audio regression test |
| BAC-07 | Preparation: topic choice, `partnerTask` is the other topic, abandoning leaves no event, a failed session creation keeps the notes (BR-08, BR-08a) | host tests |
| BAC-08 | Training: start from a chosen task, each Teil's parts, corrections `inline`, soft timers, the 240 s monologue limit, Teil 3 with Replay, Done, a closed microphone, notes and a talk that is not stored | `ExamController` and host tests |
| BAC-09 | Voice selection per BR-23: different voice, Premium avoided when the Examiner's is Premium, one installed voice; the panel names the current speaker | unit tests with a fake list; snapshot |
| BAC-10 | Prompts: `examinerRule` unchanged; full Training system prompt contains the inline correction rule and `@hint` and lacks "No spoken corrections"; role texts of BR-24 incl. the open point; `<exam>` at maximum within 700 scalars and 250 tokens; no `questions:` in Mock `goethe_b1.3`; no full talk, no `time is up` in a run with a format; the Mock `goethe_b1.3` request holds the whole learner talk within its cap | snapshot tests |
| BAC-11 | Notes never appear in any request, event or log; gone after the run | unit tests; review of the code paths |
| BAC-12 | Debrief request: grouping by part, intro excluded, finished Teile only, both sides in Teil 1, limits of BR-27, tokens at maximum under 8 000 | unit tests + snapshot |
| BAC-13 | Points: every letter of BR-28, the zero rule, all parser cases of BR-29 incl. the `[T<n>]` blocks, partial failure per Teil | unit tests + `goethe-scoring.json` |
| BAC-14 | Early finish and failure: incomplete marker, nothing to assess, parse failure shows text without points, Retry (BR-31, BR-32) | engine tests |
| BAC-15 | The pronunciation filter and the Goethe-only score filter drop their lines, incl. golden false-positive cases; `PronunciationFilter` is unchanged; no total, level or pass/fail on the card | unit tests + snapshot |
| BAC-16 | Mock hides Hints, Translate, In Russian (⌥R has no effect) and typing; Training keeps them with useful phrases and no topic-phrases request | host tests + snapshot |
| BAC-17 | Goethe screen: Teacher entry, tabs and Start locked for the whole Mock, chips, real counts incl. legacy, right panel, Debriefs list; RU and EN, light and dark, DESIGN.md tokens only; mockup against implementation in both themes (DESIGN.md §8) | `check-design`, `--ui-snapshot`, evidence images |
| BAC-18 | Contracts: schema, TS payloads and fixtures accept the new values | `npm test`, Swift fixture tests |
| BAC-19 | Old journals decode to the same state; a legacy German session opens with its debrief and legacy Retry; against a pinned list of the 18 old Goethe ids, a Mock with old ids validates and one with a new id does not | unit tests |
| BAC-20 | IELTS unchanged per BR-41: IELTS snapshots are not re-recorded and IELTS assertions are not edited. Permitted edits in shared tests are the Goethe values only (`ExamTests` Goethe durations, the monologue list gaining the Goethe intro) | `swift test`, `git diff` of tests and snapshots |
| BAC-21 | Three single daytime debrief requests from synthetic transcripts (one Mock, two Training) parse fully, with no pronunciation line and no total | diagnostic through the signed app; NOT RUN with a reason if no key is available |
| BAC-22 | Peak memory during a Mock with two voices stays within the 1.2 GB budget | `metrics.py` during H-10 |
| BAC-23 | Owner tries one Mock and one Training at H-10 | owner checkpoint |
