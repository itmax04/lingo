# LINGO-05 handoff

Status: documents (#67) and T-1…T-5 (#68, #70, #71, #72, #73) merged; the owner runs build 196 with the warm-up. Updated 2026-11-03.

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

## Executor decisions
- D-01 (intent): rule 9 applies when TypeScript implements cards, FSRS, statistics or memory; until then contracts and core-ts event/tag decoding land with each step.
- FSRS reference: py-fsrs 5.1.3 (`fsrs/fsrs.py`, `tests/test_basic.py`) read from GitHub. Running the downloaded reference code was
  blocked by the agent environment, so the Swift port is checked against the reference's published test expectations instead of
  vectors produced by the reference itself. Optional for the owner: `pip install fsrs==5.1.3` and compare `fsrs.json`.

## Next step
Rebuild the owner's app with T-5; then T-6a (exam runner). From 2026-11-03 the remaining steps run with Codex
([CODEX.md](../../process/CODEX.md)): one GitHub issue per step in the milestone "LINGO-05 · Teacher" (T-6a #74, T-6b #75, T-7 #76, T-8 #77, T-9 #78,
report #79, then the owner checkpoint H-05 #80).
Before T-6a: PR #81 (this runbook, the completion plan, issues #74–#80; branch `claude/lingo-github-docs-386bb4`) needs an
independent review in a fresh session (CODEX.md §5) and a merge under CODEX.md §6. Checks on f2ca139: `check-english` PASS,
`secret-scan --no-history` 0 findings, link check PASS; CI and the review NOT RUN yet, in the order of the [completion plan](../../plans/COMPLETION-PLAN-2026-11.md).
