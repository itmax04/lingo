# LINGO-05 handoff

Status: documents (#67) and T-1…T-5 (#68, #70, #71, #72, #73) merged; T-6a1 foundations reviewed: changes-required (two P2 prompt conflicts). Owner app on disk: build 201 (`9d3f681`, includes T-5). Updated 2026-11-04.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Documents v1 | #67 | AI review: changes-required (F-01…F-18) | Owner decisions Q-01…Q-03 in intent.md (2026-11-01): Mac now, all four blocks plus useful additions, no night evals |
| Documents v1.1 | #67 | AI re-review: approve-with-notes (no P0/P1); notes N-01…N-18 applied | All findings answered (the spec v1.1 header lists where); Q-04: the teacher goes before the new HFL / Stand Your Ground modes |
| T-1 cards and FSRS | #68 | `swift test` PASS (220); `npm test` PASS (287); check-core-ios, check-english, secret-scan PASS; FSRS vs py-fsrs 5.1.3 test expectations PASS; the reviewer's independent formula script reproduced `fsrs.json` (27 states, 0 mismatches); py-fsrs itself NOT RUN; AI review approve-with-notes, notes F-1…F-9 applied | 621 changed lines without fixtures (86 of them pretty-printed schema JSON), slightly above the 600 guideline, accepted as stated in the PR |
| T-2 statistics, goal and streak | #70 | `swift test` PASS (228); `npm test` PASS (287); check-core-ios, check-english, secret-scan PASS; `stats.json` recorded; AI review approve-with-notes, F-1…F-7 applied | GR-01 refined in the spec: the 600 s break rule and portable definitions of words, uses, mistakes and weeks |
| T-3 warm-up engine | #71 | `swift test` PASS (250); `npm test` PASS (301); check-core-ios, check-design, check-english, secret-scan PASS; prompt snapshots re-recorded (rule 7) + 2 warm-up snapshots; AI review changes-required (1 P1), F-1…F-12 applied | No UI yet (T-4). The model's `@grade` is not tested live (Q-03). TS `decodeSettings` drops `activity` (acceptable under D-01; the web decodes it when it implements the warm-up). Re-review: approve-with-notes, R-1/R-2/R-3/R-5 applied. Accepted: R-4 ("Reply again" on an answer that ended in an unrated-limit skip names the newer card) and R-6 (`warmupNamedNext` is in memory only: after a restart a card set up after the deadline is dropped and the warm-up ends) |
| T-4 Today, Teacher, warm-up flow | #72 | `swift test` PASS (257); `npm test` PASS (301); AI review approve-with-notes, F-1…F-9 applied (end card by the engine's own finished state, a double click and an unreviewed warm-up reopen instead of duplicating, banner on Today/Teacher, plural forms en/ru, accessibility labels, scrolling card list, top-aligned grid, minute clock); check-core-ios, check-design (plural-aware, 492 strings), check-english, secret-scan PASS; screenshots on a synthetic journal (light and dark): Today, Teacher, end of a warm-up | First usable warm-up: Today and Teacher start it; Today shows goal ring, streak, plan; the end card has counts, next review date and "Don't practise this card"; the Teacher screen lists suspended cards. Other teacher cards stay "Coming soon". The warm-up is not yet tried by the owner with a live model (Q-03) |
| T-5 scenarios | #73 | `swift test` PASS (265); `npm test` PASS (301); check-core-ios, check-design, check-english, secret-scan PASS; screenshots: scenario session with checklist, picker | Catalogue in Swift (9 DE: doctor, Bürgeramt, Ausländerbehörde, flat viewing, bank, complaint, train, interview, team meeting; 6 EN), written to `packages/contracts/teacher/scenarios.json` by the tests; `title` (study language) added to SR-01. Live model behaviour of `@task` NOT RUN (Q-03). AI review changes-required (1 P1: the level fell to A2 after a warm-up), F-1…F-14 applied: the learner's level comes from their own ordinary sessions only; the opening turn never marks a task; task < 1 is unknown in Swift and TS; Start guards a double click; scenario wording fixes. Decision: the checklist sits above the input (not in the header), the header subtitle says "Scenario" |

| T-6a1 exam foundations (partial #74) | [#82](https://github.com/itmax04/lingo/pull/82), branch `feat/74-exam-runner`; review changes-required, merge pending | `swift build` + `swift test` PASS (272); `npm ci && npm test` PASS (302); check-core-ios, check-design (496 strings), check-english, secret-scan (0 findings), diff check PASS | Original catalogue (6 tasks per Goethe part; 8 IELTS topics and linked cue cards/discussions), frozen settings, tolerant decoding, additive `exam.part` in Swift/TS, pure phase/timer state, examiner/max-block snapshots, skip/resume guards. Independent review at `78c8dea`: changes-required, F-1/F-2 (P2), no P0/P1; [review](https://github.com/itmax04/lingo/pull/82#issuecomment-6624957890). Voice/UI integration NOT RUN and not implemented in this partial PR. [Evidence](evidence/t6a1-mac-checks.md) |

## Executor decisions
- D-01 (intent): rule 9 applies when TypeScript implements cards, FSRS, statistics or memory; until then contracts and core-ts event/tag decoding land with each step.
- FSRS reference: py-fsrs 5.1.3 (`fsrs/fsrs.py`, `tests/test_basic.py`) read from GitHub. Running the downloaded reference code was
  blocked by the agent environment, so the Swift port is checked against the reference's published test expectations instead of
  vectors produced by the reference itself. Optional for the owner: `pip install fsrs==5.1.3` and compare `fsrs.json`.

- D-02 (T-6a split, #74 issue comment): T-6a1 is the catalogue/contracts/pure state/prompt foundation; T-6a2 connects the dialogue/voice
  coordinator and UI. Split coordination/UI further if needed for the 600-line limit. Only the final PR closes #74; #75 stays blocked.
  The actual catalogue fits the prompt in full; hypothetical maximum-size task data is bounded to a 700-scalar excerpt to keep `<exam>`
  under 250 estimated provider tokens. Complete task/points/questions stay available to the UI. No new dependency or live call.
- Baseline: `origin/main` is `9d3f681` (PR #81 merged). Main was clean and the Mac baseline passed (Swift 265, TS 301, iOS core).
  Its design check fails on a duplicate DESIGN.md in the existing nested `.claude/worktrees` checkout; the same-commit isolated worktree
  passes. Do not modify that other agent's checkout. The owner's app was rebuilt and codesign-verified at main (build 201); it does not
  contain the unmerged T-6a1 code. Live model checks remain NOT RUN (Q-03).

## Current work identity
- Worktree `/Users/macbook/Developer/lingo-74`, branch `feat/74-exam-runner`, base `9d3f681`, implementation commit `bb0f0bd`.
  Independent review checked head `78c8dea5c97b6810bf032a96a1810158ee9c3760`; local/remote head agreed and the tree was clean.
  This follow-up changes only `handoff.md`, is committed before delivery, and does not change the reviewed implementation.
- PR [#82](https://github.com/itmax04/lingo/pull/82) is OPEN. [Independent review](https://github.com/itmax04/lingo/pull/82#issuecomment-6624957890):
  **changes-required**, no P0/P1; two open P2 findings. No merge or owner-app rebuild in the review session.

## Verified (independent review, 2026-11-04)
- `swift test --package-path apps/mac` at `78c8dea`: PASS, 272 tests in 66 suites, 9.982 s.
- `npm test` at `78c8dea`: PASS, 302 tests in 7 files.
- Read-only assertions on both `prompt-exam-goethe_b1.txt` and `prompt-exam-ielts.txt`: both conflicting instruction pairs CONFIRMED.
- `gh pr checks 82` at `78c8dea`: hygiene PASS (86 s), TS PASS (24 s), Mac swift-test PASS (85 s). No manual CI rerun.
- Original implementation build/iOS/design/language/secret checks: [evidence](evidence/t6a1-mac-checks.md).
  Separate build/iOS/design reruns in this review: NOT RUN; no implementation changed.
- Handoff publication: `scripts/check-english.sh` PASS; `scripts/secret-scan.sh` PASS (0 findings); `git diff --check` PASS.
- Live model/device checks: NOT RUN (Q-03; voice/UI integration is not implemented yet).

## Open
- **F-1 (P2)** `Teacher/ExamPrompt.swift:5`, composed with `Dialogue/PromptBuilder.swift:87`: the examiner must keep its task,
  but rule 4b demands switching to the learner's new subject and never returning. Make rule 4b exam-aware; retain rules 4/4a.
- **F-2 (P2)** `Dialogue/PromptBuilder.swift:95–99,161–163`: rule 6 forbids spoken corrections, but rule 8 still requests the ordinary
  3–5-point mistakes review, each also as an `@fix`. Make the exam mistakes-command fallback silent-only and continue the exam.
- Both are confirmed prompt contradictions, not observed live-model failures. Full exam snapshots currently preserve them;
  tests assert the new prohibitions exist but do not assert the conflicting ordinary instructions are absent.
- #74 remains incomplete: no start integration/event emission, monologue holding/release, actual mic-off, timer task or exam screen.
  `ExamRun.microphoneAllowed` and queued transitions are pure state only. `DialogEngine.resume` is guarded; UI hiding is T-6a2.
  The old worktree `/Users/macbook/Developer/lingo-t1` on `feat/5-t6a-exam` remains untouched.

## Next step
**Standard: fix the two T-6a1 review findings in a fresh implementation session**, on this branch and PR #82.
Read the [review](https://github.com/itmax04/lingo/pull/82#issuecomment-6624957890), `Teacher/ExamPrompt.swift`,
`Dialogue/PromptBuilder.swift`, `Tests/LingoCoreTests/ExamTests.swift` and the two exam system snapshots under `packages/contracts/prompts/`.
Scope rule 4b and the mistakes-command fallback to exam behavior; preserve ordinary conversation prompts/commands.
Add full-prompt assertions for both exam kinds, including detected and transcript-only mistakes requests; re-record the exam snapshots
and recheck PX-03 sizes. Run Swift/TS tests and the applicable CODEX.md §4 checks, update this handoff, commit and push without rewriting
history. Then independent re-review of the new commits in a fresh strong session. F-1/F-2 must be fixed or explicitly answered;
no merge before that review and green head CI. A handoff-only commit does not require code re-review (CODEX.md §6).
After an eligible merge, rebuild the owner's clean main app per CODEX.md §3.9.
Only then start T-6a2 (standard): dialogue/voice coordination, held monologue and one release request, phase events, preparation mic-off,
start guards, timer/turn/cancellation tests, Teacher cards, exam panels, hidden Resume and RU/EN light/dark synthetic screenshots.
#74 closes only after integration is checked and merged; do not start T-6b #75 before then.
No live model calls. Stop for owner-only actions or a spec conflict, not routine choices.
