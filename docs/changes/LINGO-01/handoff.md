# LINGO-01 handoff

Status: **Q29 stage 1 done (build 19, `8470d07`); next — Cloudflare (owner), H-3 (the iCloud folder), the control 30-minute session tomorrow (AC-17)** · Updated: 2026-10-25 · Branch: `feat/lingo-01` · Commit: see `git log -1`
Goal and boundaries: [intent.md](intent.md), requirements: [spec.md](spec.md), steps: [plan.md](plan.md).
Translated to English in LINGO-03 P-06 (MR-08); the Russian original is in the Git history of this file. Quoted owner statements were originally in Russian. Quoted UI strings and tool output were Russian too and are translated; they may differ from the wording of the current catalog.

## Done
- 2026-10-25: a brainstorm with the owner (Q1–Q26), the SDLC documents were created:
  - intent, spec, plan;
  - ADR-0001;
  - evals/README;
  - DESIGN.md (tokens from the mockup);
  - CLAUDE.md, README;
  - executor-prompt;
  - owner-brief, pdf-patterns.

  No code was written.
- 2026-10-25: the owner moved stage A to the iPhone Air: "I want the Air, and then we adapt for the iPhone 11 if needed" (Q25).
  There is no Lightning cable (Q26). Updated intent (devices, constraints, Q25–Q26, A-9), spec (section 4), plan (H-0, P-00, P-05, risks), ADR-0001 (candidates for 12 GB, Apple's built-in model as an additional candidate), CLAUDE.md, README, executor-prompt.
- 2026-10-25: the owner changed the order: "let's still start with the Mac, and then adapt for the right iPhone" (Q27).
  LINGO-01 is only the MVP for the Mac (plan v2: P-00…P-12, H-0…H-5). The iPhone, SideStore, the F checks, the local model are LINGO-02.
  Updated intent v2, spec v2 (section 4 is a draft for LINGO-02, AC-08/AC-14/AC-16), plan v2, ADR, CLAUDE.md, README, evals, executor-prompt v2.
- 2026-10-25: the owner accepted the v2 set ("let's start"), the statuses → accepted.
- The original PDF was copied to `private/pdf-example.pdf`. It is in .gitignore: it holds a personal conversation with names and a list of chats.

## Environment on 2026-10-25 (before P-00)
- macOS 15.7.2 (24G325), Apple M1, 8 GB.
- Xcode 26.3 (17C529), `xcode-select` → `/Applications/Xcode.app/Contents/Developer`.
- About 14 GB free.
- ffmpeg and Homebrew are installed. `gh` is authorised as itmax04.
- For LINGO-02: the iPhone Air (iPhone18,4), iOS 27.0, paired with the Mac over USB-C, "Developer Mode" is off, SideStore is not installed (`devicectl`, 2026-10-25).
- The system has no poppler, so the PDF was rendered through PDFKit (a Swift script in the scratchpad). The work does not need it.

## P-00. Survey and baseline (2026-10-25)
**Git:** branch `feat/lingo-01`, `fade7c6`, the tree is clean, matches the handoff (no discrepancies).

**Environment (commands run on 2026-10-25):**
- `xcodebuild -version` → Xcode 26.3, Build 17C529; iOS SDK 26.2 (`xcrun --sdk iphoneos --show-sdk-version`).
- `swift --version` → Apple Swift 6.2.4 (swiftlang-6.2.4.1.4), target arm64-apple-macosx15.0.
- macOS 15.7.2 (24G325), Apple M1, 8 GB. `df -h /` → **12 GiB** free (less than the ≈14 GB in the intent).
- ffmpeg, gh, brew are present; XcodeGen is not installed (needed only in LINGO-02); Python 3.12.3.
- Signing: the keychain has a self-signed identity "InterviewCopilot" (`security find-identity -p codesigning`:
  `CSSMERR_TP_NOT_TRUSTED` — normal for local signing, IC is signed with the same one). The decision on the certificate is H-0.
- The whisper models are already with Interview Copilot (`~/Library/Application Support/InterviewCopilot/models/`):
  `ggml-large-v3-turbo-q5_0.bin` (574,041,195 B), `ggml-small-q5_1.bin`, `ggml-medium-q5_0.bin`.

**whisper.cpp** (GitHub API `repos/ggml-org/whisper.cpp/releases`, 2026-10-25):
- the latest tag `v1.9.5` (2026-10-06) has no files; the XCFramework is in the build release **`b5454`** (2026-10-06):
  `whisper-b5454-xcframework.zip`, 65,816,082 B, SHA256 `e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b`.
  The same version as in IC (`Package.swift` of IC, commit `cf0e764`).

**Groq** (https://console.groq.com/docs/rate-limits, https://console.groq.com/docs/models, https://console.groq.com/docs/billing-faqs — read on 2026-10-25):
- The Free Plan, chat models: `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b` (preview) — each has 30 RPM, 1K RPD, 8K TPM, 200K TPD.
  `llama-3.1-8b-instant`, `llama-3.3-70b-versatile`, `minimaxai/minimax-m2.7`, `meta-models/muse-spark-open` are marked Enterprise and are not in the Free table.
- The limits are per **organization** ("Rate limits apply at the organization level"), and the table gives them separately for each model. This confirms A-4.
- Card: it is not said directly "no card"; a payment method is mentioned only for moving to the Developer tier.
- 429: the `retry-after` header (seconds), plus `x-ratelimit-*` (RPD/TPM). Used in R-29.
- The exact model list is `GET https://api.groq.com/openai/v1/models` after H-1 (without a key — 401).

**Mistral** (https://mistral.ai/pricing, https://docs.mistral.ai/getting-started/quickstarts/studio/activate-and-generate-api-key,
https://docs.mistral.ai/getting-started/quickstarts/developer/first-api-request — read on 2026-10-25):
- "Free mode: API access is enabled by default with no credit card required. Usage and rate limits apply." Base URL `https://api.mistral.ai/v1`, `/chat/completions`.
- The numeric limits of Free mode were **not found**: the tier pages (`/deployment/ai-studio/tier/`, `/deployment/laplateforme/tier/`, a help-center article) return 404.
  They cannot be reconstructed from memory; the chain reacts to 429/`retry-after` dynamically, so the implementation does not need the numbers.
  If the owner adds a Mistral key in H-1, the limits are visible in their console.

**OpenRouter** (https://openrouter.ai/docs/api-reference/limits, https://openrouter.ai/docs/faq, `GET https://openrouter.ai/api/v1/models` — 2026-10-25):
- `:free`: 20 RPM; 50 requests per day if less than 10 credits were bought (1000 if ≥ 10, which is paid, not used). A card is not directly required for `:free`.
- Base URL `https://openrouter.ai/api/v1`, OpenAI-compatible. Requests are not logged by default.
- The catalogue has 467 models, 17 `:free`; among the chat ones: `google/gemma-4-31b-it:free`, `google/gemma-4-26b-a4b-it:free`,
  `nvidia/nemotron-3-super-120b-a12b:free`, `nvidia/nemotron-3-ultra-550b-a55b:free`, `thinkingmachines/inkling:free` and others.

**Conclusion for the plan:** the base of the chain is 2–3 Groq models (gpt-oss-120b, qwen3.8-27b, gpt-oss-20b), the fallbacks are Mistral Free and OpenRouter `:free`.
The budget of 1K requests per day per model per organization is accounted for in the evals (P-05): a `dialog` run is ≈ 80–160 requests.

## P-01. Skeleton, theme, window (2026-10-25)
**Done:**
- `Package.swift` (Swift 6.2 tools): `LingoCore` (macOS 15 / iOS 17), `LingoMac` (the product `Lingo`), `lingo-eval`, `LingoCoreTests`. No external dependencies.
- `LingoCore/Model`: `Lang`, `SessionSettings` (modes, corrections, who starts; no defaults for the role/level — A-8; `canStart` per A-3), `Session`,
  `ChatMessage`, `ReplySegment`, `Fix`, `Phrase`, `VoiceState`; `Logging/Log.swift` (R-49, subsystem `com.itmax04.lingo`).
- `LingoMac/Design/Theme.swift` — all tokens of DESIGN.md §1–§4, §6. A three-column window on the mockup fixtures (`Fixtures.swift`):
  the sidebar, the header with the source badge, the feed with bubbles (70% width, ✓/✓✓, a language label), the "Listening" voice panel with the wave,
  the input field (Enter — send, ⇧Enter — line break), the hints. The hints collapse at a width < 1280 (R-40). "Reduce motion" — a static bar.
- The app icon is drawn from the tokens (`--export-iconset`), a window snapshot is `Lingo --ui-snapshot <png>`.
- Scripts: `scripts/build-app.sh` (a build in a temporary folder outside iCloud, signing A-5), `scripts/check-core-ios.sh`, `scripts/secret-scan.sh`,
  `scripts/ensure-build-dir.sh`.

**Checks (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, 4 tests (`SessionSettingsTests`).
- `scripts/build-app.sh` — PASS: `dist/Lingo.app`, `codesign -dvvv` → `Identifier=com.itmax04.lingo.mac`, `Authority=InterviewCopilot`.
- `scripts/check-core-ios.sh` — PASS: `LingoCore` objects with `LC_BUILD_VERSION platform 2` (iOS), minos 17.0, SDK 26.2.
  A negative check: `import AppKit` in the core → FAIL (as it should).
- `scripts/secret-scan.sh` — 0 findings. A negative check with synthetic values (Groq, Mistral, email) → 3 findings, the values are masked.
- AC-11 (part): [evidence/ui-p01.png](evidence/ui-p01.png) — the mockup and the real `dist/Lingo.app` window (a `screencapture -l` snapshot) side by side.
- Contrast (DESIGN.md §8, WCAG): `text.primary` 13.8–18.2:1, `text.secondary` 6.5–8.6:1 on all column, card and bubble backgrounds — PASS (≥ 4.5).
  For reference: `text.tertiary` 4.0–5.3:1 (placeholder, icons), `text.metaOnAccent` on `bubble.user` 4.2:1 (time, 11 pt) — below 4.5, but these tokens were taken from the mockup and §8 does not set a norm for them.

## H-0. Signing certificate (2026-10-25)
The owner chose option 1 — keep the existing certificate "InterviewCopilot" (the answer "keep it", passed on by the coordinator session).
Checked: `codesign -dvvv dist/Lingo.app` → `Authority=InterviewCopilot`. "Lingo Dev" is not created; `build-app.sh` still looks for it first.

## P-02. Journal and sync, the core (2026-10-25)
**Done** (`Sources/LingoCore/Journal/`):
- `Event` (R-35: v, id-ULID, device, seq, lamport, ts UTC with ms, type, session, payload; unknown fields go to `extra`, unknown types are kept),
  `JSONValue`, `ULID`, `Payloads` (typed payloads of all 13 types).
- `JournalWriter` — appends to `journal-<yyyy-mm>.jsonl` + `synchronize()` (fsync); a truncated line is closed with a line break (R-39).
  `JournalReader` — skips a truncated last line and corrupted lines (a metric in `os_log`), a newer-schema flag.
- `Merger` → `HistoryState`: a union by `id`, the message order (`ts`, `device`, `seq`), LWW (`lamport`, then `device`) for the title,
  settings, the delete tombstone, ending/resuming, the summary, edits and "interrupted", the vocabulary ★. A pure function of the set of events.
- `JournalStore` (actor) — its own journal in `Application Support` (the source of truth, R-34), a cache of other journals, an index at start,
  `seq`/`lamport` continue after a restart, ✓✓ by the `pushedSeq` mark, "read only" on a newer schema.
- `SyncFolder` — the structure `Lingo/v1/devices/<deviceId>/` + `device.json`, writing only to its own folder, reading others through `NSFileCoordinator`,
  `startDownloadingUbiquitousItem` for files not yet downloaded (including `.icloud` placeholders), a security-scoped bookmark. `SyncScheduler` (R-38):
  launch, activation, every 60 s, end of session, the button; request coalescing; sync does not block the conversation.
- `lingo-eval sync-write | sync-now | sync-view` — the second "device" for S-19. `scripts/sync-check.py` — duplicates, "foreign writer", the number of messages,
  losses and the order in the local databases.

**Checks (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, **19 tests** in 5 suites: the event codec and unknown fields; a truncated line, a corrupted line,
  a newer schema; appending after a break; the order with equal `ts`; 50 permutations with duplicates; LWW by `lamport` and `device`; edits, "interrupted",
  the tombstone, ★/un-★, an unknown type; the property of commutativity and idempotence (30 random pairs of journals); **2 writers × 25 messages**
  through `SyncFolder` (50 messages, the same order, no duplicates, ✓✓); S-20 (no folder → "Sync folder unavailable — choose again",
  the history intact after a restart); a newer schema on another device → `readOnly`; the continuation of `seq`/`lamport`.
- S-19 through the CLI on a temporary folder: `lingo-eval sync-write … --offline` ×2 of 25, `sync-now` ×3, `scripts/sync-check.py … --expect 50` →
  `RESULT: PASS (0 losses, 0 duplicates)` (the output is translated), both local databases show `lost=0 order_mismatch_sessions=0 dup=0`. A negative check (a duplicated line) → FAIL.
- `scripts/check-core-ios.sh` — PASS (15 objects, platform 2). `scripts/secret-scan.sh` — 0 findings.
- The real iCloud folder — in P-10 (H-3).

## P-03. Model chain (2026-10-25) — up to H-1
**Done:**
- `LingoCore/LLM` (ported from IC `cf0e764` with a source header): `LLMTypes` (an HTTP error with `retry-after`), `ProviderID`/`ProviderEndpoints`
  (Groq, Mistral, OpenRouter, a custom address; HTTPS only, http only for localhost), `SSEClient` (+ `retry-after`, scrubbing the key from errors),
  `OpenAICompatibleProvider`, `ProviderChain` (R-29: "provider → model → key" steps, unlimited keys, 401/403 disable the key,
  a pause by `retry-after` or 300 s per "key + model" pair, a first-token timeout of 6 s, `restart` on a break, S-18 with "in N"),
  `KeyVerifier` (`GET /models`, chat models only), `LLMSettings` (keys without values, the chain order, models from `/models`).
- `LingoCore/Secrets/KeychainStore` — service `com.itmax04.lingo`, account = the key id (R-48).
- `LingoCore/Dialogue`: `ReplyProtocol` + the streaming `ReplyStreamParser` (R-24: `@say` sentences are handed to speech before the line ends,
  `<think>` is cut out, broken lines → `protocol_violation`), `PromptBuilder` (R-25: the wrapper, data in `<session_prompt>`, `<summary>`,
  `<transcript>`, the `interrupted_at` mark), `ContextPolicy` (R-04: N = 20, 6–40, a summary every 10 turns).
- `LingoCore/Settings/AppSettings` + `SettingsStore` (UserDefaults, tolerant decoding). `Commands/CommandKind`.
- Mac: the "Lingo Settings" window (⌘,), the "Keys and models" tab: keys by provider (add, "Check", delete, ••••last 4,
  "invalid"), "Get a key…", the chain order (on/off, a model from the `/models` list, up/down, delete, add a step), a timeout of 2–15 s.
  The source badge shows the first available step (R-32). A utility mode `Lingo --check-keys` (from the signed .app).

**Checks (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, **43 tests** in 11 suites. New: the chain on a mock provider (101 steps from 51 keys in the order
  provider → model → key; 429 → the next key; 401 → only this key is disabled, its steps with another model are skipped; a first-token timeout;
  a break in the middle of an answer → `restart`; exhaustion with `retryAfter` ≈ 120 s and a repeated run without requests; a pause of 300 s by default and per the pair
  "key + model"; no keys → S-18); the provider (429 + `retry-after: 17`, the key scrubbed from the error text; SSE and usage parsing; the request body
  for Groq/Mistral; a custom address only HTTPS/localhost); `KeyVerifier` (chat models only, 401); the protocol R-24 (all tags, 5 kinds of broken lines,
  sentences before the end of the line, `<think>` across a chunk boundary); `ContextPolicy`; **21 snapshots** of `PromptBuilder` (3 modes × 7 combinations)
  + rule checks (no "Thomas", pronunciation, Russian only on request, one question, the protocol, the `<session_prompt>` block only in "Custom prompt");
  the data is marked and `</transcript>` is cut out of an utterance.
- `scripts/build-app.sh` — PASS; the settings window was checked with a snapshot of the real window. `scripts/check-core-ios.sh` — PASS. `scripts/secret-scan.sh` — 0 findings.
- `GET /models` at Groq — **NOT RUN** until H-1 (no key).

**H-1 (2026-10-25).** The owner added a Groq key in "Settings → Keys and models" (the answer "done" through the coordinator session).
`dist/Lingo.app/Contents/MacOS/Lingo --check-keys --all-models` (the same build, there was no Keychain request); the app printed Russian, the output is translated here:
```
Groq key 1 ••••<4>: Key works · models: 4
  models: allam-2-7b, openai/gpt-oss-120b, openai/gpt-oss-20b, qwen/qwen3.8-27b
chain: on  Groq openai/gpt-oss-120b [ok]
chain: on  Groq qwen/qwen3.8-27b [ok]
chain: on  Groq openai/gpt-oss-20b [ok]
chain: on  Mistral mistral-small-latest [?]   (no key)
chain: on  OpenRouter google/gemma-4-31b-it:free [?]   (no key)
```
The Groq chat models by `GET /models` on 2026-10-25: `allam-2-7b`, `openai/gpt-oss-120b`, `openai/gpt-oss-20b`, `qwen/qwen3.8-27b`.
The default chain matches the list; `allam-2-7b` (a model for Arabic) was not added to the chain. The final order follows the `dialog` eval (P-05).
There are no Mistral and OpenRouter keys: the fallback steps are skipped until keys are added.

## P-04. Speech on the Mac (2026-10-25) — up to H-2
**Done** (`LingoCore/Speech`, `LingoCore/Audio`, `LingoCore/Commands`):
- `SpeechRecognizer` (candidates {study language, ru}, `forced` — the "I speak Russian" button), `UtteranceBuffer` (≤ 60 s in memory, R-08).
- `WhisperEngine` (ported from IC `cf0e764`): Metal, language strategies `detect | dual | smallDetect`, a trimmed context, a bilingual seed,
  a language label from the alphabet of the text. `AppleSpeechEngine` (`SFSpeechRecognizer`, on device only, in parallel for the candidates).
- `ModelStore`: the whisper catalogue with SHA256 from Hugging Face (the LFS oid, checked 2026-10-25: large-v3-turbo-q5_0 `3942…7e2`, small-q5_1 `ae85…1bb`),
  an APFS clone from the IC models or a download from HF, a checksum check. Both models were installed by clone in 0.4 s, no space is used (D-02).
- `EnergyVAD` (ported from IC, + headroom for barge-in), `VoiceDefaults`, `TurnSegmenter` (R-10 T, R-11 G, a minimum speech of 0.3 s, merging,
  a ban on merging after speech has started), `TurnTimeline`.
- `VoiceIO`: one `AVAudioEngine` — the microphone with voice processing (echo cancellation) and speech `AVSpeechSynthesizer.write` → `AVAudioPlayerNode`
  (the echo cancellation sees the assistant's voice, the barge-in position is by samples), a voice warm-up, a microphone pause while a phrase is being listened to (R-27).
  `Voices` (premium → enhanced → default), `SlowChunks` (R-15), `SpeechPace` (×0.75 / ×0.6). `Permissions` (microphone, recognition).
- `CommandDetector` (R-14…R-22): a whole utterance without filler words with a typo tolerance by length; commands with an argument by the exact beginning.
- Evals: `evals/commands/{ru,de,en}.yaml` (128 phrases, 34 negative = 26.6%), `evals/turn/timelines.yaml` (22 timelines, 29 utterances),
  `evals/audio/phrases.yaml` + `scripts/make-audio-fixtures.sh` (75 `say` recordings + ffmpeg, only the texts are in Git),
  `lingo-eval commands | turn | stt | stt-bench | tts-bench | chunk-debug | model-install`, `scripts/run-evals.sh`.
- The "Recognition check" window (`Lingo --stt-check part1|part2`, the Lingo menu): a phrase → recording into memory → whisper and Apple → WER →
  "Understood / Not understood"; the result in `~/Library/Application Support/Lingo/evals/live-stt-<part>.json` (texts only). The phrases are `Resources/live-phrases.json`,
  the script is `evals/live-script-mac.md`.

**Checks (2026-10-25):**
- `swift build` — PASS. `swift test` — PASS, **55 tests** in 14 suites (new: segmentation, the S-05 merge, the ban on merging after speech,
  noise < 0.3 s, flush, the T/G ranges; the command detector and typos; the "slower" parts; WER; the language label by alphabet; the 60 s buffer;
  model installation by clone and a refusal on a wrong checksum).
- `scripts/run-evals.sh commands` — **PASS**: 127/128 = 99.2% (≥ 95%), false positives 1/34 = 2.9% (≤ 3%). The miss: "Wie sagt man das in deiner
  Familie, weiß ich nicht" → how_to_say (the beginning matches the command). Three labels first set to fit the detector were corrected to the meaning.
- `scripts/run-evals.sh turn` — **PASS**: 29 utterances, 0% cut-offs, 0% false merges — both by the timeline and through sound synthesis + EnergyVAD.
  This is synthetic data; on live speech — H-4.
- `lingo-eval stt` (synthetic `say`, 75 recordings), whisper large-v3-turbo q5_0:

  | Variant | en | de | ru | mixed auto | mixed with the button | latency | memory |
  |---|---|---|---|---|---|---|---|
  | detect, trimmed context (as in IC) | 4/20 | 3/20 | 0/20 | 3/15 | 3/15 | 3.9 s | 761 MB |
  | detect, full context | 20/20 | 20/20 | 20/20 | 7/15 | 5/15 | 4.2–4.5 s | 763 MB |
  | dual@512 | 20/20 | 20/20 | 20/20 | 10/15 | 7/15 | 1.3–1.4 s | 754 MB |
  | smallDetect@512 | 20/20 | 20/20 | 20/20 | 10/15 | 7/15 | 1.2 s | 1148 MB |
  | **dual@512 + seed + label by alphabet (the choice)** | **20/20, language 100%** | **20/20, 100%** | **20/20, 100%** | **13/15** | **13/15** | **1.45–1.65 s** | **759 MB** |
  | small q5_1 dual@512 + seed | 20/20 | 18/20 | 19/20 | 5/15 | 4/15 | 0.5 s | 447 MB |

  "Understood" = WER ≤ 25%. The first seed coincided with the phrases of the set (a leak, 15/15) — it was replaced by a neutral one; the table shows the honest result.
- `lingo-eval tts-bench`: only voices of Default quality are installed (en Aaron, de Anna, ru Milena) → R-13: offer to download enhanced ones.
  The first synthesis with a voice ≈ 1.1 s, the following 15–40 ms → warm up the voices at the start of a session (R-14 ≤ 0.3 s). These voices give no word markers.
- `scripts/build-app.sh` — PASS (whisper.framework in the bundle, `codesign --verify --deep --strict` OK, 19 MB). `--check-keys` after the rebuild
  read the key **without** a Keychain request. `scripts/check-core-ios.sh` — PASS (the core with whisper and audio). `scripts/secret-scan.sh` — 0 findings.
- Apple Speech, live phrases, barge-in — **NOT RUN** until H-2 / H-4 (the process has no permissions and there is no live speech).

**H-2 (2026-10-25).** The owner granted the permissions (microphone, speech recognition) and went through the 18 steps of part 1 (the built-in MacBook microphone;
the owner's answer did not specify — assume the built-in one). The first launch of the window — CoreAudio −10875 (D-18), then the window opened under the main window
(fixed: the check window is on top). The microphone button did not react to the mouse (recording went by the space bar) — to be looked into in P-07.
The result: [evidence/live-stt-part1.json](evidence/live-stt-part1.json) (texts only; no audio was saved).

| | whisper: understood (WER ≤ 25% or a mark) | whisper: language | Apple: understood |
|---|---|---|---|
| en (4) | 4/4 | 4/4 | 2/4 |
| de (4) | 4/4 (de2, de3 the owner marked "not understood", WER 11% and 25%) | 4/4 | 0/4 (empty) |
| ru (4) | 4/4 | 4/4 | 0/4 (empty) |
| mixed auto (3) | 2/3 | — | 0/3 |
| mixed with the button (3) | 3/3 (mx3 marked "not understood", WER 22%) | — | 1/3 |

The whisper latency is 1.3–1.5 s (with the button 0.7 s), 2.1 s for the first phrase after loading. The typical errors are neighbouring words by sound
("sister → system", "Tag → Dank", "wohne → wanne", "seit drei Jahren → sein Dreisjärren"). The AC-16 result comes after part 2 (H-4, 75 phrases).
**The Mac engine choice: whisper** (ADR-0001). The owner proposed contextual understanding (Q28) — accepted: R-51 and `@heard` in spec 2.1.

## P-05. Dialogue quality (2026-10-25) — partly
**Done:**
- R-51 (Q28): rule 4a in the wrapper (an accent → restore the meaning, do not "correct", when in doubt ask again, `@heard`), `@heard` in the protocol,
  "understood as" under the user's bubble, the conversation context in the whisper seed / Apple `contextualStrings` (`RecognitionContext`).
- `LingoEvalKit`: `DialogCase` (YAML), `DialogRules` (protocol_ok, lang_discipline, no_pronunciation, one_question, contains_correction,
  returns_to_practice, length_by_level, asks_repeat, repeats_previous, fix_recorded, heard_ok, no_false_correction, says, hint), `DialogRunner`
  (a retry on 429/network, the result by the thresholds of evals/README.md, AC-05/AC-06 by category). Launch — `dist/Lingo.app/Contents/MacOS/Lingo --eval-dialog`
  (D-11), a recount over saved answers — `lingo-eval dialog-recheck`, the blind-review sheet — `lingo-eval blind`.
- `evals/dialog/*.yaml` — **100 cases** in 16 categories (all the minimums of evals/README.md + `asr_accent` 8; en 50 / de 50).
- The wrapper after run1: "how to say" — the variants must also be in `@say`; a Russian utterance — a variant first, then a request to repeat;
  on a request to assess pronunciation — do not mention the topic at all; 4a — an explicit ban on `@fix`/"Natürlicher" for likely recognition errors.
  The token reserve: dialog 450 (was 600), reasoning +512 (was +1024). The snapshots were updated.

**Runs (Groq, free tier, key 1):**
- run1 (the wrapper before the edits), 100 cases × 3 models, after fixing the `no_pronunciation` rule (D-20) — a recount over the same answers:
  gpt-oss-120b **70%**, qwen3.8-27b **73%**, gpt-oss-20b 65% (threshold ≥ 90%) — **FAIL**. Weak categories: asr_accent 0–25%, asr_artifacts 33–67%,
  injection 0–75%, mixed_speech 33–67%, ru_utterance 0–50%, how_to_say 38–88%. Strong: modes, repeat, slower, continue, explain 88–100%,
  correction_after/on_demand up to 100%. protocol_ok 99–100%, lang_discipline 100%, one_question 95–100%, length_by_level 100%. The median answer 0.35–0.6 s.
  12 "request errors" per model are network breaks/timeouts (now retried).
- run2 (the wrapper after the edits) was stopped at 34–39 cases per model (the first categories: modes, commands, "how to say"): it hit the **daily Groq limit
  of 200K tokens per model per organization** (the `retry-after` wait grew to 90 s and more). Partially: gpt-oss-120b **34/34** (on the same cases in run1 32/34),
  qwen 34/39, gpt-oss-20b 35/39 (how_to_say at 20b still sags).
- Conclusion: AC-05/AC-06 — **NOT RUN** on the final wrapper; a repeated full run — on a fresh quota (or with additional free Mistral/OpenRouter keys,
  at the owner's wish). The chain order by the data at hand: gpt-oss-120b → qwen3.8-27b → gpt-oss-20b (the default).
- The blind assessment (`evals/blind-review.md`) is generated after the final run.

## P-06…P-10. Sessions, voice loop, behaviour, hints, sync (2026-10-25) — implemented, the live check is H-3/H-4
- **P-06:** `DialogEngine` (core): creation/renaming/delete-tombstone/continuation, a turn with a record of user/assistant/`@fix`/`@hint`, S-18
  (the message "Models are unavailable… Try again in N min", the utterance is saved), "Answer again", an edit (`message.edited`), a summary
  every 10 turns. The window on the real journal: the "New session" screen (S-01, A-3 — the previous choice is filled in, "Start" is inactive without a correction
  mode; no "Thomas/A2"), the "…" menu (rename, delete with confirmation, show the journal), text input, editing and "Answer again",
  the answer as it is generated.
- **P-07:** `TurnController` (core): the button/space bar and continuous mode, the end of an utterance by T, merging by G (cancelling the unfinished request,
  editing the utterance, a new request), barge-in (stopping the speech, "interrupted" with a position), Esc, "I speak Russian" (one utterance), "Slow pace",
  the local "repeat" (without the model) and "slower" (×0.75 → ×0.6, parts with a pause of 0.6 s), a repeat on a bubble click. `MetricsRecorder` (R-47)
  + `scripts/metrics.py` (AC-02, AC-15, R-14). The voice panel: "Continuous", "In Russian", "Slowly", "Pause", "Finish"; space/Esc/⌥R.
  A VAD bug was found and fixed (it did not listen between recordings by the button, and in the check window it was reset and took speech for noise) — that was
  the "the microphone button does not press" at H-2 (the recording did not stop by itself). `--ui-click-test`: all three buttons of the panel work.
- **P-08:** ending (R-22): a farewell answer to the finish command + the recap R-23 in Russian (a card, in the "after" mode) + "finished" + a summary.
- **P-09:** the "Hints" panel of 4 sections (topic phrases — by a background request after the start; corrections from `@fix`; "how to say" — the `@hint`
  of the answer to the command; the ★ vocabulary by language), ▶ — the voice of the phrase's language, the microphone does not listen meanwhile, behind the assistant's speech — a queue; ★ — journal events.
- **P-10:** `SyncScheduler` in the app (launch, activation, 60 s, end of session, the button), statuses in the sidebar (a click: sync or
  "choose again"), ✓/✓✓; `Reachability` (S-17: voice and input are inactive with an explanation, history/hints/listening work);
  the "Voice" settings (voices, pace, T, G, echo cancellation, a hint about enhanced voices), "Sync" (a folder choice by `NSOpenPanel`,
  a bookmark, "Sync now"), "Data" (the path, ZIP export, deleting the local history with a confirmation); the first-launch wizard (R-45);
  the source badge — a menu "Auto (chain)" / a concrete step (R-32); the gear — the session's correction modes (R-20), "Slow pace", memory.
  The folder `~/Library/Mobile Documents/com~apple~CloudDocs/Lingo` was created by the executor.
- The chain: on 429 at all steps with a wait ≤ 12 s — a wait and a second pass (per-minute limits on the free tier).
- `Lingo --selftest <wav…>`: synthetic speech → VAD → whisper → chain → protocol (without a window and a microphone). The run of 2026-10-25 21:10:
  the recognition was right (including the mixed phrase), but all three models answered 429 (the quota was eaten by run2) → the S-18 path was checked.
  speech_end → stt_final ≈ 3.1–3.6 s = T 1.5 s + recognition ≈ 1.4 s (the context seed does not change the speed: 1.34 s with it and without).
- **Checks:** `swift test` — **79 tests** PASS (new: DialogEngine 4, TurnController 6 — barge-in ≤ 0.5 s by sound, the S-05 merge, "repeat"
  without the model ≤ 0.3 s, "slower" ×0.75 → ×0.6, Esc; hints and ★; a pinned chain step; a short 429 → a retry; the pronunciation rule),
  `scripts/check-core-ios.sh` PASS, `scripts/build-app.sh` PASS, `scripts/secret-scan.sh` 0 findings. The live voice loop, S-17, S-19/S-20
  on a real folder, AC-02/03/10/11/15 — **NOT RUN** until H-3/H-4.

## External review and Q29 (2026-10-25, evening)
The owner hit the Groq limits during a lesson (the log 20:33–21:03: 9 utterances, 10 answers, 12 refusals) and passed on an external review
(`~/Downloads/2026-10-25/1-2-3-mvp-minimum-viable/outputs/Lingo_Review_Report_2026-10-25.pdf`, 9 pages). All findings were confirmed in the code:
F-01 the evals on the same quota; F-02 the 429 retries were cut to 90 s, the cancel was swallowed by `try?`; F-03 the kind of limit and `usage` were lost; F-04 the context
by turns (20), background requests after 8 s; F-05 no reserve (only a Groq key), the build is older than the sources. The own review added:
qwen (with no prompt cache at Groq) stood second; "Try again in 3 min" was taken from the default pause, not from the provider; the `x-ratelimit-*`
remainders were not used to choose a step; the summary sent up to 42 messages.

The owner's decisions (Q29, intent): stage 1 — yes; Cloudflare Workers AI — yes (the owner registers); evals — at night in small portions;
a local model on the Mac — first "yes", then cancelled ("I changed my mind, do not install a local model on the Mac") → Q19 and AC-15 unchanged;
Colab Pro — no (paid; the Colab rules forbid web service offerings and remote proxies on all plans); the control session — tomorrow.
spec 2.2: R-04 (N = 8 + a budget), R-52 (limits and usage), AC-17 (the control 30-minute session).

**Stage 1 done (commit `8470d07`, build 19):**
- `RateLimits.swift`: the kind of limit from the 429 text (RPM/RPD/TPM/TPD), "try again in …" as a fallback period, `RateLimitSnapshot` from `x-ratelimit-*`,
  `UsageRecord`/`UsageRecorder` (`~/Library/Application Support/Lingo/usage/usage-<day>.jsonl`; input/output/cache/remainders/status/purpose;
  unknown stays empty), `TokenEstimate`. The error text up to 400 characters, the organization id is scrubbed.
- The chain: a usage record for every attempt, remainders per "key + model" pair, a step without a token reserve for the minute — to the end, a second pass
  only if all refusals are 429; the period in S-18 — only from the provider. The S-18 message: "Models are unavailable: <model — the kind of limit — retry in …>.
  The nearest attempt is in N" or "The provider did not report the recovery time".
- The context: N = 8 (a migration of the saved 20 → 8) + a budget of 6300 transcript characters; the summary — only new turns.
- The dispatcher: background requests (topic phrases, the summary) — after a turn, when no turn is going and the first step has ≥ 3000 tokens per minute;
  the topic phrases — after the first answer (instead of "after 8 s").
- The default order: gpt-oss-120b → gpt-oss-20b → qwen3.8-27b (a migration of the old order).
- Evals: by default one model, 10 cases (a portion by category, `--offset`), a request budget, in the daytime (08–23) only with `--allow-daytime`,
  the full `retry-after`, a stop at a wait > 60 s with a partial report, a cancel without new requests, a report after every case, the usage "eval".
- The tab "Settings → Quota": the daily usage by model and purpose, remainders, the last kind of refusal, the build version.
- The build: `CFBundleVersion` = the number of commits, `LingoGitRevision` (+ `-dirty`), `LingoBuildDate`; version 0.2.0.
- Voice: a recording by the button ends by itself after the pause T; the hint "The microphone gives no sound"; "In Russian" goes out after an utterance.
- **Checks:** `swift test` — **94 tests** PASS (new: parsing of limits and periods, an honest description, scrubbing the org, headers, the usage record,
  skipping a step without a reserve, a period from the text, S-18 without an invented period, the context budget, the order migration, stopping the eval at a long wait,
  the budget, a cancel, topic phrases after the first answer); `check-core-ios.sh` PASS; `--ui-click-test` PASS; `secret-scan.sh` 0 findings.
- **Not done / NOT RUN:** real requests to Groq were not sent (the day's quota is exhausted); the effect of the saving and the cache share — to be measured in the control session.
  The evals are not run tonight, so as not to spend the quota of tomorrow's control session.

## Executor decisions
- **D-01 (P-00, R-30).** The numeric limits of Mistral Free were not found (the pages return 404). It does not block: R-29 handles 429 dynamically. Values are not invented.
- **D-02 (P-00, ADR-0001 item 6, disk).** 12 GiB free. The whisper models for Lingo are taken by an APFS clone (`cp -c`) from the IC models folder
  with a SHA256 check against the Hugging Face sum — no disk space is used. If the file is missing — a download from Hugging Face with a SHA256 check.
- **D-03 (P-01, A-6).** Xcode 26.3 does not have the iOS 26.2 platform component installed (`xcodebuild … generic/platform=iOS` → "iOS 26.2 is not installed"),
  while the `iphoneos` SDK is present. I did not download the platform (several GB with 12 GiB free): `check-core-ios.sh` builds the `LingoCore` target
  through `swift build --triple arm64-apple-ios17.0 --sdk <iPhoneOS.sdk>` and checks the platform of the objects. If the platform is installed, the script also
  runs xcodebuild. For LINGO-02 (the IPA build) the platform will have to be installed: Xcode → Settings → Components.
- **D-04 (P-01, AC-14).** The repository lies on the "Desktop", which is synced with iCloud Drive: the File Provider changed files during the build
  ("modified during the build"). `.build` is a symlink to `~/Library/Caches/com.itmax04.lingo/build` (`scripts/ensure-build-dir.sh`, called from build-app.sh).
- **D-05 (P-01, DESIGN.md).** Tokens were added with the note "added, P-01": `size.waveBar` 3 pt / `space.waveGap` 4 pt, `size.statusDot` 12 pt.
  The inner padding of the segment track is 4 pt (≈ 1.5 pt on the mockup, but DESIGN.md §3 allows only a step of 4). The session rows are wider than the other elements
  of the column by 8 pt on each side, as on the mockup. The robot icon is not in SF Symbols — it is drawn as a shape (`RobotIcon`).
- **D-07 (P-02, R-37).** The event time is stored with millisecond precision and rounded on write — the order does not depend on the precision of Double.
  If an `id` matches with different content (should not happen), the choice is deterministic by (`lamport`, `device`, `seq`).
  A session is shown only when its `session.created` has arrived; events without it are stored and applied later.
- **D-08 (P-02, R-36).** If the chosen folder is called "Lingo", the structure `v1/…` is created right in it, otherwise in a subfolder "Lingo".
  Its own journal is copied into the folder in full when the size changes (one writer per file, the files are monthly and small).
- **D-09 (P-03, R-29).** 401 and 403 always disable the key; 400 only if the error text speaks about the key ("api key", "authentication"…).
  Otherwise a 400 caused by the request parameters would disable a working key. Groq, Mistral and OpenRouter answer a wrong key with the code 401.
- **D-10 (P-03, R-29).** Parallel launch (hedge) was not ported: per R-29 it is off by default, and a delay of up to 8–10 s is acceptable (Q3).
  Steps paused by 429 are skipped; steps paused by a timeout or the network are tried last if there are no fresh steps.
- **D-11 (P-03, R-48).** A Keychain with an untrusted self-signed certificate asks for access after every rebuild (the IC experience, COPILOT-01 P-11).
  Therefore everything that reads keys (the check, `GET /models`, the `dialog` evals) is launched from the signed `dist/Lingo.app` (`--check-keys`, then `--eval`),
  not from `lingo-eval`. The keys are read off the main thread. After a rebuild the owner may need to press "Always Allow".
- **D-12 (P-03, DESIGN.md).** There is no settings window on the mockup: colours, fonts, radii and spacing are from DESIGN.md, the controls are system ones
  (the dark appearance), the column widths of the chain list are technical.
- **D-13 (P-04, ADR item 6).** A trimmed `audio_ctx` to the length of the sound (an IC technique) gave garbage and looping on large-v3-turbo; a minimum of 512 frames
  keeps the quality and is 3 times faster than the full context. whisper language detection on the full context costs ≈ 2 s, so the language is chosen
  by a double pass (`dual`): cheaper and without a second model (smallDetect gives 1.15 GB, AC-15 is at risk).
- **D-14 (P-04, R-08, R-09).** Mixed speech: a bilingual `initial_prompt` seed (the text does not overlap with the eval sets) keeps both parts of the
  phrase, without it whisper dropped or translated the part in the other language. The language label is by the share of Cyrillic in the final text.
  Recognition by pieces between pauses is switched off: on synthetic data the pauses between the parts are too short, there is no gain.
- **D-15 (P-04, R-12, R-13).** Speech goes through the same `AVAudioEngine` as the microphone (`AVSpeechSynthesizer.write` → a player node):
  the voice-processing echo cancellation gets the assistant's voice as a reference signal, and the barge-in position is taken from the player position
  (the standard voices have no word markers — proportionally to the share of the part's sound that was played).
- **D-16 (P-04, R-14).** "Repeat" ≤ 0.3 s: the voices are warmed up at the start of a session (the first synthesis ≈ 1 s), the repeat is synthesised anew (15–40 ms).
- **D-17 (Git, iCloud).** On 2026-10-25 at 18:08, after `git rm --cached`, the file `.git/index` disappeared and `.git/index.lock` remained — all files became "deleted
  + untracked". The cause is probably the iCloud File Provider (the "Desktop" is synced). Restored: `mv .git/index.lock .git/index`
  (the very index that git wrote), the working files were not harmed. `git status` is checked before every commit. A recommendation for the owner in the report —
  exclude the repository from iCloud (the owner's decision, the path was set in the task). Also: to test `secret-scan.sh` a local
  probe commit with a synthetic key was made and undone with `git reset --soft HEAD~1` (not pushed, it is not in the branch history).
- **D-18 (P-04, H-2, ADR item 8).** The first launch of the check window (H-2) — a CoreAudio error −10875. The diagnostics `Lingo --audio-diag` (from the .app):
  voice processing + a player at 24 kHz mono did not start; VP without an output started but gave no samples; the VP input on this Mac is 48 kHz, **5 channels**,
  and mixing 5 channels down without a layout gave silence. Fixed: the mixer → output is connected in the format of the voice input (Apple's scheme for VP),
  the player is mono at the VP frequency, channel 0 is taken from the input; the fallback — to recreate the engine without VP. The result of the diagnostics: VP + output — there is a signal,
  "Test" from the speakers hardly gets into the microphone (a peak of 0.003 against 0.05 without VP). The commit `f7c33ba` went out with a failing new test
  (the `swift test` output went through `head`, the return code was lost) — the test was fixed in `14de755`; from now on checks run with `set -o pipefail`.
- **D-19 (P-05, quota).** Free Groq limits not only the minute (8K tokens) but also the day (200K tokens per model per organization).
  One full run of the `dialog` eval (100 cases × ≈ 2.5K tokens) almost exhausts the model's day. In a live session the wrapper is the same and is cached
  (cached tokens do not count against the Groq limit), so a conversation is cheaper. The evals and the live check H-4 are planned for a fresh quota.
- **D-20 (P-05, evals).** The `no_pronunciation` rule gave false positives on idioms ("That sounds like a lot of fun", the Russian phrase for "let us focus attention"):
  the dictionary was converted to whole-word regular expressions, idioms were removed; the 100% threshold was not changed. Forms of a request to repeat were added
  ("Please say…", "Bitte sagen Sie…"). run1 was recounted over the same answers (`lingo-eval dialog-recheck`).
- **D-21 (P-07, R-12, R-11).** Barge-in does not cancel the request to the model: the answer is appended to the journal in full with the mark "interrupted" (the position —
  by the played share of the part). Merging cancels the request only if the assistant has not started to speak yet; the merged text — by an edit of the first utterance.
  "Repeat" and "slower" are saved as the user's utterance, without a model answer.
- **D-06 (P-01, R-32).** On the fixture the source badge is "On device", as on the mockup (for the AC-11 comparison). In the Mac app the values per R-32 are:
  "Groq · <model>" or "No network" (from P-03/P-10).

## Microphone capture fix (2026-10-26)

- The cause was confirmed by the log: after the VP start the engine was stopped on an audio configuration change;
  the multichannel input format was used on the speaker side. Unconditional restarts made the problem worse.
  The limiter also recorded rejected attempts, so the one-second watchdog extended the block indefinitely.
- `VoiceIO`: the output is connected in the format of the output node after VP is switched on; notifications are coalesced and check
  the actual capture state. On a repeated asynchronous VP failure there is a recovery without echo cancellation.
  The old I/O is released before the new one is created. The limiter counts only accepted attempts and lifts the block.
- The absence of input buffers/converted samples is checked by an independent timer. When capture is lost the panel
  stops showing a recording, switches off continuous mode and offers to repeat the utterance. Cancelling the watchdog ends the timer.
  The old synthesis callback does not decrease the counter of the new queue; a stopped engine does not start the player.
- Added `--audio-stability <path>`: counters only, no audio saved and no API requests. 20 seconds of capture
  after a warm-up, a forced restart at the 11th second, a check that there is no self-start after a stop.
- PASS: `swift test` — 96 tests; after the last edit — AudioRecoveryTests + TurnControllerTests, 9 tests.
  PASS: `scripts/check-core-ios.sh`. PASS: a hardware check — 20/20 seconds, 367874 samples in total with the warm-up,
  one requested restart, zero capture failures; VP is on. The user's voice and a 30-minute session were not checked by this.
- An update: the macOS version 0.2.1, built with `scripts/build-app.sh` with the same identifier and certificate.
  The changes are made on top of the existing `main-en` working tree; other people's changes were not committed and not published.

## Next step
1. The owner: a Cloudflare Workers AI key ("Custom address") — then one check request and a record in the usage log.
2. H-3: the iCloud folder (the wizard skipped step 3 — "Sync is not set up") → S-19 on the real folder.
3. Tomorrow on a fresh quota: the control 30-minute session per the review protocol (AC-17) = a part of H-4; then at night — the `dialog` eval in portions
   of 10 cases (`--offset`), blind-review → P-11/P-12.

## Repository in English, branch `main-en` (2026-10-26)

- Owner decision Q30: the whole repository is in English; a branch where a person or another AI agent can understand the project easily.
  Work continues on **`main-en`** (branched from `feat/lingo-01` at `d2b82b5`); `feat/lingo-01` stays as the Russian history.
- Done: code, tests, scripts, `intent.md`, new `AGENTS.md` (entry point), English `README.md` and `CLAUDE.md`.
  UI strings use `String(localized:)` / `LocalizedStringKey`; LLM prompts unchanged (snapshots identical).
- Not done yet (AGENTS.md §8): the Russian String Catalog — **the app UI is English until it lands**; in-app interface language;
  remaining documents (this file included); `scripts/check-english.sh`.
- Cloudflare Workers AI added by the owner as a "Custom endpoint" chain step (`@cf/openai/gpt-oss-120b`, last in the chain);
  two single test requests through the signed app: PASS, 3.7 s and 3.8 s, recorded in the usage log. `GET /models` returns HTTP 405 there (no model list) — harmless.
- Checks: `swift test` — 96 tests PASS. `scripts/secret-scan.sh` before the push.
- Next: AC-17 control 30-minute session (owner), Premium voices Ava (en) and Anna (de) downloaded by the owner, then H-3, H-4.
