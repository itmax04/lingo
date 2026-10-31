# LINGO-01: Technical plan v2 — MVP for the Mac

ID: LINGO-01-plan · Status: **accepted** (2026-10-25) · Version: 2 · Date: 2026-10-25 · Owner: itmax04
Precondition: intent, spec and ADR-0001 were accepted by the owner. Requirements are not repeated here, only references to the R- and AC- numbers of [spec.md](spec.md).
Executor: Claude Code, `claude-opus-5-5`, effort high.
Version 2: the owner decided to start with the Mac and adapt for the iPhone later (Q27). The iPhone checks (spec, section 4) and the utility app
move to LINGO-02. Version 1 of the plan is in the Git history, commit `9e8daa0`.
Translated to English in LINGO-03 P-06 (MR-08); the Russian original is in the Git history of this file.

## Preconditions and state
- Repository `~/Desktop/1/lingo`, private `itmax04/lingo`. Work goes on in `feat/lingo-01`, `main` holds only the initial commit.
- No code is written. All commands below are **new**. While a command does not exist, its result is NOT RUN.
- Reference code: Interview Copilot — `~/Desktop/InterviewCopilot-redesign/<ImageGen results folder>/source` (commit `cf0e764`), directories `Sources/CopilotCore/LLM`, `Secrets`, `STT`.
  The code is **copied with adaptation**, with the source named in the file header.
- **iPhone readiness.** `LingoCore` is written without AppKit and without APIs that are missing on macOS or iOS.
  From P-01 its iOS build is checked by a command (see "Checks"), so that the adaptation in LINGO-02 does not require reworking the core.

## Manual action points (H)
At a point the executor stops, gives a step-by-step instruction in Russian, says what it will check afterwards, and waits for "done". It asks no other questions.

| H | Step | Owner action |
|---|---|---|
| H-0 | P-01 | Confirm the signing certificate: keep the existing "InterviewCopilot" (A-5) or create "Lingo Dev" following the instruction |
| H-1 | P-03 | Create a Groq key (and optionally Mistral, OpenRouter) and enter it in Lingo → "Settings → Keys and models", press "Check". Do not send keys in the chat |
| H-2 | P-04 | Allow Lingo access to the microphone and speech recognition. Read 15 phrases to check recognition from `evals/live-script-mac.md`, part 1 |
| H-3 | P-10 | Choose the iCloud Drive folder `Lingo` in the sync settings; allow access to iCloud Drive when macOS asks |
| H-4 | P-11 | Live check from `evals/live-script-mac.md` (≈40 min) + an interface assessment next to the mockup + a blind assessment of 20 answers (`evals/blind-review.md`) |
| H-5 | P-12 | Acceptance from report.md |

## Files and order
Each step: implementation → step checks → review of its own diff → update handoff.md → commit `P-xx: <short>` → `scripts/secret-scan.sh` → `git push origin feat/lingo-01`.

**P-00. Survey and baseline**
- Record in handoff.md: `git status`, `xcodebuild -version`, `swift --version`, free space.
- Check against the primary sources on the date of the step and record with links:
  - the free limits and models of Groq, Mistral, OpenRouter; whether they require a card;
  - the whisper.cpp release with an XCFramework: tag, size, SHA256.
- The iPhone information from the session of 2026-10-25 is for LINGO-02 and is not used in this plan.

**P-01. Skeleton, theme, window** — R-40, R-41 (static), R-49, AC-11 (part), AC-13, AC-14
- `Package.swift`: targets `LingoCore`, `LingoMac`, `lingo-eval`, `LingoCoreTests`. Platforms: macOS 15, iOS 17 (for the core).
- `LingoMac/Design/Theme.swift`: tokens from DESIGN.md one to one. A three-column window on fixtures:
  the sessions and messages from the mockup, two hints, the voice panel in the "Listening" state.
- Scripts:
  - `scripts/build-app.sh` — `dist/Lingo.app`, signing per A-5;
  - `scripts/secret-scan.sh` — Groq keys `gsk_…`, Mistral, OpenRouter `sk-or-…`, generic `sk-…`; emails and phone numbers; a ban on `private/` in the index;
  - `scripts/check-core-ios.sh` — a `LingoCore` build for `generic/platform=iOS`.
- Checks: `swift build`, `scripts/build-app.sh`, `scripts/check-core-ios.sh`, `scripts/secret-scan.sh`.
  A screenshot of the window next to `lingo-mac.webp` → `evidence/ui-p01.png`; record the text contrast per DESIGN.md §8 in the handoff.
- **H-0.**

**P-02. Journal and sync (core)** — R-34…R-39, S-19, S-20
- `LingoCore/Journal/`:
  - `Event` (R-35);
  - `JournalWriter` (append + fsync);
  - `JournalReader` (R-39);
  - `Merger` (R-37);
  - `SyncFolder` (bookmark, `NSFileCoordinator`, download from iCloud);
  - `SyncScheduler` (R-38).
- Tests:
  - merge: permutations, duplicates, equal `ts`, LWW by `lamport`;
  - a truncated line;
  - 2 writers × 25 messages;
  - the property "the union is commutative and idempotent".
- `lingo-eval sync-write --device <id> --session <id> --count N` — a second "device" for checking S-19 without an iPhone.
  `scripts/sync-check.py <folder>` — compares the message sets, losses and duplicates.

**P-03. Model chain** — R-24, R-25, R-29, R-30, R-44 (keys tab), R-48, S-18, AC-09
- Ported from IC with adaptation:
  - `LLM/ProviderChain.swift` (R-29: triples, unlimited keys, disabling a key, `retry-after`);
  - `ProviderHealth`, `SSEClient`, `KeyVerifier`;
  - `Providers` (OpenAI-compatible);
  - `Secrets/KeychainStore.swift` (service `com.itmax04.lingo`).
- `LingoCore/Dialogue/ReplyProtocolParser.swift` (R-24, streaming), `PromptBuilder.swift` (R-25), `ContextPolicy.swift` (R-04).
- The settings window, the "Keys and models" tab: a list of keys for each provider, "Check", the chain order, models from `GET /models`.
- Tests:
  - the chain with a mock provider: 429 → next key; 401 → key disabled; timeout; exhaustion;
  - the parser on fixtures, including broken lines;
  - PromptBuilder snapshots for the three modes and all combinations of corrections.
- **H-1**, then `GET /models` at Groq. Record the model list in the handoff.

**P-04. Speech on the Mac** — R-08…R-15, R-12, AC-04, AC-16
- `LingoCore/Speech/`:
  - `SpeechRecognizer` (protocol) and the Mac engines per ADR-0001 item 6;
  - `VoiceActivityDetector`;
  - `TurnSegmenter` (R-10, R-11);
  - `SpeechOutput` (AVSpeechSynthesizer, segments, pace, splitting into parts R-15);
  - `BargeInMonitor` (R-12, voice processing).
- `LingoCore/Commands/CommandDetector.swift` and `evals/commands/*.yaml` (≥ 90 phrases ru, de, en, ≥ 25% negative).
- `evals/audio/`: synthetic `say` recordings (en Samantha/Daniel, de Anna, ru Milena), mixed ones joined with ffmpeg. Reference texts.
- `lingo-eval stt --engine <id> --set evals/audio`: WER, language detection, latency, memory. Record the engine choice in ADR-0001.
  Delete the unused whisper models from the disk.
- Checks: `swift test`; `scripts/run-evals.sh commands` (≥ 95%); `scripts/run-evals.sh turn`. **H-2** → AC-16 on live phrases.

**P-05. Dialogue quality** — R-03, R-16…R-21, R-24…R-26, AC-05, AC-06
- `evals/dialog/*.yaml`: ≥ 80 cases from the patterns P1–P16 (evals/README.md), synthetic data only.
- `lingo-eval dialog --source chain` → `evals/out/dialog-chain.json`. Rules and judge per evals/README.md.
- Choosing the default Groq models and the chain order from the results. Recorded in ADR-0001.
- `evals/blind-review.md`: 20 random answers for H-4.

**P-06. Sessions** — R-01…R-05, S-01, S-16, AC-01, AC-07
- The setup screen (S-01, A-3), the list and the English/Deutsch filter, the "…" menu, continuation with `ContextPolicy`, the summary and the recap as events.
- Tests: creation, renaming, delete-tombstone, continuation, app restart.

**P-07. Voice loop** — R-06, R-07, R-10…R-13, R-42, R-43, S-02…S-05, AC-02, AC-03
- `TurnController`: holding the space bar, continuous mode, merging, barge-in, request cancellation, the "interrupted" mark.
- The voice panel (states and wave), text input.
- `MetricsRecorder` (turn marks R-47; on the Mac without MetricKit) and `scripts/metrics.py`.
- `TurnController` tests on fake audio: merging, barge-in, Esc.

**P-08. Assistant behaviour** — R-14…R-26, S-06…S-15, AC-04…AC-06
- Commands locally and through the model, Russian on an explicit request, R-18, the correction modes and their combinations, the `@fix` aggregator, the recap R-23, ending by voice R-22.
- `scripts/run-evals.sh dialog` and `commands` against the AC-04 and AC-05 thresholds.

**P-09. Hints and vocabulary** — R-27, R-28, AC-10
- Background generation of "Topic phrases", the sections, listening with a queue and a microphone pause, ★ and the vocabulary.

**P-10. Sync in the app, settings, first launch** — R-32, R-33, R-36…R-38, R-44, R-45, S-17, S-20, AC-08, AC-12
- Integration of `SyncScheduler`, statuses, ✓/✓✓, the remaining settings tabs, the first-launch wizard, the source badge, the offline state.
- The executor creates the folder `~/Library/Mobile Documents/com~apple~CloudDocs/Lingo`. **H-3**.
- S-19 per AC-08: Lingo without a network writes 25 messages, `lingo-eval sync-write` writes 25 from the second device, the network is switched on, `scripts/sync-check.py`.

**P-11. Live check** — AC-02, AC-03, AC-10, AC-11, AC-15, AC-16
- `evals/live-script-mac.md`, metrics, `footprint -p $(pgrep Lingo)` once a minute. **H-4.**

**P-12. Review and report** — all AC
- `/code-review` at level high on the branch, fixing P0 and P1.
- `report.md`: a table AC → command → result → evidence; what was not verified; risks; what is ready for LINGO-02 (iPhone).
- Update the README, the ADR, the handoff. **H-5.**

## Dependencies
Only from ADR-0001 item 11. Any other one is an ADR entry and a "needs owner confirmation" note in the handoff.

## Checks
| Command (new) | Steps | Expected evidence |
|---|---|---|
| `swift build` | all | Build without errors |
| `swift test` | P-02+ | All tests green, the number of tests in the handoff |
| `scripts/check-core-ios.sh` | P-01+ | `LingoCore` builds for iOS (readiness for LINGO-02) |
| `scripts/build-app.sh` | P-01+ | `dist/Lingo.app`, `codesign -dv` shows the certificate per A-5 |
| `scripts/secret-scan.sh` | P-01+, before each push | "0 findings" (AC-13) |
| `scripts/run-evals.sh commands` | P-04+ | ≥ 95% (AC-04) |
| `scripts/run-evals.sh turn` | P-04+ | Metrics from evals/README |
| `scripts/run-evals.sh dialog` | P-05+ | The AC-05, AC-06 thresholds |
| `lingo-eval stt …` | P-04 | WER and language detection |
| `scripts/metrics.py <jsonl>` | P-07+ | Medians and p90 (AC-02) |
| `scripts/sync-check.py <folder>` | P-02, P-10 | 0 losses, 0 duplicates (AC-08) |
| `footprint -p $(pgrep Lingo)` | P-11 | Peak ≤ 1.2 GB (AC-15) |

Tests and thresholds must not be weakened to get a green result. If a test needs a key that is missing, it is NOT RUN, not a deleted test.

## Risks and rollback
| Risk | Sign | Action |
|---|---|---|
| The echo of the MacBook speakers breaks barge-in | AC-03 below the threshold | A VAD threshold during playback; a headphone recommendation in the report |
| Mixed speech is recognised poorly | AC-16 below the threshold | R-09; compare engines; spec, section 6 |
| whisper large-v3-turbo and the app do not fit in 1.2 GB or are slow | AC-15, `stt_final` latency | The small model or `SFSpeechRecognizer` |
| macOS does not give access to iCloud Drive without a sandbox | An access error in H-3 | The "Files and Folders" permission through TCC (done by the owner), a bookmark; spec, section 6 (F-08) |
| Groq limits during the evals | 429 | A pause, rotation of keys and models, stretch the run; do not ask for keys |
| The core uses a macOS-only API | `scripts/check-core-ios.sh` fails | Move the platform code from `LingoCore` to `LingoMac` |
| Not enough disk | < 3 GB free | Delete unused models and the project's DerivedData; do not touch other people's files |

Rollback: each step is a separate commit in `feat/lingo-01`. A failed step is rolled back with `git revert` of its commit. `main` does not change.

## Stop conditions (escalation to the owner)
- A dependency, service or key outside ADR-0001 and the intent is needed, or something paid.
- A spec requirement cannot be met without changing the boundaries.
- A secret or personal data is found in the Git history.
- Three attempts in a row on one problem without progress: save the state in the handoff, describe the hypotheses.
- Any action from the "Forbidden" list in CLAUDE.md.

## Done when
AC-01…AC-16 have evidence in report.md — PASS, or NOT RUN with a reason the owner accepted.
The review has no open P0 and P1, `LingoCore` builds for iOS, the branch is pushed, the handoff is current, the owner confirmed H-5.
