# LINGO-05 handoff

Status: T-1…T-6a1 merged. T-6a2a PR #83 review fixes implemented and locally checked; independent re-review pending. Owner app: build 202 (`fa6146c`). Updated 2026-11-04.

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

| T-6a2a core coordination (partial #74) | [#83](https://github.com/itmax04/lingo/pull/83), branch `feat/74-exam-integration`; review changes-required at `3395859`, F-1/F-2/F-3 fixed pending re-review | Swift build + 287 tests, iOS core (63 objects), design (496 strings), English and diff PASS; publication scan/CI below | `ExamController`, DialogEngine exam snapshots, TurnController capture/flush/speech integration; 8 original + 6 regression tests. AppServices/UI not connected yet (T-6a2b); #74 stays open. [Evidence](evidence/t6a2a-mac-checks.md) |

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
- Worktree `/Users/macbook/Developer/lingo-74-integration`, branch `feat/74-exam-integration`, base `fa6146c`, PR #83.
- Fixes/tests/evidence: `4ef5c99`, based on reviewed `3395859`; the next commit changes this handoff alone.
  Local checks ran on the exact source/test tree committed as `4ef5c99`. Use `git log -1` and the PR publication comment for the final
  submitted head; expected tracked working tree after publication: clean.
- [Independent review](https://github.com/itmax04/lingo/pull/83#issuecomment-6625855530): changes-required at `3395859`.
  F-1 (P1 cumulative audio), F-2 (P2 dropped fragments), F-3 (P2 monologue truncation) have implementation fixes and regressions.
  Independent re-review: NOT RUN. Merge/rebuild: NOT RUN; owner's app remains build 202 (`fa6146c`).

## Verified (review fixes, 2026-11-04)
- `swift build --package-path apps/mac`: PASS (9.85 s); `swift test --package-path apps/mac`: PASS, 287 tests, 69 suites, 10.517 s.
- Six new offline regressions (eight argument cases): continuous non-overlapping fragments/Done, delayed recognition queue plus
  deadline flush, queued Done, normal-part deadline into preparation, cancellation, and full 65/120/180-second monologues.
  Original production files at `3395859` reproduce all three findings (expected FAIL, 14 assertions); see evidence for harness fixes.
- `apps/mac/scripts/check-core-ios.sh`: PASS, 63 objects, platform=2. Design: PASS, 496 bilingual strings.
- English, diff check and secret scan (0 findings): PASS. Final-head CI: see the PR publication checkpoint.
- npm: NOT RUN again (no TS/contracts changes); previous 302-test PASS remains historical.
- No live providers/audio/devices, `--selftest`, owner metrics, shipping-app UI, app rebuild or independent re-review.
  Exact commands/results and limits: [evidence](evidence/t6a2a-mac-checks.md).

## Open
- #74 remains incomplete: Mac entry cards, AppServices/VoiceServices attachment, visible timers/panels, hidden Resume and screenshots
  are T-6a2b. The new coordinator is exercised through real DialogEngine/TurnController with fake recognition, provider and SpeechSink.
- Host integration must stop/cancel on selection, deletion or Finish and reapply mic gating after VoiceIO startup/restarts. Stop alone
  cancels coordination; the host still marks a manually finished session ended. Prior/restarted exams are transcript-only.
- Debrief remains #75, blocked until the final #74 PR merges. The old `lingo-t1` worktree is untouched. No owner blocker/spec conflict.

## Next step
**Strong: independent re-review of PR #83 in a fresh session; no implementation edits.** Read CODEX.md §5, this handoff,
evidence/t6a2a-mac-checks.md and the [review findings](https://github.com/itmax04/lingo/pull/83#issuecomment-6625855530).
Review the new commits after `3395859` plus affected segmentation/recognition/capture/transition/cancellation paths; run Swift tests.
Check F-1 audio boundaries, F-2 serial reservations and deadline flush, F-3 retention through both monologue limits, and ordinary-turn
compatibility. Record verdict/findings and exact SHA in the PR. Stop after review; further fixes require an implementation session.
No live providers. #74 stays open, #75 blocked, T-6a2b unstarted. Merge/rebuild only in a later delivery stage after re-review and green
final-head CI under CODEX.md §6; owner's build 202 stays unchanged in this session.
