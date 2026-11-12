# LINGO-10: Intent — Goethe-Zertifikat B1 Sprechen on the Mac

ID: LINGO-10-intent · Status: **accepted** by the owner (2026-11-09) · Version: 1 · Date: 2026-11-09 · Owner: itmax04 · Risk: **R2**
Links: [spec.md](spec.md) · [plan.md](plan.md) · [handoff.md](handoff.md) · prior: [LINGO-05](../LINGO-05/intent.md) (exam modes XR-01…XR-03) ·
mockups `design/goethe-b1-2026/`

## Problem
The owner prepares for the Goethe-Zertifikat B1 speaking exam. The German exam built in LINGO-05 only resembles it. It runs as a single
exam with one drawn topic. It has no introductory talk, no notes and no choice of two topics. In Part 3 the learner never gives feedback on
a partner's talk or asks a question about it. Hints, Translate and In Russian stay available. The debrief uses four global criteria with
B1–B2 ranges, so it says nothing about the points of each part. Nothing can be practised alone: the only entry is a full exam, and it has
six tasks per part.

## Desired outcome
1. **A Goethe exam screen** reached from Teacher, with three tabs: Training, Mock exam and Debriefs.
2. **Training** of any single Teil on a chosen task, with hints, immediate corrections and useful phrases, and a debrief of that Teil.
3. **A mock exam in the real format, about 30 minutes.** Preparation of 15 minutes with notes and a choice of two topics, then an unassessed
   introduction, Teil 1, Teil 2 and Teil 3. Lingo plays the partner in a pair exam: it plans Teil 1, reacts to the learner's talk, gives its
   own pre-written talk, and answers the learner's question. No aids, strict timers.
4. **A debrief in the exam's terms:** A–E per official criterion and points per Teil, computed by the app, with no overall total, no pass or
   fail, and the "practice estimate" note.
5. **Twice the material:** 12 original tasks per part with categories, a pre-written talk for each topic, and useful phrases per Teil.
6. **Nothing else changes:** the IELTS exam and every old session work as before.

## Scope
- In: Lingo for Mac; `packages/contracts` (catalogue export, event values, fixtures); `packages/core-ts` payloads for the new event values;
  docs.
- Out, paused by the owner until this change is finished: a custom training timer; an own-vocabulary mode with PDF and pasted material; the
  exam title that reads "Free conversation: …".
- Out, decided: a 4-week plan or exam-date plan (Q3, a later and separate feature); stars and search on tasks (Q8); charts in Debriefs (Q7);
  the "Whole exam" segment in Training (Q6); telc; the web and iOS clients.
- Independent: H-05 (#80), the acceptance of LINGO-05, stays open and does not depend on this change.

## Constraints
- No copied exam material (LINGO-05 XR-01). No pronunciation assessment in any form (AGENTS.md §6.7). $0 (§6.1).
- Quota: only single daytime requests during development; batches at night (§6.5).
- DESIGN.md wins over the owner's mockups. Repository files are English; the owner is addressed in Russian.
- The IELTS exam is unchanged. Every journal and settings change is additive (§6.9).

## Owner decisions (design interview, 2026-11-09; all recommendations accepted)
| ID | Decision | Effect |
|---|---|---|
| Q1 | Simulate the pair exam. Lingo is the partner, plans Teil 1, reacts to the learner's talk and asks a question, and reads its own pre-written talk from the catalogue. The learner gives feedback and asks a question. | BR-08, BR-13, BR-14 |
| Q2 | A–E per criterion and points per Teil, no overall total, no pass or fail. The model returns only the letter; the app computes the points. Keep the "practice estimate" note. Replaces the B1–B2 ranges of XR-03 for Goethe. | BR-27…BR-30 |
| Q3 | No 4-week plan now. An exam-date plan is a later, separate feature. | Out of scope |
| Q4 | 12 original tasks per part with categories. The six existing tasks and their ids stay. | BR-03 |
| Q5 | Exam screen from Teacher. Training: any single Teil, hints on, immediate corrections. Mock: 15 min preparation with notes and a choice of two topics, an unassessed introduction of about 1 min, Teil 1, Teil 2, Teil 3 with answers on the learner's own talk and then feedback and a question on the partner's talk; no Hints, Translate or In Russian; strict timers; debrief at the end. | BR-07…BR-20 |
| Q6 | Training has only Teil 1, Teil 2 and Teil 3. The mockup's "Whole exam" segment is dropped. | BR-34 |
| Q7 | A "Debriefs" tab: a plain list (date, mode, topic) that opens the stored session with its debrief card. No charts. | BR-36 |
| Q8 | No stars and no search. Keep category chips and the real per-task practice count from the journal. | BR-34 |
| Q9 | "Useful phrases for Teil N": about 10 original phrases per Teil in the catalogue, Training only. | BR-05, BR-19 |
| Q10 | "My presentation plan" is the same notes field, also available in Training Teil 2. | BR-22 |
| Q11 | Mock task content is German only; Russian glosses stay in Training; the interface stays Russian. Teil 2 timer 4 min, labelled "3-4 min". | BR-08, BR-20, BR-34 |
| Q12 | The partner's talk is about 3 min, about 400 words; a mock is then about 30 min. | BR-04 |
| Q13 | Two voices: the Examiner in the learner's voice, the partner in a different installed German voice; the same voice with a label when only one is installed. | BR-23 |
| Q14 | The partner's talk text is hidden in Mock; visible with replay in Training; notes are editable while listening. | BR-13, BR-17, BR-22 |
| Q15 | In Mock the learner presents first, then the partner; fixed. | BR-08 |
| Q16 | Training Teil 3: listen to a partner's talk, give feedback and ask a question, then answer one question on the topic. | BR-17 |
| Q17 | Training debrief: one request at the end, A–E and points for that Teil only. | BR-26 |
| Q18 | Early finish: debrief only finished parts, marked incomplete. If the letters cannot be parsed, show the text without points. The existing Retry stays. | BR-29, BR-31, BR-32 |
| Q19 | In Mock, Done may end a part early and the timer moves on otherwise; no typing; the introduction is scripted with no model call and is excluded from the debrief. | BR-09, BR-11, BR-20 |

Mockup corrections accepted without asking (the mockups match DESIGN.md on colours, flat surfaces and no pronunciation rating): page title
24 pt; right panel 272 pt, collapsing below 1280 pt; tabs locked during a running mock; notes stay on screen for the whole exam and stay on
the Mac, never sent to a model. Live Teil and debrief screens have no mockup and build on the existing conversation view under DESIGN.md.

## Assumptions (executor, R2: recorded, not blocking)
- A-01: The Mock session is created at the end of preparation, with the chosen topic frozen in it. A preparation that is abandoned leaves
  nothing in the journal.
- A-02: The Mock order inside Teil 2 and Teil 3 follows the official order, which Q5 and Q15 allow: the learner's talk, the answers about it,
  then the partner's talk, then the learner's feedback and question.
- A-03: The partner talks about the topic the learner did not choose, as a real partner would present a different one.
- A-04: Notes live in memory for one exam run. They are not stored in the journal or on disk and are gone when the run ends.
- A-05: Training timers are informative: dialogue parts do not end at zero. The only forced end is the 4-minute limit of a Teil 2 monologue,
  which the speech buffer requires. A configurable timer stays paused (see Scope).
- A-06: The Examiner's lines are fixed catalogue text. They are spoken and shown in the exam panel and are not stored as messages. They are not sent to a model, except that Training Teil 3 sends the task's catalogue question, so that the partner can react to the answer. Every stored assistant message of a Goethe exam is therefore the partner's.
- A-07: The Debriefs tab lists only sessions of this change. Older German exam sessions stay in the sidebar, unchanged.
- A-08: The rule "E on Erfüllung makes the task 0" applies to Teil 1 only: the asterisk in Übungssatz Erwachsene p. 47 is on the Aufgabe 1
  row alone.
- A-09: A Mock debrief gives strengths and improvements per Teil, not per criterion, so that it fits one request (BR-27).
- A-10: The topic names in the mockups are illustrations. "Ohne Auto leben" appears in the official Übungssatz (p. 28), so it cannot be used.
  The catalogue stays free of official topics (BR-06).
- A-12: Training Teil 1 has no notes field. Q10 and Q14 ask for notes in Teil 2 and while listening, so Training Teil 3 has them too.
- A-13: An older build, after a rollback, opens a Mock with new task ids and every Training session as a normal conversation and can resume it (spec BR-39a).
- A-11: Scoring is Mac-only for now, because the web has no exams. The table and golden cases are a contract fixture, so the web can reuse
  them later (BR-40).

## Definition of done
All BAC criteria of [spec.md](spec.md) have evidence (PASS, or NOT RUN with a reason); `swift test`, `npm test`, `check-design`,
`check-english` and `secret-scan` pass; an independent AI review has no open P0/P1 on the documents and on each PR; the owner has tried one
mock exam at checkpoint H-10 and accepted the change.
