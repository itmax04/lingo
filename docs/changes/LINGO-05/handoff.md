# LINGO-05 handoff

Status: **LINGO-05 ACCEPTED by the owner on 2026-11-12 (H-05, #80); see "H-05 acceptance" below.** T-1…T-9 merged (last: T-9b, PR #91, `82357ac`). The LINGO-05 report (#79) is in [PR #92](https://github.com/itmax04/lingo/pull/92); then owner checkpoint H-05 (#80). Updated 2026-11-08. Earlier status, kept for history: T-1…T-6a2a merged. T-6a2b Mac wiring/UI in [PR #84](https://github.com/itmax04/lingo/pull/84): independent re-review approve-with-notes at `d358a16` ([review](https://github.com/itmax04/lingo/pull/84#issuecomment-6705310503), no open P0/P1, one P3 note answered in the PR); delivery (merge, owner build) recorded in the PR. Updated 2026-11-07. #74 closes on the merge; T-6b debrief (#75) merged in [PR #86](https://github.com/itmax04/lingo/pull/86) as `b2aa6ff` (review approve-with-notes at `3753531`, F-1/F-3 fixed in `d921f9c`; owner build 205; [delivery](https://github.com/itmax04/lingo/pull/86#issuecomment-6707615848)). #75 closed. #76/T-7 is next.

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
**T-8 Memory (#77) is merged: [PR #89](https://github.com/itmax04/lingo/pull/89), squash-merged by the owner as `e3fb778`.** Independent review approve-with-notes at `0cdd7f5` (no P0/P1); F1 (delete/switch applies in an open session via `PromptProfile.keepingLiveFacts`), F2 (`known_facts`/`learner_lines` in `stripTags`), F3, F4, F6 fixed in `169386b`, the flaky memory tests isolated from the shared `ProviderHealth` in `a9d340d`; F5 accepted. CI green. Owner build and delivery comment: pending. [Evidence](evidence/t8-mac-checks.md).
**T-9a Reminder (#78, part) is merged: [PR #90](https://github.com/itmax04/lingo/pull/90), squash `121f946`.** `Teacher/Reminder.swift` (pure `Reminder.next`, `Reminder.sync` against a `ReminderCenter`), `AppSettings.reminderOn`/`reminderTime` (device-local), `ReminderServices.swift` (`UNUserNotificationCenter` adapter; permission asked only when the switch is turned on), Settings → Reminder, RU/EN strings (plural). `swift test` 347 PASS, check-core-ios, check-design (577 strings), check-english, secret-scan PASS. The real notification is NOT RUN (owner tries it). Independent review at `e36d8e6`: approve-with-notes; F1 (re-sync on day change and wake), F2 (serialised syncs), F3 (re-sync on `didBecomeActive`), F4 (not-yet-asked wording) fixed in `e12bbc2`; re-review approve-with-notes, no P0/P1, P3 notes only (the observers and serialisation are not covered by automated tests: manual/NOT RUN). [Evidence](evidence/t9a-mac-checks.md).
**T-9b docs and screenshots (#78, rest): done in PR #91** (retargeted to `main` after #90 merged; independent review approve-with-notes at `cf5be6c`, no P0/P1, F1–F4 fixed). Docs (ARCHITECTURE, MAC, CODEBASE, ROADMAP, AGENTS, contracts README, completion plan), 32 RU/EN light/dark screenshots in `evidence/t9`, T-7 F1 test tightened. Open from T-7: F2 (fixture advice vs chart trend) and F3 (neutral chart colours); both re-shoot the T-7 screenshots. [Evidence](evidence/t9b-mac-checks.md).
**LINGO-05 report (#79): written in [report.md](report.md) (PR in review); then owner checkpoint H-05 (#80).** T-9b is merged as PR #91 (`82357ac`).
Next after the report: H-05 (#80). Next model: standard → Sonnet 5.5 medium. Start: "Post the Russian H-05 checklist on #80 after the report PR merges."

## Open: H-05 finding, "Start exam" does nothing after the first exam (2026-11-08, owner build 211, `b7b8171`)
- Facts: the German B1 exam started at 08:58:56Z (journal `session.created`, `exam.part` prep → part 1, examiner reply), then ended at 08:59:43Z with the fixed farewell and `session.ended`, no learner turn in between (unknown who pressed Finish). After that both "Start exam" buttons on Teacher (German B1, IELTS) do nothing: no new `session.created`, no banner seen by the owner. The buttons look dimmed in the owner's screenshot (possibly disabled: `model.startingExam || !model.online || model.readOnly` in `TeacherView.examCard`), unconfirmed.
- Checked in code, no cause found: `ExamServices.startExam` guards (`startingExam`, `ending`, `readOnly`), `finishSession` resets `ending`, `stopExam` resets `startingExam`, `shutDownVoice` is bounded to 8 s, banners are shown on Teacher. Not reproduced: the app cannot be clicked from the agent session.
- **Owner screenshot (Teacher, build 211): the red banner "Finishing the session…" is still shown long after the exam ended, the Start exam buttons are inert, the sidebar shows no "Offline"/"No key".** So `finishSession`'s task (`VoiceServices.swift:163-192`) never reaches `ending = false` (the banner is cleared there too) and `startExam` returns at `guard !ending`. `farewell` and `markEnded` completed (journal has both events), so the hang is after `markEnded`: `shutDownVoice()` (`io.isSpeaking` loop is bounded to 8 s; `io.stop()` → `VoiceIO.resetEngine()` is the unverified suspect) or a call that never returns. Still unconfirmed which.
- Whether Finish was pressed by hand is unknown.

### Root cause (found 2026-11-08, supersedes the "suspect" above)
Nothing hangs: an Objective-C exception kills the finish task. Evidence from the still-running owner build 211 (pid 52582, `/usr/bin/log show`, `sample`; in zsh plain `log` is a builtin):
- 09:59:47.243 CET, main thread: `required condition is false: [AVAudioNodeImpl.h:303:AVAE_CheckNodeHasEngine: (_engine != nil)]`, then HIServices `FAULT: com.apple.coreaudio.avfaudio`. AppKit swallowed it; the main thread is idle in the run loop and still handled clicks at 10:11.
- Backtrace: `-[AVAudioNode lastRenderTime]` ← `VoiceIO.stopSpeaking` (`playerSample()`) ← `TurnController.interrupt` ← `TurnController.stopVoice` ← `AppServices.shutDownVoice` ← `finishSession` task.
- Mechanism: `shutDownVoice` calls `io.stop()`; `resetEngine()` replaces `player` with a new node that has no engine; the following `turn?.stopVoice(cancelTurn: true)` reaches `stopSpeaking`, and `playerSample()` reads `lastRenderTime` on that node. The exception unwinds the Swift task, so neither `defer` nor `ending = false` runs. It needs a real `VoiceIO`, so it should happen on every Finish with live audio; `ExamHostTests` use a fake sink and cannot see it.
- Unknown: who pressed Finish, and why the exam ended after 47 s (not investigated).

### State of this fix
- Identity: branch `claude/exam-ending-flag-stuck-a443f9`, base `b7b8171`, nothing committed (2026-11-09). Implemented steps 1-4 of "Next":
  - `VoiceIO.playerSample()` reads the player only when `hasOutput`, `running`, `player.engine != nil` and the engine runs. Test `VoiceIOStopTests` (a real unstarted `VoiceIO`, `stopSpeaking()` before start and after `stop()`) crashed the test process before the fix and passes now.
  - `shutDownVoice` calls `turn?.stopVoice(cancelTurn: true)` before `io.stop()`.
  - `finishSession`: `finishID`, idempotent `releaseFinish(id, timedOut:)`, a main-actor watchdog (`finishTimeout`, 15 s) that clears `ending`, the banner and `pendingContinue` and shows a timeout banner; the late finish task checks `finishID == fid` before speaking or tearing down. Seam `finishTeardown` (test: never returns).
  - `startExam` shows a banner for `ending`, `startingExam` and `readOnly`; RU strings are in `Localizable.xcstrings`; the refusal text is cleared on release / when the start ends.
- Verified (real output, 2026-11-09): full `swift test --package-path apps/mac`, 353 tests: 10 consecutive runs PASS (12.6, 12.3, 13.7, 12.0, 12.6 s, then 11.4, 13.1, 11.4, 11.3, 11.8 s after the test-seam cleanup below; base `b7b8171` reported 11.5-13.8 s). `check-core-ios.sh`, `check-design.py`, `check-english.sh`, `secret-scan.sh` (0 findings): PASS. A parallel session saw two failing full runs (`ChainTests.shortRateLimitWaitsAndRetries`, `TurnControllerTests.s05MergeCancelsAndCombines`, 17-21 s) that did not reproduce here; both tests pass alone and in 10 full runs, and were not changed. Likely cause: CPU contention from concurrent builds/tests (timing-sensitive tests), not proven. The one thing in the new tests that could outlive a test, the never-returning `finishTeardown` stand-in, now ends when the test ends. Independent review, PR, live Finish then Start exam on a new build: NOT RUN.
- Rejected: moving `io.stop()` to a GCD thread. Off the main run loop nothing catches an `NSException`, so the app would crash. Swift `do/catch` and `defer` do not handle or survive it either.

### Next
1. (done) Regression test first: a real unstarted `VoiceIO()` (no microphone needed; `AVAudioEngine` input is not touched) must survive `stopSpeaking()` before start and after `stop()`; add it, and a host test where `services.turn`'s sink is a real `VoiceIO`. Red is a crash of the test process.
2. (done) Fix: in `VoiceIO.playerSample()` read the player only when it is attached and running (`guard hasOutput, running, …`). Check the other `player` uses in `VoiceIO`. In `shutDownVoice` call `turn?.stopVoice(cancelTurn: true)` before `io.stop()`.
3. (done) Make `ending` impossible to stick: `defer` is not enough. Add a `finishID: UUID?`, one idempotent `releaseFinish(id)` (clears `ending` and the finishing/refusal banner), and a separate main-actor watchdog task (15 s: goodbye wait 8 s + teardown) that survives the unwinding of the finish task, clears `pendingContinue` and shows a timeout banner. After a release, a late finish task must not call `shutDownVoice` or speak. Test the watchdog through a seam that never returns.
4. (done) Banner when `startExam` is refused: `ending` → "The session is still finishing. Try again in a moment."; `startingExam` → "An exam is already starting." (cleared when the start ends); `readOnly` → `model.disabledReason`. Add RU to `Localizable.xcstrings`. A refusal text must not outlive the finish.
5. Checks: full `swift test`, `apps/mac/scripts/check-core-ios.sh`, check-design, `scripts/check-english.sh`, `scripts/secret-scan.sh`; independent review; PR (it may need #93 first or a rebase on it). The owner confirms on a new build: Finish, then Start exam. Build 211 (pid 52582) can be quit. Then continue H-05 (#80, checklist posted in the issue).


## H-05 acceptance (2026-11-12)
- The owner accepted LINGO-05 in chat ("I accept LINGO-05", written in Russian), after trying the teacher on the Mac and the learner's own scenarios (PR #117, merged `e0ab5cb`).
- The exam "Finishing the session…" finding was fixed in PR #94 (`030eaa3`).
- Not independently evidenced by the executor: live-model behaviour of `@grade`, `@task`, exams and memory is covered only by the owner's own use (Q-03, no night evals).
- Follow-ups outside LINGO-05: golden fixture for `activity.custom`; `custom.lang` against the session language; signal 6 at test exit on `main` not checked; #108 flaky TurnControllerTests.
- Next: close #80 and epic #29; then LINGO-09 (completion plan row B1), which starts with questions to the owner about the HFL and Stand Your Ground modes.
