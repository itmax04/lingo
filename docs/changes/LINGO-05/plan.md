# LINGO-05: Plan

ID: LINGO-05-plan · Status: draft for AI review · Version: 1.1 · Date: 2026-11-01 · Risk: R2 · Links: [intent.md](intent.md) · [spec.md](spec.md)

One step = one PR (≤ 600 changed lines without fixtures and catalogues), each with tests, an independent AI review and green CI before
merge. Mac and shared contracts only (D-01): `packages/contracts` gets the schemas, catalogues and golden fixtures; `packages/core-ts`
gets the new event types and the two silent tags, so the shared journal and protocol fixtures stay valid for both. No live model batches
(owner decision Q-03); every model-facing piece is covered by prompt snapshots and offline rules. v1.1 splits the old T-2 and T-5
(review F-17) and moves the statistics core before the screens that need it.

| Step | Content | Requirements | Checks |
|---|---|---|---|
| T-1 | Cards and FSRS: card derivation, `card.reviewed` (first per session and card) and `card.suspended`, the FSRS-5 port with the py-fsrs checks, the due queue; schema, `fsrs.json` | CR-01…CR-04 | TAC-01…TAC-03, TAC-10 (events) |
| T-2 | Statistics core: practice minutes, sessions, words, uses, mistakes, card states; `goal.set`, goal per day and streak; `stats.json` | GR-01, GR-02 | TAC-07 |
| T-3 | Warm-up engine: `activity` (tolerant decoding), frozen queue, `<card>`/`<next_card>`, warm-up mode text, `@grade` silent tag (Swift + TS parsers, protocol fixture), WR-03 transitions, time limit, Resume, end data; `stripTags`/rule 7; PX-03 snapshots | WR-01…WR-04, PX-01…PX-03, PX-05 | TAC-04, TAC-10, TAC-11, TAC-16 (part) |
| T-4 | Today and Teacher screens, the warm-up flow UI, end card, card suspension, daily goal setting | GR-03, GR-07, WR-04, WR-05 | TAC-09 (part), TAC-13, TAC-14 |
| T-5 | Scenarios: catalogue + validation, `<scenario>` / `<scenario_progress>`, `@task` (Swift + TS), `scenario.task`, picker, checklist, hints | SR-01…SR-04 | TAC-05, TAC-09 (part), TAC-11 (`@task`), TAC-16 (scenario sizes, no topic phrases) |
| T-6a | Exam runner: catalogue + validation, parts, roles, timers, monologue holding, microphone off in preparation, examiner rule, `exam.part` | XR-01, XR-02 | TAC-06 (runner), TAC-09 (part), TAC-16 (exam sizes) |
| T-6b | Exam debrief: request, the `no_pronunciation` marker list moved from `LingoEvalKit/DialogRules.swift` into LingoCore, the runtime filter, the debrief card and Retry | XR-03, PX-04 (exam) | TAC-06 (debrief), TAC-16 (examFeedback) |
| T-7 | Progress screen (charts) and weekly report | GR-04, GR-05, PX-04 (report) | TAC-09 (part), TAC-12, TAC-16 (weeklyReport) |
| T-8 | Memory: events, extraction, filter, "What Lingo knows about me", profile facts, switch | GR-06, PX-04 (memory) | TAC-08, TAC-16 (memory) |
| T-9 | Reminder; docs update (ARCHITECTURE, MAC.md, ROADMAP, AGENTS, contracts README); RU/EN screenshots of all new screens | GR-08 | TAC-09, TAC-15 |

A step that turns out larger than 600 lines (T-3 and T-4 are the likely ones) is split into an engine part and a UI part before review.
Order: T-1 → T-2 → T-3 → T-4, then T-5 … T-9 in this order (each depends only on T-1…T-4 and could be stacked). The owner's app is
rebuilt after T-4 (first usable warm-up) and after each later step.
Risks: model quality of `@grade`/`@task` without live evals (mitigation: `wait` grade, local fallback, the two-turn skip, offline rules
on prompt snapshots, the owner's own sessions); exam content quality (mitigation: written to the public format descriptions, reviewed by
the AI reviewer, marked as an estimate); privacy of memory (mitigation: explicit facts only, visible, editable, deletable, switch, the
"hidden, not erased" disclosure, never logged); FSRS formula errors (mitigation: the port reproduces py-fsrs's published test
expectations; the running reference itself was not executed in the agent environment — the owner can regenerate `fsrs.json` from py-fsrs
if wanted).
