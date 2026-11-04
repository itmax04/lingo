# T-6a2a core coordination checks

Date: 2026-11-04 · Base: `fa6146c` · Branch: `feat/74-exam-integration` · Local Mac, mocked providers only.

## Scope

`ExamController` connects frozen exam settings and `ExamRun` to journal phase events, the dialog stream and a SpeechSink.
`TurnController.exam` gates preparation audio, routes recognized fragments through capture tokens, flushes a current utterance at
its deadline and consumes exam replies through the normal speech loop. The consumer must await playback completion, not just the
last model token. The Mac application does not instantiate this controller yet: Teacher entry cards, AppServices/VoiceServices
wiring, panels, timer display, hidden Resume and synthetic screenshots are T-6a2b. TAC-06/TAC-09 are not complete.

## Verification

- PASS: `swift build --package-path apps/mac && swift test --package-path apps/mac` — 281 tests in 68 suites, 9.902 s.
- PASS: all eight new tests (ExamControllerTests and ExamVoiceTests), included in that full run.
- PASS: unchanged prompt snapshots, including full exam requests and maximum blocks, without recording.
- PASS: `apps/mac/scripts/check-core-ios.sh` — 63 objects, `LC_BUILD_VERSION platform=2 (iOS)`.
- PASS: `npm ci && npm test` — 302 tests in 7 files, audit 0 vulnerabilities; no TS/contracts diff.
- PASS: `python3 scripts/check-design.py` — 19 exact tokens, 88 contrast pairs, 496 bilingual strings.
- PASS: `scripts/check-english.sh`, `git diff --check`.
- PASS: `scripts/secret-scan.sh` — 0 findings (repeated before publication).
- NOT RUN: live providers, microphone/device behavior, shipping-app integration, screenshots (no UI diff), independent review.

One earlier full run failed in the new delayed-STT test: its fixed 250 ms sleep could finish before recognition when the full suite
ran concurrently. Replaced that sleep with a bounded wait for the actual phase transition; likewise wait for capture release between
held fragments. The final full run above passes. No product delay was added.

## Covered edges

- Goethe preparation rejects input and mutes the sink; parts/events are ordered; held fragments (including a local-command-shaped
  utterance and an embedded non-command “fertig”) are saved separately without provider calls; whole-utterance Done releases once
  into Part 3; the final phase ends the session. Topic phrases, recap and summary produce no extra request.
- IELTS preparation mutes input; deadline waits for a capture token, includes its final transcript, and makes one Part 2 follow-up
  request. Repeated ticks/Done cannot skip that follow-up; its answer starts Part 3 with one new request.
- A deadline while reply/speech is running queues one transition; a normal-turn barge-in is journaled while speech drains and then
  answered; duplicate Start creates one session; Stop invalidates late transcripts, pending transitions and the automatic timer.
- Synthetic continuous audio at a monologue deadline is flushed, recognized with a delay and included before the release request.

## Integration obligations for T-6a2b

Attach one controller per live exam before input is enabled. Update its observed run/busy state from callbacks, route typed input to
`submit`, and let `consume` await the complete TurnController speech lifecycle. Stop the controller and cancel recognition on Finish,
selection change and deletion; mark the session ended through the existing engine flow on Finish. Reapply microphone gating after
voice setup/restarts (VoiceIO.start clears micMuted). A prior/restarted exam has transcript access only, never a new controller.
No background/provider calls or screenshots should be inferred from this core-only evidence.
