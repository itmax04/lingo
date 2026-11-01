# LINGO-05: Intent — the teacher on the Mac

ID: LINGO-05-intent · Status: **accepted** (owner, 2026-11-01) · Version: 1.1 · Date: 2026-11-01 · Owner: itmax04 · Risk: **R2**
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
| Q-04 | Finish the teacher before the new HFL / Stand Your Ground modes? | "Finish the teacher completely", "teacher, then the modes" (2026-11-01) | LINGO-05 goes first; the brainstorm of the new modes is recorded for a later change |

### Superseded decisions
Q-01 supersedes, for the Mac, LINGO-03 **O-04** (the teacher comes after the web) and **O-19** (the Mac joins the account before the
teacher). The ROADMAP's LINGO-05 row also listed telc and a role split (partner / analyst / planner); both are **out** of this change
(Goethe-style B1 only; one model role per activity). ARCHITECTURE's "teacher via the engine after LINGO-04" is replaced in the docs step
(plan T-9).

### Executor decision
- **D-01** (AGENTS rule 9, contracts first): the TypeScript ports of cards, FSRS, statistics and memory are deferred to the web work
  (LINGO-03 Stage 2), because the owner paused the web ("Mac first", 2026-11-01). This change still puts the shared parts into
  `packages/contracts` (event schema, catalogues, `fsrs.json`, `stats.json`) and updates `packages/core-ts` for everything a shared
  journal or reply needs today: the new event types (decoded, counted as known) and the silent `@grade` / `@task` tags.

## Assumptions (executor, R2: recorded, not blocking)
- A-01: Cards come from two sources: vocabulary items (incl. ★) and recurring mistakes (grouped `@fix` records). A card is created by the
  first source event; its schedule is derived only from `card.reviewed` events (event sourcing, no stored schedule). Reviews come only
  from warm-ups in this change (no manual review flow).
- A-02: FSRS-5 exactly as py-fsrs 5.1.3 with the published default parameters, ported into LingoCore without a dependency (the ADR rule
  applies only to new dependencies). Target retention 0.9, no minute steps, maximum interval 365 days; no tuning in this change.
- A-03: A warm-up rating comes from the turn: the model grades the target in a silent `@grade` line (`wait` when the learner did not
  attempt it); without it, the local vocabulary detection decides for word cards, and a card that stays unrated for two turns is
  skipped as `again`.
- A-04: Scenarios, exam parts, cue cards and topics are data in `packages/contracts/teacher/` (language data in the study language, UI
  titles in English and Russian), so the web can reuse them.
- A-05: Exam debrief and the weekly report each cost one model request, only at the end of an exam or on the learner's click; memory
  extraction costs one background request per session, only when the quota allows (the LINGO-01 R-52 background check). The full
  table is spec PX-04.
- A-06: Additive only: new event types and optional `SessionSettings` fields (an older build shows a teacher session as a normal
  session). Rollback: the events stay in the journal and older builds ignore them.
- A-07 (addition): a daily goal in minutes (default 15) and a streak of days that reached it, shown on "Today".
- A-08 (addition): a mistake bank — recurring mistakes become cards automatically, so the warm-up practises them.
- A-09 (addition): an optional daily reminder (a local macOS notification at a chosen time, off by default).
- A-10 (addition): a noisy card can be suspended and resumed (`card.suspended`), so a vague mistake group does not keep coming back.
- A-11: the daily goal and the memory switch are journal events (they follow the learner to other devices later); the reminder is
  device-local on purpose.

## Definition of done
All TAC criteria of [spec.md](spec.md) have evidence (PASS, or NOT RUN with a reason); `swift test`, `check-core-ios`, `check-design`,
`check-english`, `secret-scan` pass; an independent AI review has no open P0/P1 on each PR; RU/EN screenshots of the new screens.
Live model checks are NOT RUN by owner decision Q-03 unless the owner asks for them.
