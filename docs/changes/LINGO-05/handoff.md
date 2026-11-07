# LINGO-05 handoff

Status: T-1…T-6a2a merged. T-6a2b Mac wiring/UI in [PR #84](https://github.com/itmax04/lingo/pull/84): independent re-review approve-with-notes at `d358a16` ([review](https://github.com/itmax04/lingo/pull/84#issuecomment-6705310503), no open P0/P1, one P3 note answered in the PR); delivery (merge, owner build) recorded in the PR. Updated 2026-11-07. #74 closes on the merge; T-6b debrief (#75) implemented locally on `claude/t-6b-debrief-155925`, not yet reviewed or published.

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

| T-6a1 exam foundations (partial #74) | [#82](https://github.com/itmax04/lingo/pull/82), branch `feat/74-exam-runner`; merged as `fa6146c`; review APPROVE at `925764d` | `swift build` + `swift test` PASS (273); `npm ci && npm test` PASS (302); check-core-ios, check-design (496 strings), check-english, secret-scan (0 findings), diff check PASS | Original catalogue (6 tasks per Goethe part; 8 IELTS topics and linked cue cards/discussions), frozen settings, tolerant decoding, additive `exam.part` in Swift/TS, pure phase/timer state, examiner/max-block snapshots, skip/resume guards. Independent re-review at `925764d`: APPROVE, F-1/F-2 resolved, no new findings; [review](https://github.com/itmax04/lingo/pull/82#issuecomment-6625259451). Voice/UI integration NOT RUN and not implemented in this partial PR. [Evidence](evidence/t6a1-mac-checks.md) |

| T-6a2a core coordination (partial #74) | [#83](https://github.com/itmax04/lingo/pull/83), merged `1a67e90`; independent APPROVE at `f6705f8` | Swift build + 287 tests, iOS core (63 objects), design (496 strings), English, diff, secret scan and CI PASS | `ExamController`, DialogEngine exam snapshots, TurnController capture/flush/speech integration. Owner build 203; [delivery](https://github.com/itmax04/lingo/pull/83#issuecomment-6632843656), [evidence](evidence/t6a2a-mac-checks.md) |
| T-6a2b Mac wiring/UI (#74) | [#84](https://github.com/itmax04/lingo/pull/84), branch `feat/74-exam-ui`, implementation `3a2046c`, review fixes `ea15ee0`; review changes-required at `a8922d5`; **approved** at `d358a16` ([re-review](https://github.com/itmax04/lingo/pull/84#issuecomment-6705310503), no open P0/P1) | Swift build + 298 tests, iOS core, design (506 strings), English/diff, secret scan (0 findings) PASS at `ea15ee0`; npm 302 and signed worktree bundle PASS at `3a2046c`; CI: see PR checks | Teacher start cards, task/cue panels, timers/Done, service attachment/input/speech lifecycle and transcript-only prior exams. Nine host tests; 24 RU/EN light/dark screenshots. [Evidence](evidence/t6a2b-mac-checks.md) |

## Executor decisions
- D-01 (intent): rule 9 applies when TypeScript implements cards, FSRS, statistics or memory; until then contracts and core-ts event/tag decoding land with each step.
- FSRS reference: py-fsrs 5.1.3 (`fsrs/fsrs.py`, `tests/test_basic.py`) read from GitHub. Running the downloaded reference code was
  blocked by the agent environment, so the Swift port is checked against the reference's published test expectations instead of
  vectors produced by the reference itself. Optional for the owner: `pip install fsrs==5.1.3` and compare `fsrs.json`.

- D-02 (T-6a split, #74 issue comment): T-6a1 is the catalogue/contracts/pure state/prompt foundation; T-6a2 connects the dialogue/voice
  coordinator and UI. Split coordination/UI further if needed for the 600-line limit. Only the final PR closes #74; #75 stays blocked.
  The actual catalogue fits the prompt in full; hypothetical maximum-size task data is bounded to a 700-scalar excerpt to keep `<exam>`
  under 250 estimated provider tokens. Complete task/points/questions stay available to the UI. No new dependency or live call.
- D-03: T-6a2 is split into T-6a2a core coordination and T-6a2b Mac wiring/UI to keep reviewable PRs below ~600 lines.
  IELTS's two-minute held talk releases one follow-up in Part 2; its answer starts Part 3. Duplicate Done/ticks during the follow-up
  do not skip it. Goethe's release starts Part 3 with its reaction/question in one request. No live calls (Q-03).
- Delivered baseline: PR #82 squash-merged at `fa6146c`; delivery comment confirms green final-head CI and rebuild. This session
  verified `origin/main` and the owner's bundle: build 202, revision `fa6146c`. The old `lingo-74` worktree is untouched.

- D-04 (PR #83 review fixes): reserve closed audio before serial STT and delay transitions until every reservation finishes.
  Retain up to 185 seconds of exam audio in memory (about 12 MB), covering the 180-second maximum plus slack; ordinary conversations
  keep 60 seconds. No extra model calls. The owner requested fixes and regressions in the same PR, so the resulting review
  scope exceeds the ~600-line guideline; no separate corrective PR is created.

## Current work identity
- Worktree `/Users/macbook/Developer/lingo/.claude/worktrees/lingo-05-handoff-continue-50ef7e` (Claude Code), branch `feat/74-exam-ui`
  checked out from `origin/feat/74-exam-ui` at `a8922d5`; the original `lingo-74-ui` worktree no longer exists.
- Review-fix commit `ea15ee023f93f5779b150e4a919a53160c8386dc` (code, tests, evidence); this handoff commit follows it alone.
  Base `1a67e904b37e21aaae7195cd76d7a40c0f907140`. Identify the published head with `git log -1`; check CI on that head.
- PR #83 delivery (merged `1a67e90`, owner build 203, codesign PASS) was re-verified before work. Other worktrees untouched.

## Executor decisions (T-6a2b)
- D-05: `ExamController.onStarted` lets the host select/load the new session before input or the opening request; busy changes notify
  observers. AppServices attaches one runner to TurnController, including typed capture reservations and full reply/speech consumption.
  Start has a generation guard; selection/deletion/Finish cancels captures/timer/speech. Existing/restarted exams never attach a runner.
- D-06: preparation shows tasks and timer with Done/Finish; input is hidden. Goethe preparation includes the presentation task too.
  Prior exams show only their transcript, with no Resume/edit/regenerate; Finish still journals session completion. The existing
  Teacher/conversation components and references are extended. No new dependency, prompt, schema or extra provider request.
- D-07 (review F-1): only `AppModel.apply`'s pick for a missing/deleted selection is automatic. During a start without a session it is
  ignored; `onStarted` then selects the exam session. Explicit navigation still cancels; any selection away from a live exam stops it.
- D-08 (review F-2): R-22 "that's all" ends an exam session typed or spoken, also in held monologues and while part input is not
  capturable (Finish button parity). The runner is stopped before the line is journaled. Whole-utterance Fertig/Done/Finished stay
  part completion (XR-02). The fixes add ~140 lines to a PR already near the guideline; kept in the same PR as with D-04.

## Verified (review fixes, 2026-11-07, at `ea15ee0`)
- `swift build --package-path apps/mac` PASS (5.71 s); `swift test --package-path apps/mac` PASS (298 tests, 70 suites, 10.123 s);
  prompt snapshots unchanged. New regressions FAIL on the old production files (F-1 2/4 cases, typed and both spoken Finish cases).
- iOS core PASS (63 objects, platform=2); design PASS (506 bilingual strings); English, diff check, secret scan PASS (0 findings).
- NOT RUN: npm (no TS/contracts change; 302-test PASS at `3a2046c` is historical); screenshots (no view/string/token change);
  live providers, real STT/microphone/VoiceIO restart, `--selftest`, shipping-app runtime (Q-03). [Evidence](evidence/t6a2b-mac-checks.md).

## Verified (T-6a2b implementation, 2026-11-04, at `3a2046c`)
- Swift build/293 tests, npm 302, iOS core, design, English/diff, secret scan PASS; worktree bundle build and deep/strict codesign PASS;
  24 fixture screenshots (Teacher, Goethe/IELTS preparation and monologue, prior transcript × RU/EN × light/dark) visually checked.

## Open
- Fresh-session re-review of F-1/F-2 and the whole PR is required before merge (CODEX.md §§5–6); no approval is inferred.
- Real VoiceIO startup/restart and live exam flow remain owner-checkpoint evidence; fake-sink gating tests are offline evidence only.
- Debrief remains #75/T-6b, blocked until #74's final runner PR merges. No owner blocker or spec conflict identified.

## Next step
**T-6b debrief (#75): implementation done and verified locally; remaining: delivery.**
1. Push the branch, open the PR (closes #75), bind it with ccd_pr.
2. Independent fresh-context review (`sdlc:reviewer`) without open P0/P1; verdict and SHA in a PR comment; fix findings.
3. Green CI, squash-merge under CODEX.md §6, rebuild the owner's app, record delivery in the PR and here; list live debrief quality and live `no_pronunciation` eval as NOT RUN for H-05.
Implementation: `PronunciationFilter` (LingoCore, one marker list, used by `DialogRules`), `LLMPurpose.examFeedback`, `PromptBuilder.examFeedbackRequest` (`Teacher/ExamDebrief.swift`), `DialogEngine.examDebrief` (stored `summary` message, no auto retry, no concurrent request), `AppServices.runDebrief` (end of exam, Finish, Retry), `ExamDebriefCard`. [Evidence](evidence/t6b-mac-checks.md).
Next model: standard → Sonnet 5.5 medium. Start: "Deliver T-6b debrief (#75) from the handoff."
