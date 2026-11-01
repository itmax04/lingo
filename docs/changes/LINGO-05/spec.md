# LINGO-05: Specification — the teacher on the Mac

ID: LINGO-05-spec · Status: **draft for AI review** · Version: 1.1 · Date: 2026-11-01 · Owner: itmax04 · Risk: R2
Links: [intent.md](intent.md) (Q-01…Q-04, A-01…A-11, D-01) · [plan.md](plan.md) · [contracts](../../../packages/contracts/README.md) ·
[DESIGN.md](../../../DESIGN.md) · design references `design/redesign-2026/04-mac/mac-{today-overview,teacher-soon,progress-soon}-*.png`
Requirements of this change are defined only here: CR (cards), WR (warm-up), SR (scenarios), XR (exams), GR (progress, Today, memory),
PX (prompt, protocol, quota, compatibility), TAC (acceptance). The web and iOS clients are out of scope. Learner texts (answers, memory
facts, goals) are never written to logs.

v1.1 answers the AI review of v1 (findings F-01…F-18): silent tags (F-01), the warm-up protocol (F-02), FSRS pinned to py-fsrs 5.1.3
(F-03, F-04), review de-duplication (F-05), stable card ids and suspension (F-06), warm-up prompt parts (F-07), prompt blocks and token
limits (F-08), the exam voice flow (F-09), the pronunciation filter (F-10), memory facts (F-11), journal-stored goal and memory switch
(F-12), activity compatibility (F-13), the quota table (F-14), statistics definitions (F-15), missing TACs (F-16), the plan split (F-17)
and superseded decisions (F-18, in the intent).

Common definitions: **live session** — a session without `session.deleted`. **Counted message** — a `message.created` with kind `normal`
in a live session (summary, error and system kinds never count). **Local day** — the calendar day in the Mac's current time zone
(`Calendar.autoupdatingCurrent`; tests pass a fixed calendar). **Key** — `VocabularyText.key(lang:text:)` of LINGO-08 (normalised text
with the language prefix). Event order everywhere is (ts, device, seq, id), as in the merger.

## 1. Review cards (FSRS)
- **CR-01. Card.** `id`, `lang`, `kind` (`word` | `mistake`), `front` (what the learner should produce), `hint` (the Russian meaning or
  the rule), `createdAt`.
  - **Word card**: one per key of the vocabulary list of LINGO-08 (`vocabulary(lang:)`, own items and ★ items; an own item hides a ★
    item with the same key, VR-02). `id = word:<key>`, so ★ → own item and same-text duplicates keep one card and one history.
    `front` = the shown item's text, `hint` = its translation, `createdAt` = the earliest `vocab.added`/`phrase.starred` of that key.
    Editing an item's text gives a different key, i.e. a new card (it is a different phrase).
  - **Mistake card** (best-effort grouping, like LINGO-08 PR-01): fixes of live sessions of that language are grouped by
    `VocabularyText.normalize(rule)` cut to 60 Characters; within a group, fixes with the same (session, normalised original) count once
    (so "Reply again" does not double them). A group with ≥ 2 counted fixes is a card: `id = mistake:<lang>:<group key>`, `front` = the
    shortest corrected text of the group (by Character count, then bytes) cut to 80 Characters, `hint` = the latest rule text (event
    order) cut to 120 Characters, `createdAt` = the second counted fix. Known limit: wording drift of the model's rule ("seit + Dativ" vs
    "seit + Dat.") can split a group; recorded, not solved here.
  - A card exists while its source exists. Reviews are never deleted: when the source disappears (item removed, session deleted), the
    reviews stay in the journal and apply again if the same id comes back.
- **CR-02. Events** (additive, journal schema v1):
  - `card.reviewed` `{ card, rating: again | hard | good | easy, source: "warmup", message }` — `message` = the id of the graded learner
    message, "" when the card was skipped (WR-03); session = the warm-up session. The reducer keeps all events but **counts only the
    first review per (session, card)** in event order. Reviews of an unknown card are kept and ignored. There is no manual source in this
    change.
  - `card.suspended` `{ card, suspended: Bool }` — last writer wins per card (lamport, device). A suspended card never enters the queue
    and is not counted in statistics; it can be resumed.
- **CR-03. Schedule** — FSRS-5 exactly as **py-fsrs 5.1.3** `Scheduler.review_card` with the default parameters
  `w = [0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192, 1.01925, 1.9395, 0.11, 0.29605, 2.2698,
  0.2315, 2.9898, 0.51655, 0.6621]`, `DECAY = -0.5`, `FACTOR = 0.9^(1/DECAY) − 1` (= 19/81) and the **Lingo profile**: desired retention
  0.9, no learning steps, no relearning steps, maximum interval 365 days, no fuzzing (the schedule must be identical on every device).
  The state of a card (phase, step, S, D, last review, due, reviews, lapses) is a pure function of its counted reviews in event order:
  - elapsed days `t` = whole days between the last review and this one, rounded down (Python `timedelta.days`);
  - first review with grade G (again 1 … easy 4): `S = max(w[G−1], 0.1)`, `D = clamp(w4 − e^{w5·(G−1)} + 1, 1, 10)`;
  - later reviews compute S from the **old** D first, then D:
    - `t < 1` (same day, takes precedence): `S' = S·e^{w17·(G−3+w18)}`;
    - otherwise `R = (1 + FACTOR·t/S)^DECAY` and for G ≥ 2 `S' = S·(1 + e^{w8}·(11−D)·S^{−w9}·(e^{(1−R)·w10} − 1)·(G=2 ? w15 : 1)·(G=4 ? w16 : 1))`,
      for G = 1 `S' = min(w11·D^{−w12}·((S+1)^{w13} − 1)·e^{(1−R)·w14}, S / e^{w17·w18})`;
    - `D' = clamp(w7·D0(4) + (1−w7)·(D − w6·(G−3)·(10−D)/9), 1, 10)` with `D0(4)` the clamped initial difficulty of easy;
    - there is no stability floor besides the initial 0.1 (as in the reference);
  - interval `I = min(365, max(1, round_half_even(S/FACTOR·(0.9^{1/DECAY} − 1))))` days; `due = last review + I × 86 400 s` (exact time).
  Verification: the Swift port reproduces the published expectations of py-fsrs 5.1.3 `tests/test_basic.py` with py-fsrs's own default
  profile (learning steps 1 and 10 minutes, relearning 10 minutes, maximum 36 500 days): the interval history
  `[0, 4, 14, 44, 125, 328, 0, 0, 7, 16, 34, 71, 142]`, the memo state (S rounds to 49, D to 7.0866), ten easy reviews → D = 1.0, and the
  learning/relearning step timings. `packages/contracts/fixtures/teacher/fsrs.json` pins the Lingo profile (review sequences → S, D, due)
  for the TS port, written by Swift; S and D are compared with a tolerance of 1e-6, due exactly.
- **CR-04. Due queue** per language, deterministic for (journal state, now, calendar):
  - **due cards**: reviewed, not suspended, and the local day of `due` ≤ today (a card due at 20:00 is due all of that day);
  - order: retrievability now ascending (R from whole elapsed days), then kind (mistake first), then `createdAt`, then id bytes;
  - **new cards** (never reviewed, not suspended) follow, ordered by (`createdAt`, id); at most **5 per language per local day**, minus the
    cards of that language whose first counted review falls on today's local day.

## 2. Warm-up
- **WR-01. Session.** `SessionSettings.activity = { kind: "warmup", cards: [ids] }`: up to 8 ids taken from the due queue at the start
  and frozen in the session settings. It starts only when the queue is not empty. Stored for older builds: mode "Questions", topic =
  a fixed study-language title ("Wiederholung meiner Wörter" / "Reviewing my words"), the learner's usual correction modes; the assistant
  starts. The warm-up ends when every queued card is reviewed or skipped, or after **5 minutes** of the session; at the time limit the
  current card is finished (its answer or skip) and then the warm-up ends. Resume continues the queued cards that have no counted review
  in this session, with a new 5-minute budget.
- **WR-02. Turn.** **Current card** = the first id in `activity.cards` without a counted review in this session and not skipped; **next
  card** = the one after it, or none. Every request carries, after `</transcript>`, `<card>` (front, hint, kind of the current card) and
  `<next_card>` (the same for the next card, or `none`). The warm-up mode text (PX-02) tells the model: on the opening turn, set up a short
  realistic situation or question that needs the current card (never say its front first); after the learner's answer give a short
  natural reaction, at most one correction sentence, the silent `@grade` for the current card, then set up the next card in the same turn
  (still one question per turn); with no next card, a short closing line without a question. The engine, not the model, decides which
  card is current, so the two cannot drift apart: each request names it again.
- **WR-03. Rating and transitions.** `@grade: again | hard | good | easy | wait` (`wait` = the learner did not attempt the card yet).
  | Learner turn | Rating of the current card | Advance |
  |---|---|---|
  | an answer, the reply has a valid grade (not `wait`) | that grade (capped at `hard` after a Russian turn on this card) | yes |
  | an answer, the reply has `@grade: wait` (question, off-topic, clarification) | none | no |
  | an answer, no valid `@grade` line | word card used by the local matching (LINGO-08 VR-07b, run in a warm-up regardless of the vocabulary switch) → `good`, else none; a mistake card → none | only when rated |
  | a Russian utterance (rule 5: the model gives a version and asks for a repeat) | none now; the next graded answer on this card is capped at `hard` | no |
  | a local command ("repeat", "slower", "how do I say …") | none | no |
  | the `continue` command | skip: `again`, `message` = "" | yes |
  | the second consecutive learner turn on the same card without a rating | skip: `again`, `message` = "" | yes |
  A `@grade` line received before a barge-in still counts. Only the first review per (session, card) counts (CR-02).
- **WR-04. End.** After the last card or at the time limit: a fixed localized closing line in the study language (no model call), then an
  end card on screen: cards reviewed, the again/hard/good/easy counts, and the next due local date. A warm-up never requests a recap, a
  summary, topic phrases or memory extraction (PX-04).
- **WR-05. Card management.** The warm-up end card and the Warm-up screen list the session's cards; each has "Don't practise this card"
  (`card.suspended` true). A "Suspended cards" list on the Warm-up screen resumes them (`card.suspended` false).

## 3. Scenarios
- **SR-01. Catalogue** `packages/contracts/teacher/scenarios.json`, validated by a test: per scenario a unique `id`, `lang`, `title_en`,
  `title_ru`, `level` (A2 | B1 | B2), `role` (Lingo's role, study language, ≤ 80 characters), `situation` (study language, ≤ 300
  characters), `tasks` (3–5 learner tasks, study language, each ≤ 120 characters), `phrases` (3–6 useful phrases with Russian
  translations). At least 8 German (life in Germany: doctor, residents' office registration, flat viewing, bank account, complaint in a
  shop, train delay; work: job interview, team meeting) and 6 English (job interview, meeting, small talk with colleagues, phone call,
  airport, doctor). Synthetic, written for Lingo.
- **SR-02. Session.** `activity = { kind: "scenario", id }`. Stored for older builds: mode "Free conversation", `role` = the scenario role,
  `topic` = the scenario title in the study language, the learner's usual correction modes. The system part gets `<scenario>` (role,
  situation, numbered tasks — constant within the session) and the scenario rule: stay in the role, lead the learner through the tasks in
  order without naming them as tasks, mark a task the learner completed with one silent line `@task: <number>`, and after the last task
  close the situation naturally. The done tasks change per turn, so they go after `</transcript>` as `<scenario_progress>done: 1, 3</scenario_progress>`.
  The phrases are shown as topic hints without a model call.
- **SR-03. Progress.** A valid `@task: n` (1 ≤ n ≤ task count) is recorded as `scenario.task` `{ task: n, message }` the first time n is
  marked in that session; repeats and invalid numbers are ignored. The session header shows the checklist. A scenario is **done** when one
  live session of it has all its tasks recorded.
- **SR-04. Debrief.** "Finish" shows the usual recap when the session has the "after" correction mode (R-23) plus the checklist result;
  nothing else is requested. The topic-phrases request is never made for a scenario.

## 4. Exam modes
- **XR-01. Catalogue** `packages/contracts/teacher/exams.json`, validated by a test; all tasks are written for Lingo (no copied exam
  material):
  - **German B1 speaking (Goethe-style)**: one preparation phase before the exam (up to 15 minutes, the learner can start earlier) with
    the Part 1 and Part 2 tasks on screen; Part 1 "plan something together" (a planning task with 4 points, about 3 minutes); Part 2
    "present a topic" (5 slides, about 3 minutes); Part 3 "talk about the topic" (about 2 minutes); at least 6 tasks per part.
  - **IELTS Speaking**: Part 1 (familiar topics, 8–10 short questions, 4–5 minutes), Part 2 (a cue card, 1 minute preparation, up to 2
    minutes talk, one follow-up question), Part 3 (6–8 discussion questions linked to Part 2, 4–5 minutes); at least 8 Part 1 topics and
    8 cue cards with Part 3 questions.
- **XR-02. Session and roles.** `activity = { kind: "exam", exam: "goethe_b1" | "ielts", tasks: [ids] }` (drawn at the start and frozen).
  Stored for older builds: mode "Free conversation", `role` = "Prüfer" / "Examiner", `topic` = the exam title, corrections "after". An exam
  cannot be resumed (Resume is hidden; the transcript stays). The app runs the parts in order with on-screen timers and records each
  part start as `exam.part` `{ part }`. Roles per part:
  | Part | Lingo | Turn-taking |
  |---|---|---|
  | Goethe 1 | the learner's partner: makes suggestions, sometimes disagrees, keeps to the 4 points | normal turns |
  | Goethe 2 | silent listener | **monologue**: the app holds the learner's utterances (no request) until the time is up, the learner says "fertig" / presses Done; then one request |
  | Goethe 3 | the partner: one short reaction to the presentation and one question; then a short closing | normal turns |
  | IELTS 1, 3 | neutral examiner, one question at a time | normal turns |
  | IELTS 2 | examiner | preparation: microphone off, timer and cue card on screen; talk: **monologue** as Goethe 2; then one follow-up question |
  The examiner rule suspends base rule 5 (Russian → the examiner asks once, in the study language, to answer in that language) and spoken
  corrections (rule 6: only silent `@fix` lines, kept for the debrief); rules 1, 3, 4 and 7 stay. The current part, its task and the
  remaining time go after `</transcript>` in `<exam>`; when a part's time is up, the next request says so and the model moves on with one
  short transition line.
- **XR-03. Debrief.** At the end of the exam one request (purpose `exam_feedback`, PX-04) with the learner's exam turns and the silent
  fixes writes a debrief in Russian with study-language examples: per assessed criterion (Goethe-style: task completion, coherence,
  vocabulary, grammar; IELTS: fluency and coherence, lexical resource, grammatical range and accuracy) a short assessment, 2 strengths,
  3 concrete improvements with better versions of the learner's own sentences, and an indicative **range for the assessed criteria, not
  an overall level or band**, with the note "estimate, not an official score". Pronunciation is never assessed: the prompt says so, and a
  **runtime filter** drops every debrief line that matches the `no_pronunciation` markers (one marker list in LingoCore, also used by the
  eval rule). The debrief is stored as a `summary` message and shown as a card; on failure the card shows "Debrief not available" with a
  Retry button (one request per click, no automatic retry). The live `no_pronunciation` eval stays NOT RUN (Q-03).

## 5. Progress, Today and memory
- **GR-01. Statistics** — pure functions of the journal state and a calendar, per language and in total:
  - **practice seconds** per local day: per live session, the counted messages in event order; each gap between consecutive messages adds
    `min(gap, 120 s)` to the local day of the later message; minutes are shown rounded down;
  - **sessions** per local day: live sessions with at least one counted learner message that day;
  - **learner words**: learner counted messages split on Unicode whitespace; a token counts when it contains a letter;
  - **vocabulary used**: `vocab.used` events per local day;
  - **mistakes**: `fix.recorded` of live sessions, distinct by (message, normalised original, normalised corrected); **per 100 learner
    words per ISO week** (Monday–Sunday, local);
  - **cards**: new (never reviewed), learning (S < 21), mature (S ≥ 21), due today (CR-04); suspended cards are excluded.
  Golden fixture `packages/contracts/fixtures/teacher/stats.json` (a synthetic journal with a gap over midnight, a DST change, a deleted
  session, a duplicate fix, summary messages → the expected numbers), written by Swift.
- **GR-02. Daily goal and streak.** The goal is a journal event `goal.set` `{ minutes }` (5–120; default 15 until the first event; last
  writer wins by lamport, device). A local day **counts** when its practice minutes reach the goal in force at the end of that day, so a
  goal change never rewrites past days. The streak is the number of consecutive counted days up to today (today counts once reached,
  otherwise the streak runs to yesterday).
- **GR-03. Today screen** (replaces the placeholder; reference `mac-today-overview`): a plan row per study language (languages with a
  session in the last 30 days, otherwise German and English) with the **next activity**: the warm-up if that language's queue (CR-04) is
  not empty; otherwise the first scenario in catalogue order that is not done, at the **learner's level** (the level of the latest live
  session of that language, A2 when empty; the scenario level equal to it, else the nearest lower one); otherwise free conversation. Plus
  the warm-up card (queue size, about N minutes with N = ⌈cards × 0.6⌉, start), the daily goal ring and the streak (7 days of dots), and
  "Continue conversation".
- **GR-04. Progress screen** (replaces the placeholder): practice minutes of the last 7 / 30 days (bars), learner words and mistakes per
  100 words per week (lines), cards by state, totals. Swift Charts (system framework).
- **GR-05. Weekly report.** On "Progress": the last 7 local days computed locally (minutes, counted days, sessions, vocabulary used,
  the 3 most frequent mistake groups with one example each, cards reviewed). "Advice from Lingo" makes one request (purpose
  `weekly_report`) from these numbers and examples only (no transcript) for 4–6 sentences of advice in Russian, stored as `report.weekly`
  `{ week: "YYYY-Www", text }`. When a report for the current ISO week exists, it is shown and the button becomes "Update" (an explicit new
  request); repeated clicks never send a request while one is running.
- **GR-06. Memory.** "What Lingo knows about me" shows the profile (goals and interests, LINGO-08), the recurring mistakes, and **memory
  facts** — short sentences in Russian about the learner (≤ 120 characters), for one language or general.
  - Events: `memory.noted` `{ text, lang: "de" | "en" | "" }`, `memory.updated` `{ fact, text }` and `memory.removed` `{ fact }` where
    `fact` is the id of the `memory.noted` event; the latest `memory.updated` wins; `memory.removed` is final. The switch is a journal
    event `memory.switched` `{ on }` (last writer wins; default on).
  - Extraction: once per session, on its first "Finish", when memory is on, the session is not a warm-up or an exam, it has ≥ 4 counted
    learner messages, and the quota allows (PX-04). Input: the learner's lines (the last 30, at most 3 000 characters) and the current
    fact texts; output: up to 3 new facts the learner said about themselves. Excluded by the prompt: facts about other people, health,
    religion, politics, sexuality and finances. Locally, a proposed fact whose key equals the key of a live or removed fact is dropped.
  - Use: the 5 most recent live facts (event order) of the session language or general go into `<profile>` as data, frozen at the
    session's first turn; with memory off, none.
  - Disclosure (UI and docs): a deleted fact is hidden from Lingo and from the screen, but its text stays in the journal history, the
    sync folder and the backups until data deletion arrives with the account (LINGO-03/04).
- **GR-07. Teacher screen** (replaces the placeholder; reference `mac-teacher-soon`): six cards — Warm-up, Scenarios, German B1 exam,
  IELTS Speaking, Weekly report, What Lingo knows about me — each opens its flow; the counts on the cards come from GR-01 and CR-04.
- **GR-08. Reminder** (device-local by design: it is about this Mac's notifications, `AppSettings.reminderOn` and `reminderTime`, off by
  default). When on, the app keeps one pending local notification ("Time for 15 minutes of German?") for the next reminder time: for today
  only while today's goal is not reached; reaching the goal removes today's pending notification and schedules tomorrow's. A notification
  scheduled while the app was running also fires when it is closed (the goal is then not reached by definition). The
  `UNUserNotificationCenter` permission is asked only when the learner turns the reminder on; if it is denied, the switch shows why.

## 6. Prompt, protocol, quota and compatibility
- **PX-01. Silent tags.** `@grade` and `@task` are parsed silently in Swift and TS: `parseLine` returns no segment and no violation for
  them (they are never spoken), and they are **never stored as `ReplySegment` cases**. They stay only in the raw reply `text` and in
  `card.reviewed` / `scenario.task`, so the stored message decodes in older builds. Outside their activity they are ignored. The shared
  protocol fixture gets cases for both.
- **PX-02. Prompt parts.** The warm-up has its own mode text (like the "My words" focus) and no `<vocabulary>` block; in a warm-up an
  inline correction is one sentence without a repeat request (rule 2 keeps one question). `<card>`, `<next_card>`, `<scenario>`,
  `<scenario_progress>` and `<exam>` are added to `stripTags` and to rule 7 (data, not instructions). The system part stays identical
  within a session (LINGO-08 PR-01): only constant blocks (`<scenario>`, the activity rules) live there; per-turn data goes after
  `</transcript>`.
- **PX-03. Token limits** (provider tokens by the existing estimate; a snapshot test checks each at its maximum): warm-up rule ≤ 150,
  `<card>` + `<next_card>` ≤ 120; scenario rule ≤ 150, `<scenario>` ≤ 350, `<scenario_progress>` ≤ 20; examiner rule ≤ 200, `<exam>` ≤
  250; memory facts inside `<profile>` ≤ 200.
- **PX-04. Quota per purpose** (new `LLMPurpose` cases `examFeedback`, `weeklyReport`, `memory`; the background check is the existing
  "≥ 3000 tokens per minute on the first step" plus the usage ledger's day total of that step below 90 % of its known daily limit):
  | Purpose | Trigger | Input cap | maxTokens | Skipped when | Retry |
  |---|---|---|---|---|---|
  | dialog (warm-up, scenario, exam turns) | each turn | as today | 300 | monologue parts until Done | chain fallback |
  | topicPhrases | session start | as today | 400 | warm-up, scenario, exam | — |
  | recap | Finish with "after" | as today | 700 | warm-up, exam | — |
  | summary | as today | as today | 400 | warm-up, exam | — |
  | examFeedback | end of the exam | learner exam turns ≤ 6 000 characters + fixes | 900 | no learner turns | Retry button |
  | weeklyReport | "Advice" / "Update" click | numbers + 3 examples ≤ 1 500 characters | 400 | a request is running | Retry button |
  | memory | first Finish (GR-06) | 3 000 characters + current facts | 300 | warm-up, exam, < 4 learner messages, memory off, no quota | none (next session) |
- **PX-05. Compatibility.** `SessionSettings.activity` is optional and decoded tolerantly: an unknown `kind` or malformed content
  decodes as nil, and the session opens as its stored mode (WR-01, SR-02, XR-02). New event types are additive; older builds count them
  as unknown and keep everything else. `canStart` does not require a correction mode for an exam (it stores "after").

## 7. Acceptance
| ID | Criterion | How |
|---|---|---|
| TAC-01 | Cards as CR-01: word cards by key (★ → own item keeps the id), mistake groups with the 60-Character key and duplicate fixes counted once, removal and return keep reviews | unit tests |
| TAC-02 | FSRS: the py-fsrs 5.1.3 published expectations (CR-03) pass with the reference profile; the Lingo profile equals `fsrs.json` (S, D within 1e-6, due exact) | unit tests + fixture |
| TAC-03 | Due queue (CR-04): local-day due, R order, new-card order and the daily limit, suspension | unit tests |
| TAC-04 | Warm-up: frozen queue in `activity.cards`; `<card>`/`<next_card>` in the request; every WR-03 transition; first review per (session, card); 5-minute limit; Resume | engine tests |
| TAC-05 | Scenario: catalogue validates; `<scenario>` in the system part, progress after the transcript; `@task` recorded once; hints without a model call; no topic-phrases request | tests + screenshot |
| TAC-06 | Exams: catalogue validates; parts, roles and timers in order; monologue holding; microphone off in preparation; examiner rule snapshot; debrief request as XR-03; the pronunciation filter drops marker lines | tests + snapshot |
| TAC-07 | Statistics, goal and streak (GR-01, GR-02) equal `stats.json`, incl. midnight, DST and a goal change | unit tests + fixture |
| TAC-08 | Memory: payloads with `fact`; extraction once per session and only as GR-06; duplicate and removed facts filtered; edit, final delete, switch event; facts frozen per session; never logged | engine tests |
| TAC-09 | Today, Teacher, Warm-up, Progress screens and the flows, RU and EN, light and dark (DESIGN.md tokens only) | `check-design`, snapshots |
| TAC-10 | Old journals and settings decode unchanged; teacher sessions decode as their stored mode; an unknown activity kind decodes as nil | unit tests |
| TAC-11 | A teacher reply with `@grade` and `@task` lines decodes with the current `MessageCreated` decoder and the v1 schema; nothing extra is spoken | protocol tests (Swift + TS fixture) |
| TAC-12 | Weekly report (GR-05): local numbers, request without transcript, one stored report per week, "Update" | engine tests |
| TAC-13 | Next activity on Today (GR-03) for: due cards, a not-done scenario at the level, all done | unit tests |
| TAC-14 | Warm-up end card (WR-04) counts and the next due date; card suspension (WR-05) | unit tests + screenshot |
| TAC-15 | Reminder scheduling decisions (GR-08): schedule, remove on goal, next day, permission denied | unit tests; the real notification NOT RUN unless the owner tries it |
| TAC-16 | Requests per purpose follow PX-04 (maxTokens, skip rules); prompt blocks within PX-03 | unit + snapshot tests |
