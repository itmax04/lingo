# AGENTS.md — guide for AI agents (and humans) working on Lingo

Read this file first. It is the single entry point for anyone who continues, improves or reviews Lingo.
`CLAUDE.md` only imports this file and `DESIGN.md`.

## 1. What Lingo is

Lingo is a personal macOS app (an iOS app follows in LINGO-02) for **voice conversation practice in English and German**.
The learner is a native Russian speaker; explanations in Russian are given **only on an explicit request**.

The voice loop is a pipeline, all free of charge:

```
microphone ─► VAD + utterance segmentation ─► whisper.cpp (on device) ─► LLM chain (free cloud APIs) ─► reply protocol ─► AVSpeechSynthesizer (on device)
```

- Audio never leaves the Mac and is never written to disk.
- Only text goes to the model provider.
- History is an append-only event journal per device, synced through a user-chosen iCloud Drive folder.

Owner: GitHub `itmax04`. The repository is private.

## 2. Status (2026-10-26)

| Item | State |
|---|---|
| Current change | **LINGO-01 — Mac MVP**, steps P-00…P-10 implemented, owner checkpoints H-0, H-1, H-2 passed |
| Working branch | **`main-en`** (English repository). `feat/lingo-01` is the older Russian branch, kept as history. `main` holds only the first commit. Never merge into `main` without the owner. |
| Open in LINGO-01 | AC-17 control 30-minute session · H-3 iCloud sync folder (S-19 on a real folder) · H-4 live scenario part 2 · nightly evals in small batches · blind review · P-11 · P-12 (report.md, code review, README/ADR, H-5 acceptance) |
| Latest fix | microphone capture recovery (`VoiceIO` restart limiter, capture watchdog, `--audio-stability`) — see the last sections of `handoff.md` |
| Providers | Groq (main, free tier) → Cloudflare Workers AI as a "Custom endpoint" chain step (`@cf/openai/gpt-oss-120b`), configured in the owner's settings, not in the repo |
| English migration | **in progress** — see §8 |

The detailed log of what was done, with commit references and check results, is `docs/changes/LINGO-01/handoff.md`.

## 3. Documents — where the truth lives

| What | Where |
|---|---|
| Goal, scope, owner decisions Q1–Q30, assumptions A-1…A-9 | `docs/changes/LINGO-01/intent.md` |
| Requirements R-01…R-52, scenarios S-01…S-20, acceptance criteria AC-01…AC-17 | `docs/changes/LINGO-01/spec.md` (the **only** place requirements are defined) |
| Steps P-00…P-12, owner checkpoints H-0…H-5 | `docs/changes/LINGO-01/plan.md` |
| Progress log, executor decisions D-01…D-21, next step | `docs/changes/LINGO-01/handoff.md` |
| Stack and allowed dependencies | `docs/decisions/ADR-0001-stack.md` |
| Design tokens (colors, type, spacing, radii) | `DESIGN.md`, mockup `docs/design/lingo-mac.webp` |
| Eval sets, rules, thresholds | `evals/README.md` |
| The owner's original brief and PDF patterns | `docs/reference/` |

Process: SDLC documents (intent → spec → plan → handoff). A new piece of work gets its own folder `docs/changes/LINGO-NN/`.
Code and docs refer to requirement IDs (`R-29`, `AC-15`, …); keep doing that.

## 4. Repository layout

```
Package.swift                 SwiftPM: LingoCore, LingoEvalKit, LingoMac (product "Lingo"), lingo-eval, LingoCoreTests
Sources/LingoCore/            platform-neutral core, must also build for iOS (scripts/check-core-ios.sh)
  Audio/                      VoiceIO (one AVAudioEngine: voice-processing input + speech output), EnergyVAD, PCMConverter, AudioRestartLimiter
  Speech/                     WhisperEngine (whisper.cpp), AppleSpeechEngine, TurnSegmenter (pause T / merge G), Voices, ModelStore (SHA256), WER
  Dialogue/                   DialogEngine (actor: turns, recap, summary, topic phrases), TurnController (@MainActor voice loop),
                              PromptBuilder (system wrapper, R-25), ReplyProtocol (@say/@fix/@hint/@heard parser, R-24), ContextPolicy (R-04)
  LLM/                        ProviderChain (fallback chain, R-29), OpenAICompatibleProvider, SSEClient, KeyVerifier, RateLimits (usage log, R-52), LLMSettings
  Journal/                    Event, JournalIO, JournalStore (actor), Merger (LWW, R-37), SyncFolder (NSFileCoordinator), SyncScheduler, ULID
  Commands/                   CommandDetector (local "repeat"/"slower"/… detector, ru/de/en)
  Model/ Settings/ Secrets/ Metrics/ Logging/
Sources/LingoEvalKit/         dialog eval cases, rules, runner (shared by lingo-eval and Lingo.app --eval-dialog)
Sources/LingoMac/             the macOS app (SwiftUI + AppKit): AppModel, AppServices, VoiceServices, SyncServices, Views/, Settings/, STTCheck/,
                              service modes (Headless, SelfTest, AudioDiag, UIClickTest)
Sources/lingo-eval/           CLI for evals and sync experiments
Tests/LingoCoreTests/         swift-testing; Snapshots/ = system-prompt snapshots
scripts/                      build-app.sh, check-core-ios.sh, secret-scan.sh, run-evals.sh, metrics.py, sync-check.py, make-audio-fixtures.sh, ensure-build-dir.sh
evals/                        commands, turn, audio, dialog sets; live-script-mac.md; out/ (git-ignored)
Resources/                    Info.plist, live-phrases.json (phrases for the live recognition check)
docs/                         SDLC documents, ADRs, design mockup, references
private/                      the owner's original PDF — git-ignored, never commit
```

Key design facts:
- **Event sourcing.** Every change is a journal event (JSON Lines, append-only, fsync). State (`HistoryState`) is a pure function of the event set; merging is commutative and idempotent (`Merger`, property-tested). Each device writes only its own journal file; unknown event types and fields are preserved.
- **LLM chain.** A step is "provider + model + key"; any number of keys per provider. Fallback on 429/5xx/network/refusal/first-token timeout; invalid keys are disabled per key. Remaining quota from response headers is tracked, and a usage record is written per attempt (`~/Library/Application Support/Lingo/usage/`). A dispatcher runs background requests (topic phrases, summary) only after the user's turn and only with spare quota.
- **Reply protocol.** The model answers line by line with tags (`@say <lang>:`, `@fix:`, `@hint <lang>:`, `@heard:`). It is parsed while streaming so speech starts with the first finished sentence.
- **Keys** live only in the Keychain (`com.itmax04.lingo`). Only the signed `.app` reads them without a prompt, so key-dependent checks run through `dist/Lingo.app/Contents/MacOS/Lingo --…`.

## 5. Commands

| Command | What it does |
|---|---|
| `swift build && swift test` | Quick check (96 tests at the time of writing) |
| `scripts/build-app.sh` | Builds and signs `dist/Lingo.app` (self-signed cert "Lingo Dev" or "InterviewCopilot"; build number = commit count) |
| `open dist/Lingo.app` | Run the app |
| `scripts/check-core-ios.sh` | `LingoCore` builds for iOS (arm64-apple-ios17.0) |
| `scripts/secret-scan.sh` | Keys and personal data in tree, index and the whole history — **run before every push**, must report 0 findings |
| `scripts/run-evals.sh commands\|turn\|audio` | Offline evals (no API quota) |
| `dist/Lingo.app/Contents/MacOS/Lingo --check-keys` | Checks every stored key and prints the chain (key values are never printed) |
| `dist/Lingo.app/Contents/MacOS/Lingo --eval-dialog <cases> <out> [--provider groq\|custom] [--models m] [--only ids] [--max-cases 10] [--budget 15] [--allow-daytime]` | Dialogue eval against a real provider — see the quota rule in §6 |
| `… --audio-diag <file>` / `… --audio-stability <file>` | Audio configuration diagnostics / 20 s capture stability with a forced restart (counters only, no audio saved) |
| `… --selftest <wav>` | End-to-end voice turn on real components without the microphone |
| `… --ui-snapshot <png>` / `… --ui-click-test` | Window snapshot on fixtures / synthetic clicks on the voice panel |
| `open dist/Lingo.app --args --stt-check part1` | Live speech-recognition check window (owner checkpoints H-2/H-4) |
| `python3 scripts/metrics.py` | Turn latency (median/p90) and memory from the metrics log |
| `/usr/bin/log show --last 10m --predicate 'subsystem == "com.itmax04.lingo"'` | App logs (utterance text is never logged) |

`.build` is a symlink into `~/Library/Caches` (`scripts/ensure-build-dir.sh`) because the repository lives on the iCloud-synced Desktop.

## 6. Rules (non-negotiable)

1. **Free only.** No paid APIs, subscriptions, providers that require a card, or a paid Apple developer account.
2. **No secrets anywhere.** API keys, Apple ID, passwords and personal data never go into code, logs, tests, commits, journals or chat. Test data is synthetic. Never ask the owner to paste a key into chat; keys are entered only in the app's settings.
3. **Git safety.** Work on `main-en`. Commit after each step and push. Forbidden: force-push, `reset --hard`, deleting branches, rewriting history, merging into `main` without the owner. Never commit `private/`, models, logs or `evals/out/`.
4. **System settings are the owner's.** Do not change TCC permissions, Keychain trust or macOS settings; give the owner step-by-step instructions instead (voices, microphone access, iCloud).
5. **Models** are downloaded only from official repositories over HTTPS with a SHA256 check (`ModelStore`). Disk is tight (≈14 GB free): delete models that are not used.
6. **Dependencies** only from ADR-0001 §11. Anything else needs an ADR entry and the owner's decision.
7. **API quota is shared with the owner's practice.** The free Groq limits are per organization and per model (≈30 RPM, 1K RPD, 8K TPM, 200K TPD). Dialogue evals run **only at night (23:00–08:00) in small batches** with a budget; in the daytime only single requests. Never burn the quota with test runs.
8. **Never claim a result you did not get.** Checks are PASS / FAIL / NOT RUN with the real output. A simulator or a single UI launch is not evidence for device requirements.
9. **Owner checkpoints.** Ask the owner only at H-0…H-5 (plan.md) or when blocked on something only they can decide; record other decisions in `handoff.md` ("Executor decisions", D-nn).
10. **Update `handoff.md`** after each step: what was done, commit, checks, next step.
11. **The owner communicates in Russian.** Answer the owner in Russian; everything in the repository is in English (§7).
12. **Do not comment on pronunciation** — a product rule (R-21) enforced by the prompt and by the `no_pronunciation` eval rule (100%).

## 7. Language policy for the repository

Everything in the repository is **English**: code, identifiers, comments, docs, scripts, test names, commit messages.
Russian (and German) text is allowed only where it is **language data**:
- the Russian translation of the UI in the String Catalog (`ru` values);
- utterances the app must understand or produce: command vocabularies (`CommandDetector`), the whisper bilingual prompt, example phrases and Russian output headings in `PromptBuilder`, voice warm-up phrases, conjunction lists in `Voices`;
- eval cases and fixtures (`evals/**`, test inputs, `Fixtures.swift` utterances and translations, `Tests/LingoCoreTests/Snapshots/`);
- recorded evidence (`docs/changes/*/evidence/`), which must not be altered.

UI strings: write English literals; SwiftUI `Text("…")`, `Button("…")`, `.help("…")` etc. localize automatically; anything typed as `String` must use `String(localized: "…")`. Custom components take `LocalizedStringKey` (e.g. `SettingsCard(title:)`). The app's default interface language is Russian for the owner (see §8).

## 8. English migration — what is done and what is left

Done on `main-en` (2026-10-26):
- all Swift sources, tests, scripts and `.gitignore`: comments, logs, CLI output and UI strings are in English; user-visible strings go through `String(localized:)` / `LocalizedStringKey`;
- `Language.russianPrepositional` → `inLanguagePhrase`; `SettingsTab` raw values are no longer display strings; `VoiceIO.onRestart` reports `(reason, ok)`; session dates use the UI locale (`SessionDateFormat.locale`);
- the LLM prompts were already English and are unchanged (prompt snapshots are byte-identical), so model behaviour did not change;
- `intent.md` (also adds Q30 — this migration), `AGENTS.md`, `README.md`, `CLAUDE.md`.

**Left to do** (in this order):
1. **String Catalog** — create `Resources/Localizable.xcstrings` (source language `en`, `ru` translations). Extract the exact keys with
   `swift build -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc <dir>` and
   `xcrun xcstringstool sync Resources/Localizable.xcstrings --stringsdata <dir>/*.stringsdata`; the Russian texts are the previous literals in `git show feat/lingo-01:<file>`.
   Compile it in `scripts/build-app.sh` (`xcrun xcstringstool compile … --output-directory "$APP/Contents/Resources"`), set `CFBundleDevelopmentRegion=en` and `CFBundleLocalizations=[en, ru]`, and localize the two usage descriptions in `Info.plist` (`InfoPlist.xcstrings`).
   **Until this is done the app UI shows English** although the owner expects Russian.
2. **Interface language** — the owner's macOS prefers `en-US`, so set the app's own `AppleLanguages` from an in-app setting (default Russian; options Russian / English / System) before the UI starts.
3. A `scripts/check-english.sh` that fails on Cyrillic outside the allowed places of §7, and a check that every `ru` catalog entry exists.
4. Translate the remaining documents: `spec.md`, `plan.md`, `handoff.md`, `executor-prompt.md`, `ADR-0001-stack.md`, `DESIGN.md`, `evals/README.md`, `evals/live-script-mac.md`, `docs/reference/*`, descriptions in `evals/**/*.yaml` (keep the utterances).
5. `KeyVerifier`: treat HTTP 404/405 on `GET /models` of a custom endpoint (Cloudflare has no model list there) as "key works, no model list" instead of an error.

## 9. Known pitfalls

- **iCloud Desktop.** The repo is on the iCloud-synced Desktop. File Provider has twice left `.git/index` missing with a stale `.git/index.lock`. If `git status` fails that way and **no other git process is running**, restore with `mv .git/index.lock .git/index` (keep a copy first). Moving `.git` out of iCloud is an open owner decision.
- **Shared working tree.** Several agents (Claude Code sessions, other tools) have worked in the same folder. Check `git status` before starting; never overwrite or revert changes you did not make — ask the owner.
- **codesign** fails on files with iCloud extended attributes ("detritus not allowed"); `build-app.sh` builds in a temp folder outside iCloud — keep it that way.
- **Voice processing on macOS** delivers 48 kHz with 5 channels; take channel 0. With voice processing on, connect mixer → output in the output node's format (otherwise CoreAudio −10875). macOS stops the engine on configuration changes — `VoiceIO` restarts it (limited, only accepted attempts count).
- **whisper.cpp** (`large-v3-turbo` q5_0, ≈760 MB RAM): do not reduce `audio_ctx` below 512 frames (garbage and loops, D-13); language label comes from the script of the final text (Cyrillic → ru).
- **Memory budget** AC-15: the whole app ≤ 1.2 GB during a 20-minute session. Premium TTS voices add 140–180 MB each.
- **Groq quota**: see §6 rule 7. The usage log and the "Quota" settings tab show what was spent.

## 10. Definition of done for LINGO-01

AC-01…AC-17 confirmed with evidence in `docs/changes/LINGO-01/report.md`, everything unverified listed explicitly, and the owner accepted the result at H-5.
