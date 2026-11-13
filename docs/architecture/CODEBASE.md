# Lingo — repository map

Status: current · Version 4 · Date: 2026-11-04
Part of the documentation set: [ARCHITECTURE.md](ARCHITECTURE.md) (whole system) · [MAC.md](MAC.md) (Lingo for Mac) ·
[WEB.md](WEB.md) (Lingo Web + Engine, all other devices) · **CODEBASE.md** (this file) · [EVOLVING.md](../process/EVOLVING.md) (how to change things).

This file answers **"where is it"** for the whole repository and for the parts shared by both apps. Code details per app are in
MAC.md and WEB.md. It describes `main` plus the open hand-over PRs (#1, #31); paths marked *planned* do not exist yet and must be
created exactly there (ADR-0004). Update this file in the same PR when a top-level folder appears, moves or disappears.

---

## 1. Two apps, one repository

| | **Lingo for Mac** | **Lingo Web + Engine** (iPhone, iPad, Android, Windows, any browser) |
|---|---|---|
| Guide | [MAC.md](MAC.md) | [WEB.md](WEB.md) |
| Code | `apps/mac/` (Swift package, moved in P-01) | `apps/web/`, `services/engine/`, `packages/core-ts/` *(planned)* |
| Language | Swift 6.2, SwiftUI + AppKit | TypeScript, React + Vite, Cloudflare Workers + D1 |
| Speech recognition | on device (whisper.cpp) | engine → Groq Whisper (fallback Workers AI) |
| Models and keys | own chain, keys in the Keychain | engine routes; keys are Worker secrets |
| History | own journal + sync folder; joins the account in LINGO-04 | IndexedDB copy + engine (D1) |
| Status | working (LINGO-01), redesign in PR #33 | documents and contracts only; built in LINGO-03 Stages 1–2 |
| CI | `ci-mac.yml` (macOS, path-filtered) | `ci-ts.yml` (Linux) |
| Shared with the other app | `packages/contracts` (events, API, prompts, evals, fixtures), `DESIGN.md`, rules in `AGENTS.md` | same |

## 2. Repository map

| Path | What | Belongs to | Status |
|---|---|---|---|
| `AGENTS.md` | Entry point for every agent: rules, commands, pitfalls | both | current |
| `CLAUDE.md` | Claude Code loader: imports `AGENTS.md` and `DESIGN.md` | both | current |
| `README.md` | Human overview and quick start | both | current |
| `DESIGN.md` | Design tokens — the only source of colours, type, spacing, radii; §9 web adaptation (v2 in PR #33) | both | current |
| `apps/mac/` (`Package.swift`, `Sources/`, `Tests/`, `Resources/`, `scripts/`) | Swift package of the Mac app | Mac | working |
| `packages/contracts/evals/` | Eval sets and live script (moved from `evals/` in P-01) | both | working |
| `packages/contracts/` | Event schema v1, OpenAPI, golden fixtures; later prompts and evals | both | started |
| `packages/core-ts/` | TypeScript ports of shared logic | Web | *planned* P-07 |
| `services/engine/` | Cloudflare Worker + D1 | Web | *planned* P-08 |
| `apps/web/` | React + Vite PWA | Web | *planned* P-15 |
| `apps/mac/` | Home of the Swift package | Mac | working (P-01) |
| `apps/mac/Sources/LingoCore/Teacher/ExamController.swift` | Live exam coordination, phase events, monologue release, recognition/speech deadline guards; host attachment before the first reply | Mac | T-6a2a |
| `apps/mac/Sources/LingoMac/ExamServices.swift`, `Views/ExamPanel.swift` | Live exam attachment/lifecycle, Teacher start actions, task/cue-card panels, timers and Done; Goethe Mock preparation (`beginMockPrep`, `finishMockPrep`, `discardMockPrep`) and the start guards | Mac | T-6a2b, LINGO-10 G-5b, G-6 |
| `apps/mac/Sources/LingoMac/Views/GoetheScreen.swift` | Goethe B1 Sprechen screen: Training, Mock (preparation, notes, locking), Debriefs | Mac | LINGO-10 G-5a, G-5b |
| `apps/mac/Sources/LingoMac/Views/GoetheDebriefCard.swift` | One Goethe debrief card (scores per Teil, criteria, letters) | Mac | LINGO-10 G-4 |
| `apps/mac/Sources/LingoCore/Teacher/GoetheHub.swift`, `GoetheContent.swift` | Goethe screen model: Training rules, Mock draw (`MockDraw`, partner topic), bundled German task content | Mac | LINGO-10 G-2, G-3 |
| `apps/mac/Sources/LingoCore/Teacher/GoetheScoring.swift`, `GoetheDebrief.swift` | Goethe scoring (criteria, letters, Teil results), debrief prompt parts and parser, score filter | Mac | LINGO-10 G-2, G-4 |
| `apps/mac/Tests/LingoMacTests/GoetheScreenHostTests.swift`, `GoetheMockHostTests.swift` | Host behaviour tests for the Goethe screen, Mock preparation, notes, locking and start guards (synthetic data) | Mac | LINGO-10 G-5a, G-5b, G-6 |
| `apps/mac/Sources/LingoCore/Teacher/` | Teacher logic: cards and FSRS, warm-up, stats/goal/streak, Today plan, scenarios, Progress and weekly report, memory, exam debrief, reminder, exams | Mac | T-1…T-9 |
| `apps/mac/Sources/LingoMac/Views/{TodayView,TeacherView,ScenarioViews,ProgressScreen,MemoryScreen,ExamDebriefCard}.swift`, `apps/mac/Sources/LingoMac/Settings/ReminderSettingsView.swift`, `apps/mac/Sources/LingoMac/ReminderServices.swift` | Teacher screens, Reminder setting and the notification adapter | Mac | T-4…T-9 |
| `docs/changes/LINGO-05/evidence/` | Check logs and RU/EN, light/dark screenshots of the teacher screens (`t6a2b`, `t6b`, `t7`, `t8`, `t9`) | docs | T-6…T-9 |
| `design/redesign-2026/` | LINGO-07 reference images per platform: `01-directions`, `02-iphone`, `03-ipad`, `04-mac`, `05-web-desktop`, `06-android-windows`, `07-teacher`, `08-design-system`, `09-architecture`, `10-comparison` | both | in PR #33 |
| `design/redesign/inputs/` | Owner inputs for the redesign | both | current |
| `docs/architecture/` | ARCHITECTURE, MAC, WEB, this map | both | current |
| `docs/decisions/` | ADR-0001 Mac stack · 0002 web stack · 0003 sign-in · 0004 repo layout · 0005 routing and quota (0007 redesign in PR #33) | both | current |
| `docs/changes/LINGO-NN/` | One SDLC folder per change: intent, spec, plan, handoff, report, evidence | both | current |
| `docs/process/` | SDLC, TESTING, RELEASE, EVOLVING, STAGE-PROMPTS | both | current |
| `docs/reference/` | Owner brief, PDF patterns (background only, not requirements) | both | current |
| `scripts/` | Build, checks, evals, metrics (§4) | mostly Mac | working |
| `.github/` | `ci-repo.yml`, `ci-mac.yml`, `ci-ts.yml`, PR template | both | current |
| `.claude/settings.json` | Allowed/denied commands for Claude Code sessions | both | current |
| `private/`, `dist/`, `.build/`, `packages/contracts/evals/out/`, `node_modules/`, `.wrangler/`, models | Never committed (git-ignored) | — | — |

## 3. Shared contracts (`packages/contracts`)

| Path | What | Used by |
|---|---|---|
| `events/event.schema.json` | Journal event, schema v1 | Swift `Journal`, TS `core-ts/events`, engine `/api/sync` validation |
| `fixtures/events/*.jsonl`, `*.json` | Golden journal and merge fixtures generated by the Swift reference code | parity tests on both sides |
| `api/openapi.yaml` | Engine HTTP API | engine, web client, later the Mac adapter (LINGO-04) |
| `teacher/exams.json` | Original B1/IELTS task catalogue, generated by Swift `ExamTests` | Swift; web reuse planned under D-01 |
| `teacher/scenarios.json` | Scenario catalogue, written by Swift `ScenarioTests` | Swift; web reuse planned under D-01 |
| `teacher/tone-lines.json` | Local lines of a tone session (LINGO-09 MR-21), written by Swift `ToneLinesTests` from `ToneLines` | Swift |
| `fixtures/teacher/tone-deny-list.json` | Deny-list for the local lines (MR-06, MR-47) | Swift `ToneLinesTests` |
| `fixtures/teacher/blame-markers.json`, `blame-filter.json` | Blame marker words per language (written by Swift) and golden cases of the blame filter (MR-15) | Swift `BlameFilterTests` |
| `fixtures/events/tone-filtered.jsonl` | `tone.filtered` events (MR-15), valid and malformed | Swift and TypeScript journal tests |
| `fixtures/teacher/exam-events.jsonl` | All exam phases and malformed payloads, written by Swift | Swift + TS event decoding parity |
| `prompts/` | System-prompt snapshots | Swift `PromptBuilderTests`, engine prompt builder — byte-identical |
| `evals/` | (`packages/contracts/evals/`) `commands`, `turn`, `audio`, `dialog` sets | `lingo-eval`, TS ports, the engine eval runner |

Rule: a behaviour that exists in both apps changes here first, then in Swift and TypeScript, in **one** PR.

## 4. Scripts

| Script | Use | App |
|---|---|---|
| `build-app.sh` | build and sign `dist/Lingo.app` | Mac |
| `check-core-ios.sh` | `LingoCore` compiles for iOS | Mac |
| `run-evals.sh` | `commands` / `turn` / `audio` / `dialog` / `all` (dialog = night only) | Mac (TS ports later) |
| `make-audio-fixtures.sh` | synthetic audio for the `audio` eval | Mac |
| `metrics.py` | latency and memory from the Mac metrics log | Mac |
| `sync-check.py` | consistency of journals in a sync folder | Mac |
| `ensure-build-dir.sh` | keeps `.build` out of iCloud-synced folders | Mac |
| `check-english.sh` + `english-allowlist.txt` | repository language policy | both |
| `secret-scan.sh` | keys and personal data in tree and history — 0 findings before every push | both |

## 5. Where to change what — index

| Topic | Mac | Web + Engine | Shared first |
|---|---|---|---|
| Voice loop, barge-in | MAC.md §7 | WEB.md §7, §10 | — |
| Commands | `CommandDetector` | `core-ts/commands` | `packages/contracts/evals/commands` |
| Model instructions | `PromptBuilder` | engine `src/turn` | prompt snapshots |
| Reply protocol | `ReplyProtocol` | `core-ts/protocol` | contracts fixtures |
| Events and merge | `Journal/*` | `core-ts/events`, engine `src/sync` | `events/event.schema.json` + fixtures |
| Providers, routing, quota | `LLM/*` | engine `src/turn`, `src/ledger` | ADR-0005 |
| API | — (LINGO-04 adapter) | engine + `apps/web/src/api` | `api/openapi.yaml` |
| Database | local journal files | `services/engine/migrations` | ARCHITECTURE §6 |
| Look and feel | `Design/Theme.swift`, `Views/*` | `apps/web/src/design`, `features/*` | `DESIGN.md`, `design/redesign-2026` |
| UI strings | String Catalog | i18n files | — |
| Dependencies | ADR-0001 | ADR-0002 | — |

How to make each kind of change step by step: [EVOLVING.md](../process/EVOLVING.md).
