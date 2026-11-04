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

## PR #83 review fixes (2026-11-04)

Review: [changes-required at `3395859`](https://github.com/itmax04/lingo/pull/83#issuecomment-6625855530).
All three findings have implementation fixes; independent re-review is still required.

- F-1 (P1): reset exam segmentation after each closed utterance, so the next continuous fragment has its own audio span.
  The duration-aware fake recognizes a standalone Done only from short audio, exposing the old cumulative-span failure.
- F-2 (P2): reserve every closed fragment before STT, retain its audio in a serial recognition task chain, and keep all capture
  reservations across recognition/journal I/O. Deadline/Done transitions wait for the entire queue, including the final flush.
  Input after a queued transition is rejected; Stop invalidates reservations and prevents queued STT/late journaling.
  Normal-part deadlines also drain the queue before entering preparation, without an extra answer request.
- F-3 (P2): exam audio retention is bounded to 185 seconds (180-second Goethe limit plus padding/VAD/timer slack), about 12 MB
  of Float samples in memory. Ordinary conversation keeps its 60-second cap. This uses the review's larger-buffer alternative,
  preserving the whole monologue for one recognition call without new model requests, dependencies or persisted audio.

Regression evidence: `ExamAudioRegressionTests` adds six tests (eight argument cases including 65/120/180-second monologues).
The five-test regression suite (before adding the normal-part deadline test) was also run against the original production files
from `3395859`, with the new test harness unchanged:
**expected FAIL**, 14 assertion failures reproducing F-1/F-2/F-3 (including lost starts at all three durations). Production edits
were restored before final checks. The cancellation case passed on both versions. The normal-part deadline test was added afterward.
An initial focused run on the fixes failed because the test's constant-amplitude tone was correctly classified as background noise,
the IELTS harness could consume its opening before assigning context, and a call-count log was mistaken for request text.
Fixed the synthetic syllable envelope and test context/request recorder; no test delay or product workaround was added for these.

Final local checks on the review-fix working tree based on `3395859` (commit identity recorded in handoff/publication comment):

- PASS: `swift build --package-path apps/mac` — build complete, 9.85 s.
- PASS: `swift test --package-path apps/mac` — 287 tests in 69 suites, 10.517 s, including all six new tests and unchanged snapshots.
- PASS: `apps/mac/scripts/check-core-ios.sh` — 63 objects, platform=2, 8.90 s.
- PASS: `python3 scripts/check-design.py` — 19 exact tokens, 88 contrast pairs, 496 bilingual strings.
- PASS: `scripts/check-english.sh`, `git diff --check`.
- PASS: `scripts/secret-scan.sh` — 0 findings before publication. Final-head CI: see the PR publication checkpoint.
- NOT RUN again: npm (no TS/contracts changes; original 302-test result above is historical).
- NOT RUN: real providers, microphone/devices, `--selftest` (uses live providers), owner metrics (no live turn), app rebuild/UI,
  independent re-review. Only synthetic audio and mock recognition/providers/speech were used.

The owner explicitly requested fixes/tests in this same PR. Its total diff now exceeds the ~600-line guideline because of the
regression coverage; retain the existing scope and PR for re-review rather than splitting the corrections away from their findings.
