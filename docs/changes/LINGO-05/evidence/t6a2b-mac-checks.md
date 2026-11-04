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
