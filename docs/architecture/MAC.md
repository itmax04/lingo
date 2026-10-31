# Lingo for Mac — architecture and code guide

Status: current · Version 1 · Date: 2026-10-28
Part of the documentation set: [ARCHITECTURE.md](ARCHITECTURE.md) (whole system, shared rules) · **MAC.md** (this file) ·
[WEB.md](WEB.md) (Lingo Web + Engine, all other devices) · [CODEBASE.md](CODEBASE.md) (repository map) ·
[EVOLVING.md](../process/EVOLVING.md) (how to change things).

Read this file before touching anything under `Package.swift`, `Sources/`, `Tests/`, `Resources/` (after LINGO-03 P-01: `apps/mac/`).
When you add, move or delete a Mac module, update this file in the same PR.

---

## 1. What the Mac app is

A **standalone** native app (Swift 6.2, SwiftUI + AppKit, macOS 15+) for voice practice of English and German.
It recognises speech **on the device** (whisper.cpp), speaks with the system voices, calls free chat models through its own
provider chain with keys in the Keychain, and stores its own history journal. It works without the engine and without the web.

| Fact | Value |
|---|---|
| Status | LINGO-01 MVP working; LINGO-07 redesign in PR #33; Stage 0 stabilisation in LINGO-03 P-01…P-06 |
| Hardware target | MacBook Air M1, 8 GB; memory budget 1.2 GB (Premium voices +140–180 MB) |
| Recognition | whisper.cpp `large-v3-turbo` q5_0 (≈ 760 MB RAM); Apple `SFSpeechRecognizer` as an alternative engine |
| Models | Groq chain (`gpt-oss-120b` → `gpt-oss-20b` → …) + Cloudflare Workers AI as a custom endpoint |
| Joins the account | LINGO-04 (sync adapter, optional engine turns) — until then the history is local + sync folder |
| Later | `LingoCore` is reused by the native iPhone app (LINGO-06) |

## 2. Swift package

### 2.1 Targets and dependency rule

```mermaid
flowchart LR
  whisper[[whisper.xcframework<br/>binary, SHA256-pinned]]
  core[LingoCore]
  kit[LingoEvalKit]
  mac[LingoMac → app "Lingo"]
  cli[lingo-eval]
  tests[LingoCoreTests]
  yams[[Yams]]
  whisper --> core
  core --> kit
  yams --> kit
  core --> mac
  kit --> mac
  core --> cli
  kit --> cli
  core --> tests
  kit --> tests
```

| Rule | Why | Enforced by |
|---|---|---|
| `LingoCore` imports only Foundation, Speech, Security, CryptoKit, Network, os, Darwin and `whisper` — **no AppKit, SwiftUI, LingoEvalKit** | it must build for iOS (LINGO-06) | `apps/mac/scripts/check-core-ios.sh` |
| UI and AppKit live only in `LingoMac` | keeps the core portable and testable | review |
| `Yams` only in `LingoEvalKit` / `lingo-eval` | the app core never parses YAML | `Package.swift` |
| New dependencies only from the ADR-0001 allow-list | supply chain, size, $0 | ADR first |
| Behaviour shared with TypeScript follows `packages/contracts` | one source of truth (ADR-0004) | parity fixtures |

### 2.2 `LingoCore` — by folder

| Folder | Files → main types | Responsibility |
|---|---|---|
| `Audio/` | `VoiceIO` · `EnergyVAD` · `PCMConverter`, `AudioFileReader` · `VoiceDefaults` · `Permissions` · `AudioRestartLimiter` | One `AVAudioEngine` for mic + speech output (voice processing, channel 0 of 5), adaptive energy VAD, conversion to 16 kHz mono Float32, TCC permission checks, bounded engine restarts |
| `Speech/` | `WhisperEngine` · `SpeechRecognizer`, `UtteranceBuffer`, `RecognitionContext` · `TurnSegmenter`, `TurnConfig` · `AppleSpeechEngine` · `ModelStore` · `Voices`, `SlowChunks`, `SpeechPace` · `WER` | Recognition, end of utterance and merging (pause T, merge G), model download with SHA256, voice choice (Premium → Enhanced → Default), slower speech, WER for evals |
| `Commands/` | `CommandDetector`, `CommandMatch` · `CommandKind` | "repeat", "slower", "how do I say …", "explain", "continue", "any mistakes", "finish" in ru/de/en, incl. misrecognised variants |
| `Dialogue/` | `TurnController`, `SpeechSink` · `DialogEngine`, `TurnEvent` · `PromptBuilder` · `ContextPolicy` · `ReplyProtocol`, `ReplyStreamParser` | Voice-turn state machine (listening → thinking → speaking, barge-in), one dialogue turn end to end, system wrapper (English instructions), context window + summary, streaming parser of `@say / @fix / @hint / @heard` lines |
| `Journal/` | `Event`, `EventType` · `Payloads` · `JSONValue` · `JournalIO` · `JournalStore` · `Merger` (`HistoryState`, `LWW`) · `SyncFolder`, `SyncScheduler` · `ULID` | Append-only event journal per device, merge of all devices (union, LWW, tombstones), folder sync, ULIDs — mirrors `packages/contracts/events` |
| `LLM/` | `ProviderChain` · `OpenAICompatibleProvider` · `SSEClient` · `LLMTypes` (`LLMRequest`, `LLMPurpose`) · `LLMSettings` (`KeyRecord`, `ChainEntry`) · `ProviderID` · `RateLimits` (`UsageRecorder`) · `KeyVerifier` | Provider + model + key chain with fallback on 429/5xx/network/timeout and cooldowns, streaming chat completions, rate-limit parsing, usage log, key checks |
| `Model/` | `Session` · `SessionSettings` (`SessionMode`, `CorrectionMode`, `Levels`) · `Message` (`Role`, `Fix`, `Phrase`) · `Language` (`Lang`) · `VoiceState` | Domain types built from the journal |
| `Settings/` | `AppSettings`, `SettingsStore` · `VoiceSettings` · `Reachability` | Non-secret settings, voice-loop settings, network state |
| `Secrets/` | `KeychainStore`, `SecretStore`, `InMemorySecretStore` | API keys — Keychain only (service `com.itmax04.lingo`, account = key id); never logged or returned to the UI |
| `Metrics/` | `MetricsRecorder` · `Memory` | Turn marks (`speech_end`, `stt_final`, `llm_first_token`, `first_audio`, `reply_end`), `phys_footprint` |
| `Logging/` | `Log` | `os_log`, subsystem `com.itmax04.lingo`; never utterance text or keys |

### 2.3 `LingoMac` — the app

| File | Responsibility |
|---|---|
| `App.swift` | `@main`, `AppDelegate`, main window and menu, keyboard (space, Esc, ⌥R), command-line modes (§5) |
| `AppModel.swift` | Observable window state (sessions, messages, phrases, voice state, levels, sync status, banners) |
| `AppServices.swift` | Owns journal, dialogue, sync and settings; updates `AppModel` on the main thread |
| `VoiceServices.swift` | Voice mode: `VoiceIO` + recognition + `TurnController` + metrics |
| `SyncServices.swift` | Folder sync, network watching, daily metrics |
| `Settings/` | Settings window: keys and chain (`KeysController`, `KeysSettingsView`), quota, voice, sync, data |
| `Views/` | `MainView` (three columns), `SidebarView`, `ChatViews` (header, bubbles, segments), `VoicePanel` (+ `Waveform`, input bar), `HintsPanel`, `NewSessionView`, `EditMessageView`, `OnboardingView`, `Components` |
| `Design/` | `Theme` (DESIGN.md tokens one to one), `AppIcon` |
| `STTCheck/` | "Speech recognition check" window for live recognition tests |
| `Headless.swift`, `SelfTest.swift`, `AudioDiag.swift`, `UIClickTest.swift` | Windowless diagnostic modes |
| `Fixtures.swift` | Synthetic data for UI snapshots only |

PR #33 (LINGO-07) adds `Design/InterfacePreferences.swift` (interface language and theme), `Design/LingoMark.swift` (vector mark),
`Views/PlannedViews.swift` (Today / Vocabulary / Progress / Teacher "Coming soon" sections), `Resources/*.xcstrings` (String Catalogs)
and `Tests/LingoMacTests/`. Update this table when it is merged.

### 2.4 Evals

| Path | Responsibility |
|---|---|
| `Sources/LingoEvalKit/DialogCase.swift`, `DialogRules.swift`, `DialogRunner.swift` | YAML case format, automatic rules (protocol, language discipline, no pronunciation, one question, corrections, length), runner with 429 waits and budgets |
| `Sources/lingo-eval/` | `main` (arguments) · `CommandsEval` · `TurnEval` · `STTEval` · `STTBench` · `TTSBench` · `BlindReview` · `EvalSupport` |
| `evals/` | Data sets and the live script; thresholds in `evals/README.md`. Moves to `packages/contracts/evals/` in P-01 |

## 3. One voice turn through the files

```mermaid
sequenceDiagram
  participant V as VoiceIO (Audio)
  participant S as EnergyVAD + TurnSegmenter (Speech)
  participant R as WhisperEngine (Speech)
  participant T as TurnController (Dialogue)
  participant D as DialogEngine + PromptBuilder
  participant C as ProviderChain (LLM)
  participant P as ReplyStreamParser
  participant J as JournalStore (Journal)
  V->>S: 16 kHz frames + levels
  S->>R: closed utterance
  R->>T: Transcription (text, language)
  T->>D: user turn (or a CommandDetector command)
  D->>J: message.created (user)
  D->>C: LLMRequest (purpose dialog)
  C-->>P: streamed tokens
  P-->>T: @say sentences → speech; @fix / @hint
  T->>V: speak sentences (barge-in stops them)
  D->>J: message.created (assistant), fix.recorded, hint.added
```

Local commands ("repeat", "slower") never call a model (target ≤ 0.3 s until audio). Latency today: 3.5 s median `speech_end → first audio`.

## 4. Data on disk

| Location | Content |
|---|---|
| `~/Library/Application Support/Lingo/devices/<device-id>/journal-YYYY-MM.jsonl` | this device's events (source of truth on the device) |
| `~/Library/Application Support/Lingo/cache/` | copies of other devices' journals |
| `~/Library/Application Support/Lingo/metrics/*.jsonl` | turn metrics (read by `scripts/metrics.py`) |
| `~/Library/Application Support/Lingo/` (other files) | settings, usage log |
| Keychain, service `com.itmax04.lingo` | API keys only |
| Sync folder chosen by the user: `Lingo/v1/devices/<device-id>/journal-*.jsonl` | one folder per device; each device writes only its own (checked by `scripts/sync-check.py`) |
| Model directory of `ModelStore` | whisper models, downloaded from the official source with a SHA256 check |
| Never | audio (except synthetic eval fixtures), keys outside the Keychain |

## 5. Build, run, test

| Command | What |
|---|---|
| `swift build && swift test` | build and run the Swift tests (after P-01: `--package-path apps/mac`) |
| `apps/mac/scripts/build-app.sh` | build and sign `dist/Lingo.app` with the local self-signed certificate |
| `open dist/Lingo.app` | run |
| `apps/mac/scripts/check-core-ios.sh` | `LingoCore` compiles for iOS |
| `apps/mac/scripts/run-evals.sh commands\|turn\|audio\|dialog\|all` | evals; `dialog` only at night (23:00–08:00 Berlin), budgeted |
| `python3 scripts/metrics.py` | latency and memory of recent turns |

Command-line modes of `dist/Lingo.app/Contents/MacOS/Lingo`: `--check-keys` ·
`--eval-dialog <cases> <out> [--provider] [--models] [--only] [--max-cases] [--budget] [--offset] [--allow-daytime]` · `--help-eval` ·
`--selftest <wav>` · `--audio-diag <file>` · `--audio-stability <file>` · `--stt-check` · `--ui-snapshot <png>` · `--ui-click-test` ·
`--export-iconset` · `--settings`. Key-dependent modes must run through the signed app (Keychain access without prompts).

| Test suite | Covers |
|---|---|
| `JournalTests`, `SyncTests` | ULID, event codec, merge rules, two writers, folder sync |
| `ChainTests`, `QuotaTests` | chain steps and fallback, rate-limit parsing, usage |
| `DialogEngineTests`, `TurnControllerTests` | one turn writes user/assistant/fix/hint; push-to-talk, barge-in, states |
| `PromptBuilderTests` (+ `Snapshots/`) | system wrapper rules; byte-exact prompt snapshots |
| `ReplyProtocolTests` | all reply tags, streaming parse |
| `SessionSettingsTests`, `SpeechTests`, `DialogRulesTests`, `AudioRecoveryTests` | start conditions, segmenter, eval rules, restart limiter |

CI: `.github/workflows/ci-mac.yml` (macOS runner, path-filtered — minutes count ×10, do not re-run without a reason).

## 6. Known pitfalls

- Voice processing delivers 48 kHz × 5 channels — take channel 0; connect mixer → output in the output node's format.
- macOS stops the audio engine on configuration changes; `VoiceIO` restarts it, limited by `AudioRestartLimiter`.
- Do not reduce whisper `audio_ctx` below 512 frames; the language label comes from the script of the result.
- Keys are readable without prompts only by the signed app — run key checks through `dist/Lingo.app`.
- Never build inside an iCloud-synced folder (`scripts/ensure-build-dir.sh`); work in `~/Developer/lingo`.

## 7. Where to change what (Mac)

| I want to … | Change | Also update |
|---|---|---|
| fix a bug in the voice loop | `LingoCore/Audio`, `Speech`, `Dialogue/TurnController` | a regression test in `TurnControllerTests` / `SpeechTests` |
| add or change a voice command | `Commands/CommandKind`, `CommandDetector` | `evals/commands`, contracts fixtures, the TS port (WEB.md), spec requirement |
| change model instructions | `Dialogue/PromptBuilder`, `ContextPolicy` | re-record `packages/contracts/prompts`, night `dialog` eval, the engine prompt builder (byte-identical) |
| change the reply protocol | `Dialogue/ReplyProtocol` | contracts first, both parsers, `ReplyProtocolTests` |
| add an event type or field | `packages/contracts/events/event.schema.json` → `Journal/Event`, `Payloads`, `Merger` | fixtures, `JournalTests`, ARCHITECTURE §6.1, the TS reducer |
| add a provider or model | `LLM/ProviderID`, `ProviderEndpoints`, chain defaults | ADR-0005 if routing policy changes, `ChainTests` |
| change quota handling | `LLM/ProviderChain`, `RateLimits` | ADR-0005, capacity table in the change's handoff |
| add a setting | `Settings/AppSettings` or `VoiceSettings` + `LingoMac/Settings/*View` | String Catalog entry, defaults in the spec |
| add a UI string | `String(localized:)` / `LocalizedStringKey` in code | the Russian text in the String Catalog |
| change a colour, size or font | `DESIGN.md` first → `Design/Theme.swift` | design check script (PR #33), snapshots |
| add or change a screen | `LingoMac/Views/*` using `Theme` only | `Fixtures`, `--ui-snapshot`, the reference in `design/redesign-2026/04-mac` |
| add a dependency | ADR-0001 allow-list first | `Package.swift` |
| share code with the iPhone app | put it in `LingoCore` (no AppKit/SwiftUI) | `apps/mac/scripts/check-core-ios.sh` |
