# LINGO-05: Intent — the teacher on the Mac

ID: LINGO-05-intent · Status: **accepted** (owner, 2026-11-01) · Version: 1 · Date: 2026-11-01 · Owner: itmax04 · Risk: **R2**
Links: [spec.md](spec.md) · [plan.md](plan.md) · prior: [LINGO-08](../LINGO-08/intent.md) (vocabulary, profile, prompting v2),
[LINGO-07](../LINGO-07-redesign/intent.md) (the "Today", "Progress" and "Teacher" screens exist as placeholders), [ROADMAP](../../ROADMAP.md)

## Problem
Lingo is a good conversation partner but not yet a teacher. It does not bring back what the learner got wrong or wanted to learn, has
no structured situations from real life, cannot train for an exam, and shows no progress. The "Today", "Progress" and "Teacher" screens
are placeholders ("Coming soon"). The roadmap put the teacher after the web engine and the shared account (LINGO-03, LINGO-04); the
owner wants it now, on the Mac.

## Desired outcome
1. **Warm-up with spaced repetition.** The learner's own words (LINGO-08 vocabulary, ★ phrases) and their own recurring mistakes become
   review cards scheduled by FSRS. A short voice warm-up practises the due cards in context; each card gets a rating from the turn.
2. **Scenarios.** Ready situations from life in Germany and work (doctor, residents' office, flat viewing, job interview, meeting …)
   and English work and travel situations, with a role for Lingo, a few concrete tasks to complete and a short debrief.
3. **Exam modes.** The speaking parts of German B1 (Goethe-style) and English IELTS Speaking (Parts 1–3) with the right structure and
   timing, and a criteria-based debrief at the end — never about pronunciation.
4. **Progress and memory.** A progress screen (practice minutes, streak, words used, mistakes, cards), a weekly report, and "What Lingo
   knows about me": the facts Lingo uses about the learner, viewable and deletable.
5. **Today.** A daily plan: the warm-up, a suggested next activity per language, the daily goal and the streak.

## Scope
- In: Lingo for Mac (Swift: LingoCore, LingoMac); `packages/contracts` (new event types, catalogues, golden fixtures); docs.
- Out: the web client and the engine (paused by the owner, 2026-11-01: "Mac first"); the iOS app; paid services; any rating of
  pronunciation (LINGO-01 rule); copying real exam material (all tasks and cue cards are written for Lingo).
- Later sync: everything is stored as journal events, so the web and other devices get it with LINGO-03/04 without migration.

## Owner decisions (2026-11-01)
| ID | Question | Owner's answer (translated from Russian) | Effect |
|---|---|---|---|
| Q-01 | Build the teacher now for the Mac only, without waiting for the web and the account? | "Yes, Mac now" | Mac implementation on the journal; LINGO-04 is no longer a prerequisite for the Mac part |
| Q-02 | What comes first? | "Warm-up and repetition, Scenarios, Exams B1 and IELTS, Progress and memory — and add anything else you think is useful" | All four blocks; executor additions A-07…A-09 |
| Q-03 | Night evals | "Don't run them" (2026-11-01) | No live model batches in this change; offline tests and fixtures only |

## Assumptions (executor, R2: recorded, not blocking)
- A-01: Cards come from two sources: vocabulary items (incl. ★) and recurring mistakes (grouped `@fix` records). A card is created by the
  first source event; its schedule is derived only from `card.reviewed` events (event sourcing, no stored schedule).
- A-02: FSRS-5 with the published default weights, implemented in LingoCore without a dependency (the plan's ADR rule applies only to
  new dependencies). Target retention 0.9; the learner cannot tune weights in this change.
- A-03: A warm-up rating comes from the turn: the model grades the target in a silent `@grade` line; without it, the local vocabulary
  detection decides (used correctly → good, otherwise again).
- A-04: Scenarios, exam parts, cue cards and topics are data in `packages/contracts/teacher/` (language data in the study language, UI
  titles in English and Russian), so the web can reuse them.
- A-05: Exam debrief and the weekly report each cost one model request, only on the learner's click or at the end of an exam; memory
  extraction costs one background request per finished session, only when the quota allows (LINGO-03 dispatcher).
- A-06: Additive only: new event types and optional `SessionSettings` fields (an older build shows a teacher session as a normal
  session). Rollback: the events stay in the journal and older builds ignore them.
- A-07 (addition): a daily goal in minutes (default 15) and a streak of days that reached it, shown on "Today".
- A-08 (addition): a mistake bank — recurring mistakes become cards automatically, so the warm-up practises them.
- A-09 (addition): an optional daily reminder (a local macOS notification at a chosen time, off by default).

## Definition of done
All TAC criteria of [spec.md](spec.md) have evidence (PASS, or NOT RUN with a reason); `swift test`, `check-core-ios`, `check-design`,
`check-english`, `secret-scan` pass; an independent AI review has no open P0/P1 on each PR; RU/EN screenshots of the new screens.
Live model checks are NOT RUN by owner decision Q-03 unless the owner asks for them.
