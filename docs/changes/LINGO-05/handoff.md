# LINGO-05 handoff

Status: documents (#67) and T-1…T-5 (#68, #70, #71, #72, #73) merged; T-6a1 foundations prepared, independent review pending. Owner app on disk: build 201 (`9d3f681`, includes T-5). Updated 2026-11-03.

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

| T-6a1 exam foundations (partial #74) | This PR, branch `feat/74-exam-runner`; review/merge pending | `swift build` + `swift test` PASS (272); `npm ci && npm test` PASS (302); check-core-ios, check-design (496 strings), check-english, secret-scan (0 findings), diff check PASS | Original catalogue (6 tasks per Goethe part; 8 IELTS topics and linked cue cards/discussions), frozen settings, tolerant decoding, additive `exam.part` in Swift/TS, pure phase/timer state, examiner/max-block snapshots, skip/resume guards. Voice/UI integration NOT RUN and not implemented in this partial PR. [Evidence](evidence/t6a1-mac-checks.md) |

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
  The following handoff-only commit records this state. No uncommitted changes at delivery.
- Exact check commands/results: [T-6a1 Mac evidence](evidence/t6a1-mac-checks.md), checked implementation tree committed as `bb0f0bd`.
- Independent review: NOT RUN. CI: consult the current PR (`gh pr view feat/74-exam-runner`, then `gh pr checks`).
- Open: #74 is incomplete. No start integration/event emission, monologue holding/release, actual mic-off, timer task or exam screen yet.
  `ExamRun.microphoneAllowed` and queued transitions are pure state only. `DialogEngine.resume` is guarded; UI hiding is still T-6a2.
  The old worktree `/Users/macbook/Developer/lingo-t1` on `feat/5-t6a-exam` remains untouched.

## Next step
**Strong: independent read-only review of the T-6a1 PR in a fresh session**, following [CODEX.md §5–6](../../process/CODEX.md).
Resolve the PR with `gh pr view feat/74-exam-runner`. Read its diff, XR-01/XR-02 (foundation subset), PX-02…PX-05, this handoff and
[T-6a split](plan.md). Review the original catalogue, phase roles/durations, settings/event compatibility, token bounds/snapshots and
skip guards; rerun Swift/TS tests. Assess this partial scope honestly: no claim of completed TAC-06 voice flow or TAC-09 screenshots.
Post verdict and reviewed SHA as a PR comment. No merge until green CI, no open P0/P1 and every P2 fixed or answered (CX-02).
If review changes code, hand findings to a fresh standard implementation session; re-review after fixes. A handoff-only update can
record the review without a new code review. After an eligible merge, rebuild the owner's clean main app per CODEX.md §3.9.
Then start T-6a2 in a new standard session: DialogEngine/TurnController coordinator, monologue holding and release (one request),
exam.part writes, preparation mic-off, frozen tasks, one start under double click, timer/turn/cancellation tests, Teacher cards and
exam panels, hidden Resume, RU/EN light/dark synthetic screenshots. #74 closes only when that integration is checked and merged.
Do not start T-6b #75 before #74 is complete. No live model calls; stop for owner-only actions or a spec conflict, not routine choices.
