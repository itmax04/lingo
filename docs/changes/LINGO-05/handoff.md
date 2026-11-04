# LINGO-05 handoff

Status: documents (#67) and T-1…T-5 (#68, #70, #71, #72, #73) merged; T-6a1 foundations: independent re-review APPROVE at `925764d`; merge/rebuild delivery follows the handoff-only commit. Owner app on disk: build 201 (`9d3f681`, includes T-5). Updated 2026-11-04.

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

| T-6a1 exam foundations (partial #74) | [#82](https://github.com/itmax04/lingo/pull/82), branch `feat/74-exam-runner`; review APPROVE at `925764d`; merge delivery pending at handoff commit | `swift build` + `swift test` PASS (273); `npm ci && npm test` PASS (302); check-core-ios, check-design (496 strings), check-english, secret-scan (0 findings), diff check PASS | Original catalogue (6 tasks per Goethe part; 8 IELTS topics and linked cue cards/discussions), frozen settings, tolerant decoding, additive `exam.part` in Swift/TS, pure phase/timer state, examiner/max-block snapshots, skip/resume guards. Independent re-review at `925764d`: APPROVE, F-1/F-2 resolved, no new findings; [review](https://github.com/itmax04/lingo/pull/82#issuecomment-6625259451). Voice/UI integration NOT RUN and not implemented in this partial PR. [Evidence](evidence/t6a1-mac-checks.md) |

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
- Worktree `/Users/macbook/Developer/lingo-74`, branch `feat/74-exam-runner`, base `9d3f681`.
- Independently reviewed implementation: `925764dde918e309c43b4f6df24ff99c325e57b4` (clean local/remote head at review).
  This delivery adds only this handoff; identify its commit with `git log -1`. No code, tests or snapshots were edited by the reviewer.
- PR [#82](https://github.com/itmax04/lingo/pull/82): [independent re-review APPROVE](https://github.com/itmax04/lingo/pull/82#issuecomment-6625259451),
  no open findings. Final-head CI, squash merge and the owner's main build happen after this handoff commit. Read the PR delivery
  comment for their actual outcome and inspect `~/Developer/lingo/dist/Lingo.app/Contents/Info.plist` for build/revision.
  At handoff authoring, the owner app is still build 201 (`9d3f681`); do not infer a newer build from this document alone.

## Done in the review-fix follow-up and re-review (2026-11-04)
- F-1: `Dialogue/PromptBuilder.swift` makes rule 4b exam-aware: keep the current task/question sequence and redirect off-topic
  requests. Ordinary subject-switch behavior and transcription-artifact rules 4/4a are preserved.
- F-2: the system command fallback records mistakes only as silent `@fix` lines for the debrief and continues the exam.
  Ordinary command text remains byte-identical; the ordinary detected-command task is unchanged.
- `ExamTests.fullExamPromptKeepsTaskAndMistakesSilent` checks full requests for both exam kinds/languages, off-topic and mistakes
  utterances, and locally detected/transcript-only requests. It rejects both conflicts and preserves ordinary conversation behavior.
- Only `prompt-exam-goethe_b1.txt` and `prompt-exam-ielts.txt` were re-recorded in the implementation: rules 4b and 8 changed.
- Fresh independent re-review of the commits after `78c8dea` and affected composition: APPROVE at `925764d`; both P2 findings resolved.

## Verified (independent re-review at `925764d`, 2026-11-04)
- `swift build --package-path apps/mac && swift test --package-path apps/mac`: PASS, 273 tests in 66 suites, 9.846 s.
  Full-request regressions, ordinary/scenario/warm-up/exam snapshots and PX-03 maximum-size/sanitization checks pass without recording.
- `npm ci && npm test`: PASS, 302 tests in 7 files; audit 0 vulnerabilities.
- `apps/mac/scripts/check-core-ios.sh`: PASS, 62 objects, `LC_BUILD_VERSION platform=2 (iOS)`.
- `python3 scripts/check-design.py`: PASS, 19 exact color tokens, 88 contrast pairs, 496 bilingual strings.
- `scripts/check-english.sh`, `git diff --check`: PASS. `scripts/secret-scan.sh`: PASS, 0 findings.
- CI at `925764d`: swift-test, hygiene and test all SUCCESS. Tests left the tracked tree clean.
- Live model/device checks: NOT RUN (Q-03); voice/UI integration is not implemented in T-6a1.

## Open
- #74 remains incomplete: no start integration/event emission, monologue holding/release, actual mic-off, timer task or exam screen.
  `ExamRun.microphoneAllowed` and queued transitions are pure state only. `DialogEngine.resume` is guarded; UI hiding is T-6a2.
- The old worktree `/Users/macbook/Developer/lingo-t1` on `feat/5-t6a-exam` remains untouched.
- No owner action or spec conflict is currently blocking the next implementation stage.

## Next step
**Standard: T-6a2 integration for #74, in a new session after delivery of PR #82.** First read PR #82's delivery comment and verify
its merged state, `origin/main`, and the owner's bundle revision. If delivery is still incomplete, finish the eligible merge/rebuild
under CODEX.md §§3.9/6; do not merge without green final-head CI. The only allowed post-review source change is this handoff.
Create a fresh issue-specific worktree/branch from merged `origin/main`; do not reuse another agent's checkout or rebase pushed history.
Read spec XR-02/PX-02…PX-05, plan T-6a2, issue #74, `Teacher/ExamRun.swift`, `Dialogue/DialogEngine.swift`,
`Dialogue/TurnController.swift`, and the Mac service/view entry points. Connect dialogue/voice coordination, held monologue and one
release request, phase events, preparation mic-off, start guards, timer/turn/cancellation tests, Teacher cards, exam panels and hidden
Resume. Add RU/EN light/dark screenshots on a synthetic journal. Split coordination and UI into partial PRs if needed for 600 lines.
Run CODEX.md §4 checks and independent review before each merge. #74 closes only after integration is checked and merged;
T-6b #75 stays blocked until then. No live model calls. Stop for owner-only actions or a spec conflict, not routine choices.
