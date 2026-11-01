# LINGO-05: Specification — the teacher on the Mac

ID: LINGO-05-spec · Status: **draft for AI review** · Version: 1 · Date: 2026-11-01 · Owner: itmax04 · Risk: R2
Links: [intent.md](intent.md) (Q-01…Q-03, A-01…A-09) · [plan.md](plan.md) · [contracts](../../../packages/contracts/README.md) ·
[DESIGN.md](../../../DESIGN.md) · design references `design/redesign-2026/04-mac/mac-{today-overview,teacher-soon,progress-soon}-*.png`
Requirements of this change are defined only here: CR (cards), WR (warm-up), SR (scenarios), XR (exams), GR (progress, Today, memory),
TAC (acceptance). The web and iOS clients are out of scope. Learner texts (answers, memory facts, goals) are never written to logs.

## 1. Review cards (FSRS)
- **CR-01. Card.** `id`, `lang`, `kind` (`word` | `mistake`), `front` (what the learner should produce), `hint` (Russian meaning or
  the rule), `createdAt`. A **word card** exists for every vocabulary item of LINGO-08 (own items and ★ items), `id = vocab:<item id>`,
  `front` = item text, `hint` = translation; it disappears when the item is removed. A **mistake card** exists for every recurring
  mistake group (LINGO-08 PR-01 grouping: normalised rule text, at least 2 `fix.recorded` in live sessions of that language, no time
  window), `id = mistake:<lang>:<normalised rule>`, `front` = the shortest corrected text of the group (≤ 80 Characters), `hint` = the
  rule; `createdAt` = the second fix of the group.
- **CR-02. Event** `card.reviewed` `{ card, rating: again | hard | good | easy, source: warmup | manual }`, session = where it happened
  ("" for manual). Additive (journal schema v1). Reviews of an unknown card are kept and ignored.
- **CR-03. Schedule.** FSRS-5 with the default weights `w = [0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046,
  1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621]`, desired retention 0.9, `DECAY = -0.5`,
  `FACTOR = 19/81`. State per card: stability S, difficulty D, last review, due. The state is a pure function of the card's reviews in
  (ts, device, seq, id) order:
  - first review with grade G (again 1 … easy 4): `S = w[G-1]`, `D = clamp(w4 − e^{w5·(G−1)} + 1, 1, 10)`;
  - later review after `t` days (fractional): `R = (1 + FACTOR·t/S)^DECAY`; difficulty `D' = D − w6·(G−3)·(10−D)/9`, then mean
    reversion `D'' = clamp(w7·D0(4) + (1−w7)·D', 1, 10)`;
  - same day (t < 1): `S' = S·e^{w17·(G−3+w18)}`;
  - recall (G ≥ 2): `S' = S·(e^{w8}·(11−D)·S^{−w9}·(e^{w10·(1−R)} − 1)·(G=2 ? w15 : 1)·(G=4 ? w16 : 1) + 1)`;
  - lapse (G = 1): `S' = min(S, w11·D^{−w12}·((S+1)^{w13} − 1)·e^{w14·(1−R)})`;
  - interval in days `I = max(1, round(S/FACTOR·(0.9^{1/DECAY} − 1)))` (≈ S), capped at 365; `due = last review + I days` (after an
    `again`, due is 10 minutes later, so the card comes back in the same warm-up only if nothing else is due).
  Golden vectors: `packages/contracts/fixtures/teacher/fsrs.json` (review sequences → S, D, due), written by Swift.
- **CR-04. Due queue.** Cards of a language with `due ≤ now`, ordered by (overdue ratio desc, kind: mistake first, createdAt asc, id
  bytes); new cards (never reviewed) come after due ones, at most 5 new cards per day per language. Deterministic.

## 2. Warm-up
- **WR-01. Session.** A warm-up is a session with the optional `SessionSettings.activity = { kind: "warmup" }` in the "Questions"
  mode (an older build shows it as Questions). It practises up to 8 cards (the due queue at the start, frozen) or ends after 5 minutes,
  whichever comes first; the assistant starts.
- **WR-02. Turn.** The request names the current card (front, hint, kind) in a `<card>` block after the transcript (like LINGO-08 PR-02).
  The system part adds the warm-up rule: set up a short realistic situation or question that needs the card (never show or say the
  answer first); after the learner's answer give a short natural reaction (a correction follows the correction modes), then grade it in
  one silent line `@grade: again|hard|good|easy` and move to the next card; one card per turn. Russian only on request (rule 1).
- **WR-03. Rating.** From the reply's `@grade` for the current card. Without a valid `@grade`: a word card used correctly by the local
  matching (LINGO-08 VR-07b) → `good`, otherwise `again`; a mistake card → `again`. Commands and Russian utterances do not rate. The
  `continue` command skips the card as `again`. One `card.reviewed` per card per warm-up.
- **WR-04. Protocol.** `@grade` is a new silent tag in the reply protocol (Swift and TS parsers, fixture cases); outside a warm-up it is
  ignored (no violation).
- **WR-05. End.** After the last card: a short spoken wrap-up (no model call: a fixed localized line in the study language) and a card
  on screen: cards reviewed, again/hard/good/easy counts, next due time.

## 3. Scenarios
- **SR-01. Catalogue** `packages/contracts/teacher/scenarios.json`: per scenario `id`, `lang`, `title_en`, `title_ru`, `level` (A2…B2),
  `role` (Lingo's role, study language), `situation` (study language, ≤ 300 characters), `tasks` (3–5 learner tasks, study language,
  each ≤ 120 characters), `phrases` (3–6 useful phrases with Russian translations). At least 8 German (life in Germany: doctor,
  residents' office registration, flat viewing, bank account, complaint in a shop, train delay; work: job interview, team meeting) and
  6 English (job interview, meeting, small talk with colleagues, phone call, airport, doctor). Synthetic, written for Lingo.
- **SR-02. Session.** `activity = { kind: "scenario", id }`, mode "Custom" semantics without a custom prompt: the system part gets a
  `<scenario>` block (role, situation, tasks as data) and the rule: stay in the role, lead the learner through the tasks in order
  without naming them as tasks, mark a task the learner completed with one silent line `@task: <number>`, and after the last task close
  the situation naturally. The phrases are shown as topic hints (LINGO-01 R-27) without a model call.
- **SR-03. Progress.** `@task` lines are recorded as `scenario.task` events `{ task }`; the session header shows the checklist; a task
  is done once. `@task` is a new silent tag (Swift and TS parsers, fixtures).
- **SR-04. Debrief.** "Finish" shows the usual recap (R-23) plus the checklist result; nothing else is requested.

## 4. Exam modes
- **XR-01. Catalogue** `packages/contracts/teacher/exams.json`:
  - **German B1 speaking (Goethe-style)**: Part 1 "plan something together" (a planning task with 4 points, about 3 minutes), Part 2
    "present a topic" (a topic with 5 steps, about 3 minutes, 1 minute preparation), Part 3 "talk about the topic" (the examiner's
    questions about the presentation, about 2 minutes); at least 6 tasks per part.
  - **IELTS Speaking**: Part 1 (familiar topics, 8–10 short questions, 4–5 minutes), Part 2 (a cue card, 1 minute preparation, up to 2
    minutes talk, one follow-up question), Part 3 (6–8 discussion questions linked to Part 2, 4–5 minutes); at least 8 Part 1 topics and
    8 cue cards with Part 3 questions.
  All tasks are written for Lingo (no copied exam material).
- **XR-02. Session.** `activity = { kind: "exam", exam: "goethe_b1" | "ielts", tasks: [ids] }` (the tasks are drawn at the start and
  frozen). The app runs the parts in order with on-screen timers (preparation and speaking); the system part gets an `<exam>` block
  (the current part, its task, the timing) and the examiner rule: neutral examiner, no corrections or feedback during the exam, one
  question at a time, keep to the part's time (the app tells the model when time is up through the task line).
- **XR-03. Debrief.** At the end one request (purpose `exam_feedback`) with the transcript writes a debrief in Russian with study-
  language examples: per criterion (Goethe-style: task completion, coherence, vocabulary, grammar; IELTS: fluency and coherence,
  lexical resource, grammatical range and accuracy) a short assessment, 2 strengths, 3 concrete improvements with better versions of
  the learner's own sentences, and an indicative level or band range with a clear "estimate, not an official score" note.
  Pronunciation is never assessed (LINGO-01 rule; the debrief prompt says so and `no_pronunciation` is checked offline on fixtures).
  The debrief is stored as a `summary` message (like the recap) and shown as a card.

## 5. Progress, Today and memory
- **GR-01. Statistics** (pure function of the journal state, per language and in total): practice minutes per day (sum of gaps
  between consecutive messages of a session, each gap capped at 2 minutes), sessions per day, learner words per day, vocabulary items
  used (LINGO-08 uses), mistakes per 100 learner words per week, cards: new / learning (S < 21 days) / mature (S ≥ 21 days) / due today.
- **GR-02. Daily goal and streak.** `AppSettings.dailyGoalMinutes` (5–120, default 15). A day counts when its practice minutes reach the
  goal; the streak is the number of consecutive counted days up to today (today counts once reached, otherwise the streak runs to
  yesterday). Local calendar day.
- **GR-03. Today screen** (replaces the placeholder; reference `mac-today-overview`): the plan — one row per study language with the
  suggested next activity (the warm-up if cards are due, otherwise the next scenario not yet done at the learner's level, otherwise free
  conversation) and a start button; the warm-up card (due count, about N minutes, start); the daily goal ring and the streak (7 days of
  dots); "Continue conversation".
- **GR-04. Progress screen** (replaces the placeholder): the last 7 / 30 days of practice minutes (bar chart), words used and mistakes per
  100 words (line), cards by state, totals. Swift Charts (system framework).
- **GR-05. Weekly report.** On "Progress": the last 7 days computed locally (minutes, days, sessions, new words used, most frequent
  mistakes with examples, cards reviewed) and, on the learner's click, one request (purpose `weekly_report`) that writes 4–6 sentences
  of advice in Russian from these numbers and the top mistakes (no transcript). Stored as a `report.weekly` event `{ week, text }`.
- **GR-06. Memory.** "What Lingo knows about me": the profile (goals, interests — LINGO-08), the recurring mistakes, and memory facts.
  A memory fact is a short sentence about the learner (≤ 120 characters, e.g. "Lives in Hamburg and works as a teacher"), per language
  or general. After a session ends (Finish), one background request (purpose `memory`, only when the quota allows) proposes up to 3
  new facts from the transcript as `memory.noted` events `{ text, lang? }`; facts about other people, health details and anything the
  learner did not say about themselves are excluded by the prompt. The learner can edit (`memory.updated`) and delete
  (`memory.removed`, final) each fact and can switch memory off (`AppSettings.memoryOn`, default on; off = no extraction and no facts in
  the prompt). Up to 5 most recent facts of the session language go into the `<profile>` block (LINGO-08 PR-01) as data, frozen per
  session.
- **GR-07. Teacher screen** (replaces the placeholder; reference `mac-teacher-soon`): six cards — Warm-up, Scenarios, German B1 exam,
  IELTS Speaking, Weekly report, What Lingo knows about me — each opens its flow; the counts on the cards come from GR-01.
- **GR-08. Reminder.** Optional daily local notification at a chosen time ("Time for 15 minutes of German?") when the goal is not yet
  reached that day; off by default; uses `UNUserNotificationCenter` permission asked only when the learner turns it on.

## 6. Acceptance
| ID | Criterion | How |
|---|---|---|
| TAC-01 | Cards are derived as CR-01 (word and mistake cards, removal, grouping) | unit tests + fixture |
| TAC-02 | FSRS states equal the golden vectors (first review, recall, lapse, same day, hard/easy factors, intervals, cap) | `fixtures/teacher/fsrs.json` |
| TAC-03 | Due queue order and the new-card limit (CR-04) | unit tests |
| TAC-04 | Warm-up: request carries the current card; `@grade` parsed (Swift and TS); fallback rating; one review per card; commands and Russian do not rate; ends after 8 cards or 5 minutes | engine + protocol tests |
| TAC-05 | Scenario: catalogue validates; request carries the scenario block; `@task` recorded once and shown; hints without a model call | tests + screenshot |
| TAC-06 | Exams: catalogue validates; parts and timers run in order; examiner gives no feedback during the exam (prompt snapshot); debrief request built as XR-03 with no pronunciation | tests + snapshot |
| TAC-07 | Statistics, daily goal and streak (GR-01, GR-02) on synthetic journals incl. midnight and DST | unit tests |
| TAC-08 | Memory: extraction only after Finish and with quota; edit, final delete, off switch; facts in the profile block frozen per session; never logged | engine tests |
| TAC-09 | Today, Teacher, Progress screens and the flows, RU and EN, light and dark (DESIGN.md tokens only) | `check-design`, snapshots |
| TAC-10 | Old journals and settings decode unchanged; teacher sessions open in an older build as normal sessions | unit tests |
