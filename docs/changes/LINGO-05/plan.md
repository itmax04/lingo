# LINGO-05: Plan

ID: LINGO-05-plan · Status: draft for AI review · Version: 1 · Date: 2026-11-01 · Risk: R2 · Links: [intent.md](intent.md) · [spec.md](spec.md)

One step = one PR (≤ 600 changed lines without fixtures and catalogues), each with tests, an independent AI review and green CI before
merge. Mac and shared contracts only; the TS parser gets the two new silent tags so the shared protocol fixture stays valid for both.
No live model batches (owner decision Q-03); every model-facing piece is covered by prompt snapshots and offline rules.

| Step | Content | Requirements | Checks |
|---|---|---|---|
| T-1 | Cards and FSRS: card derivation from vocabulary and mistakes, `card.reviewed` event, FSRS-5 scheduler, due queue; schema, fixtures (`fsrs.json`, cards), README | CR-01…CR-04 | TAC-01…TAC-03, TAC-10 |
| T-2 | Warm-up: `activity` settings field, `<card>` block and warm-up rule, `@grade` tag (Swift + TS parsers, protocol fixture), rating and reviews in the engine, end card; Today screen (plan, warm-up card, goal, streak) and the Teacher screen grid; daily goal setting | WR-01…WR-05, GR-02, GR-03, GR-07 | TAC-04, TAC-07 (goal/streak), TAC-09 |
| T-3 | Scenarios: catalogue (≥ 8 de + ≥ 6 en) with validation, `<scenario>` block, `@task` tag (Swift + TS), `scenario.task` events, picker and checklist UI, hints | SR-01…SR-04 | TAC-05, TAC-09 |
| T-4 | Exams: catalogue (Goethe-style B1 and IELTS), exam runner with parts and timers, examiner prompt, debrief request and card | XR-01…XR-03 | TAC-06, TAC-09 |
| T-5 | Progress and memory: statistics, Progress screen with charts, weekly report, memory events + extraction + "What Lingo knows about me" + profile facts, reminder | GR-01, GR-04…GR-06, GR-08 | TAC-07, TAC-08, TAC-09 |

Order: T-1 → T-2 → (T-3, T-4, T-5 in this order; each depends only on T-1/T-2 and could be stacked).
Risks: model quality of `@grade`/`@task` without live evals (mitigation: local fallback, offline rules on prompt snapshots, the owner's
own sessions); exam content quality (mitigation: written to the public format descriptions, reviewed by the AI reviewer, marked as an
estimate); privacy of memory (mitigation: explicit facts only, visible, editable, deletable, switch off, never logged); FSRS formula
errors (mitigation: golden vectors and monotonicity property tests).
