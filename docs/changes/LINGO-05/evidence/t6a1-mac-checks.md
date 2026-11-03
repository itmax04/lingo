# T-6a1 local Mac checks

Status: verified working tree, before the implementation commit · Date: 2026-11-03 · Base: `9d3f681` (PR #81).
Worktree: `/Users/macbook/Developer/lingo-74` · Branch: `feat/74-exam-runner`.

## Environment and baseline

Local arm64 Mac, macOS 15.7.2 (24G325), Xcode selected at `/Applications/Xcode.app/Contents/Developer`,
Apple Swift 6.2.4, Node v26.0.0, npm 11.12.1, gh 2.97.0. Node satisfies package.json's `>=26.0.0` alternative.
`git fetch origin`: main and origin/main at `9d3f681`, tree clean; PR #81 MERGED. #74 OPEN, depends on merged #73.

| Command (baseline main) | Actual result |
|---|---|
| `swift build --package-path apps/mac && swift test --package-path apps/mac` | PASS: `Test run with 265 tests in 65 suites passed after 10.136 seconds.` |
| `npm ci && npm test` | PASS: 301 tests, 7 files |
| `apps/mac/scripts/check-core-ios.sh` | PASS: 59 objects, `LC_BUILD_VERSION platform=2 (iOS)` |
| `python3 scripts/check-design.py` | FAIL in main: `AssertionError: Keep only the root DESIGN.md` (another DESIGN.md in the pre-existing `.claude/worktrees` checkout); PASS in the isolated worktree on the same commit: 19 tokens, 88 contrast pairs, 496 bilingual strings |
| `scripts/check-english.sh` (isolated worktree) | PASS |
| `scripts/secret-scan.sh` (isolated worktree) | PASS: `0 findings` |
| `apps/mac/scripts/build-app.sh` then `codesign --verify --strict dist/Lingo.app` (main) | PASS: build 201, `9d3f681`, signed with the existing InterviewCopilot identity. Owner's app at `/Users/macbook/Developer/lingo/dist/Lingo.app` now includes T-5 |

No system settings, permissions, trust, accounts or secrets were changed. No live provider calls were made.
The main-checkout design failure was not fixed by editing another agent's worktree.

## T-6a1 implementation

| Command (isolated worktree) | Actual result |
|---|---|
| `LINGO_RECORD_FIXTURES=1 LINGO_RECORD_SNAPSHOTS=1 swift test --package-path apps/mac --filter ExamTests` | PASS: 7 tests; exports original catalogue, phase-event fixture and examiner/max-block snapshots |
| `LINGO_RECORD_SNAPSHOTS=1 swift test --package-path apps/mac --filter 'PromptBuilderTests\|WarmupTests\|ScenarioTests'` | PASS; existing system snapshots change only rule 7 to include `<exam>` as data |
| `swift build --package-path apps/mac && swift test --package-path apps/mac` | PASS: `Test run with 272 tests in 66 suites passed after 9.892 seconds.` |
| `apps/mac/scripts/check-core-ios.sh` | PASS: 62 objects, `LC_BUILD_VERSION platform=2 (iOS)` |
| `npm ci && npm test` | PASS: 302 tests, 7 files; valid and malformed exam payloads match Swift |
| `python3 scripts/check-design.py` | PASS: 19 exact color tokens, 88 computed contrast pairs, 496 bilingual strings |
| `scripts/check-english.sh` | PASS |
| `scripts/secret-scan.sh` | PASS: `0 findings` |
| `git diff --check` | PASS |

ExamTests covers XR-01 field sizes/counts, linked Part 2/3 selections, tolerant settings decoding, stored roles/modes/corrections,
PX-05 canStart, ordered durations, stale actions, one queued transition after repeated expired timer ticks during a turn,
whole-utterance Done detection, event codec/parity, prompt sanitization and PX-03 limits, all actual catalogue questions fitting,
and PX-04 skip guards/no Resume at the engine boundary. No provider tokens were used.

NOT RUN: independent review and CI (recorded on the PR), actual timer/turn integration, monologue holding/release, microphone-off
behaviour and exam UI/screenshots (T-6a2); debrief (T-6b); live model behaviour (owner decision Q-03, H-05).
The pure `microphoneAllowed` state test is not evidence that the microphone is actually disabled.
