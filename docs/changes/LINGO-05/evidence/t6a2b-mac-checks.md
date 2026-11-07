# T-6a2b Mac integration checks

Date: 2026-11-04. Base: `1a67e90` (delivered PR #83, owner build 203). Implementation identity is in the handoff.
Scope: XR-02, PX-02…PX-05, TAC-06 runner, TAC-09 exam UI; debrief remains T-6b/#75.

## Local verification

| Check | Result |
|---|---|
| `swift build --package-path apps/mac` | PASS, 3.95 s; subsequent test builds also PASS |
| `swift test --package-path apps/mac` | PASS, 293 tests in 70 suites, 10.764 s; snapshots unchanged, no recording |
| `apps/mac/scripts/check-core-ios.sh` | PASS, 63 objects, platform=2 (iOS) |
| `npm ci && npm test` | PASS, 302 tests, seven test files |
| `python3 scripts/check-design.py` | PASS, 19 color tokens, 88 contrast pairs, 506 bilingual strings |
| `scripts/check-english.sh`, `git diff --check` | PASS |
| `scripts/secret-scan.sh` | PASS, 0 findings; rerun before publication |
| `apps/mac/scripts/build-app.sh` | PASS, signed worktree bundle only; owner's main bundle unchanged |
| `codesign --verify --deep --strict dist/Lingo.app` | PASS on the worktree bundle |

Six host tests (seven argument cases) use actual AppServices, DialogEngine, ExamController and TurnController with isolated settings/journals,
in-memory synthetic credentials, a fake recognizer/provider and a controllable speech sink. They check:
- Duplicate Start creates one exam; preparation rejects microphone/text capture and restores the mute gate after simulated reset.
- A phase transition waits for the entire speech lifecycle, applies once, then holds typed monologue fragments; a second immediate
  typed send keeps its draft until the first capture finishes. Finish ends the journal session and invalidates input.
- Selection changes and deletion stop the controller immediately; returning to its transcript cannot resume it.
- Finish during IELTS opening speech cancels playback and ends once, with no summary; natural Goethe completion also detaches.
- Selection before the start task runs creates no session; intentional phrase-playback muting survives until idle.
The inherited exam suites still cover deadlines, queued STT/Done, long audio retention and the PX-04 request skips.

## Screenshots

Built the app in this worktree, then ran the following for each LANGUAGE = en/ru and THEME = light/dark:

```sh
dist/Lingo.app/Contents/MacOS/Lingo --ui-snapshot <output>/capture.png --ui-exams --ui-language LANGUAGE --ui-theme THEME
```

All four commands PASS. [Screenshots](t6a2b/) contain 24 PNGs: Teacher entry cards, Goethe preparation/presentation,
IELTS preparation/cue card, and a prior exam transcript, each at 1280 × 800 points (2560 × 1600 pixels).
All 24 were visually inspected for readable RU/EN labels, task wrapping/scrolling, timers and hidden input/Resume in prior exams.
Goethe preparation includes both planning and presentation tasks in the scrolling panel. The existing Teacher/conversation
references and DESIGN.md components are extended; screenshots use deterministic catalogue selections and synthetic utterances.
These are real SwiftUI renders with fixture phase state, not evidence of live audio or model behavior.

NOT RUN: real providers, real STT/microphone/restart/device checks, `--selftest`, owner metrics and live exam/debrief behavior (Q-03).
Independent review, CI, merge and owner-app rebuild are publication/delivery gates recorded on the PR; they are not local test claims.
No new dependency, prompt/schema/TS change, extra model request, persisted audio or learner-text log was introduced.

## Review fixes F-1/F-2 (2026-11-07)

Review: [changes-required at `a8922d5`](https://github.com/itmax04/lingo/pull/84#issuecomment-6634057538) is superseded only after a fresh re-review.
Fix base: `a8922d5` (implementation `3a2046c` plus handoff-only commits).

- F-1 (P1): `AppModel.apply` marks its automatic pick (no or a deleted selection); `examSelectionChanged(automatic:)` no longer cancels
  a start that has no session yet for that pick, and the start task checks its own generation instead of comparing selections.
  The learner's navigation still cancels a start or a live exam; an automatic pick away from a live exam still stops it.
- F-2 (P2): `ExamRun.isFinishCommand` = the R-22 finish command that is not a whole-utterance Done word. Typed: `sendText` stops the
  runner, journals the line and calls `finishSession`, even when part input is not capturable. Spoken: `TurnController` stops the
  controller before the journal write and calls `onFinishCommand`, in ordinary parts and held monologues. "Fertig"/"Done"/"Finished" stay part completion.

| Check | Result |
|---|---|
| New regressions on the old production files (`a8922d5`), tests only updated | FAIL as expected: auto-selection 2/4 cases (filter = exam language), typed Finish (4 issues), spoken Finish both cases (6 issues); typed Done PASS (behaviour kept) |
| `swift build --package-path apps/mac` | PASS, 5.71 s |
| `swift test --package-path apps/mac` | PASS, 298 tests in 70 suites, 10.123 s; prompt snapshots unchanged |
| `apps/mac/scripts/check-core-ios.sh` | PASS, 63 objects, platform=2 |
| `python3 scripts/check-design.py` | PASS, 19 tokens, 88 contrast pairs, 506 bilingual strings |
| `scripts/check-english.sh`, `git diff --check`, `scripts/secret-scan.sh` | PASS, 0 secret findings |
| `npm ci && npm test` | NOT RUN: no TS/contracts change (302-test PASS above stays historical) |
| Screenshots | NOT RUN again: no view, string or token change |

New tests: host auto-selection with the app's real `store.observe` → `Task { @MainActor in model.apply }` callback (both exams × both
filters, initial nil selection); typed Finish in IELTS Part 1 (ended, one examiner turn, no capture); typed "Fertig." releases
Goethe Part 2 without ending; spoken "That's all." in IELTS Part 1 and Goethe Part 2 (no answer, release, transition or request
after a 400 s clock jump); Done words are not finish commands.
NOT RUN: live providers, real STT/microphone/VoiceIO restart, shipping-app runtime (Q-03).
