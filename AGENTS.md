# AGENTS.md — start here

This is the entry point for every AI agent (Claude Code, Codex, others) and every human working on **Lingo**.
Claude Code loads it through `CLAUDE.md`; Codex reads it directly. Keep it short and current.

Current owner decision D04-01 supersedes the historical human-review policy: AI-only implementation and review for R2/R3, with no mandatory human reviewer. See [current review policy](docs/changes/P-00/review-policy-2026-10-29.md). H-U and H-0 documents were accepted in DG-01/DG-02 on 2026-10-29. DG-03 A permits a future own docs PR and checked own merge; AI checks remain and owner manual review is not required. The current adoption build is local only, and existing PR chain merges are outside A. See [active P-00 decisions](docs/changes/P-00/handoff.md). Owner decision CX-02 (2026-11-03) lets the executor squash-merge its own PRs of the [completion plan](docs/plans/COMPLETION-PLAN-2026-11.md) after green CI and an independent AI review without open P0/P1 ([CODEX.md](docs/process/CODEX.md) §6).

## 1. First 10 minutes
1. Read this file, then [`docs/architecture/ARCHITECTURE.md`](docs/architecture/ARCHITECTURE.md), the guide of the app you touch —
   [`MAC.md`](docs/architecture/MAC.md) (Lingo for Mac) or [`WEB.md`](docs/architecture/WEB.md) (Lingo Web + Engine, all other devices) —
   and [`docs/process/SDLC.md`](docs/process/SDLC.md). Before changing anything structural read [`docs/process/EVOLVING.md`](docs/process/EVOLVING.md).
2. Open the current change: [`docs/changes/LINGO-11/`](docs/changes/LINGO-11/) — Lingo Web for friends (`intent.md`, `spec.md`, `plan.md`, `handoff.md`, ADR-0008); its documents were accepted by the owner (H-11-0); the plan steps F-1…F-24 follow. The owner paused new features on 2026-11-13, including LINGO-09 on the Mac; LINGO-11 supersedes the web part of LINGO-03. Before it: [`docs/changes/LINGO-05/`](docs/changes/LINGO-05/) — the teacher on the Mac, built through T-9 and accepted by the owner at H-05 (`intent.md`, `spec.md`, `plan.md`, `handoff.md`). LINGO-08 (vocabulary, prompting v2) is done. The web part of [`docs/changes/LINGO-03/`](docs/changes/LINGO-03/) is paused by the owner (2026-11-01: Mac first); P-07 is merged. Everything left, in order: [`docs/plans/COMPLETION-PLAN-2026-11.md`](docs/plans/COMPLETION-PLAN-2026-11.md). Codex: [`docs/process/CODEX.md`](docs/process/CODEX.md).
3. Check GitHub: open issues of the current milestone (the LINGO-11 milestones are created from the accepted plan), take the lowest-numbered unblocked step that is not an `owner-checkpoint`.
4. Make sure you are in your own worktree and branch (§5), the tree is clean, and `main` is up to date.
5. Read `handoff.md` → "Next step" before touching code.

## 2. Lingo in one paragraph
A personal voice tutor for spoken **English and German**, explanations in **Russian only on request**, for one owner (GitHub `itmax04`),
**4 × 30 minutes a day** on a phone (iPhone Air, iPhone 11), iPad, Android, Windows, other computers and a Mac — **all on free tiers**.
Two clients — **Lingo for Mac** (Swift, standalone, on-device speech recognition) and **Lingo Web** (PWA) — and the **Lingo Engine**
(Cloudflare Worker + D1) that signs the owner in with GitHub, stores the shared history, builds prompts, routes model calls within the
free quota and proxies speech recognition to Groq Whisper. The Mac already has the teacher layer (LINGO-05: spaced-repetition warm-up, scenarios, exams, progress, memory, reminder).
Later: the Mac joins the account (LINGO-04), a native iPhone client and real-time voice (LINGO-06). See [`docs/ROADMAP.md`](docs/ROADMAP.md).
LINGO-11 (accepted at H-11-0, 2026-11-13) changes the web part of this paragraph and of §7: friends get accounts by invite link instead of the owner's GitHub sign-in, keys stay in the browser, prompts and model calls run in the browser, the engine keeps accounts, sync, admin and a transit relay, and the web interface is English only without i18n keys ([ADR-0008](docs/decisions/ADR-0008-web-for-friends.md)).

## 3. Repository map
| Path | What | Status |
|---|---|---|
| `apps/mac/` (`Package.swift`, `Sources/`, `Tests/`, `Resources/`, `scripts/`) | Swift package of the Mac app (moved in P-01); eval sets and prompt snapshots live in `packages/contracts/` | working |
| `apps/web/` | React + Vite PWA | created in LINGO-11 F-1/F-9 |
| `services/engine/` | Cloudflare Worker + D1 | created in LINGO-11 F-1 |
| `packages/core-ts/` | TypeScript ports shared by web and engine | created in P-07 |
| `packages/contracts/` | event schema v1, OpenAPI, golden fixtures (later prompts and evals) | started |
| `docs/architecture/` | ARCHITECTURE (system), MAC (Mac app), WEB (web + engine), CODEBASE (repository map) | current |
| `design/` | redesign inputs; `design/redesign-2026/` reference images for every platform (LINGO-07, PR #33) | current |
| `docs/decisions/` | ADRs 0001 (Mac stack, Russian — translation pending), 0002 web stack, 0003 sign-in, 0004 repo layout, 0005 routing & quota, 0007 redesign, 0008 web for friends (accepted; replaces 0003 and parts of 0002/0005 for the web) | current |
| `docs/changes/` | SDLC folders per change; LINGO-01 frozen, LINGO-03 (Stage 0 accepted), LINGO-05 (teacher) and LINGO-08 done | current |
| `docs/process/` | SDLC, EVOLVING (how to change things), TESTING, RELEASE, STAGE-PROMPTS | current |
| `DESIGN.md` | design tokens (dark theme) — the only source of colours, type, spacing, radii | current |
| `.github/` | CI workflow, PR template | current |

## 4. Commands
Mac (the Swift package lives in `apps/mac` since P-01; `dist/` stays at the repository root):
| Command | What |
|---|---|
| `swift build --package-path apps/mac && swift test --package-path apps/mac` | build and run the Swift tests (96 at hand-over) |
| `apps/mac/scripts/build-app.sh` | build and sign `dist/Lingo.app` (self-signed "Lingo Dev" or "InterviewCopilot") |
| `open dist/Lingo.app` | run the app |
| `apps/mac/scripts/check-core-ios.sh` | LingoCore compiles for iOS |
| `dist/Lingo.app/Contents/MacOS/Lingo --check-keys` | check stored keys and print the chain (values never printed) |
| `… --eval-dialog <cases> <out> [--provider groq\|custom] [--models m] [--only ids] [--max-cases 10] [--budget 15]` | dialogue eval — night only (§6.5) |
| `… --audio-diag <file>` · `--audio-stability <file> [--duration <minutes>]` · `--selftest <wav>` · `--ui-snapshot <png>` | diagnostics |
| `python3 apps/mac/scripts/metrics.py` | turn latency and memory from the Mac metrics log |

Web and engine (from P-07/P-08 on):
| Command | What |
|---|---|
| `npm ci && npm test` | all TypeScript workspaces |
| `npm run dev -w apps/web` + `npx wrangler dev` (in `services/engine`) | local site + engine with local D1 |
| `npx wrangler d1 migrations apply lingo --remote && npx wrangler deploy` | production deploy — see [RELEASE](docs/process/RELEASE.md) |

Always:
| Command | What |
|---|---|
| `scripts/secret-scan.sh` | keys/personal data in tree + history → must be 0 findings before every push |
| `scripts/check-english.sh` | repository language policy (§7) |

## 5. How to work
- **Process:** [SDLC](docs/process/SDLC.md). One issue → one branch → one PR. Definition of Done in SDLC §6. Update `handoff.md` in the same PR.
- **Merging:** the executor squash-merges its own PR after green CI and an independent review without open P0/P1 (owner decision CX-02, 2026-11-03; rules in [CODEX.md](docs/process/CODEX.md) §6).
- **Branches:** `<type>/<issue>-<slug>` from `main`. Product-PR merges need explicit authority: owner decision CX-02 (2026-11-03) gives it for the steps of the completion plan, under [CODEX.md](docs/process/CODEX.md) §6; and the chain #1 → #31 → #34 is merged only under G-CHAIN (accepted 2026-10-31); the P-00 adoption was prepared locally and published as PR #35. While waiting, continue on a stacked branch. Never force-push, rewrite history, delete branches or merge red PRs.
- **Parallel agents:** one git worktree per agent/issue: `git worktree add ../lingo-<issue> -b <branch> origin/main`. Never work in another agent's directory; never revert changes you did not make.
- **Autonomy:** finish the whole current stage (milestone) without asking per step. Stop only at owner checkpoints `H-x`, at blockers that need the owner (accounts, keys, devices, money, scope conflicts), or when a requirement is wrong.
- **Questions to the owner:** in Russian, few, multiple choice with a recommended option; record answers in `intent.md` (decisions) or `handoff.md` (executor decisions D-xx).
- **Reporting:** at the end of a stage, a short Russian summary in the format of SDLC §10 plus PR links.

## 6. Rules (never relaxed)
1. **$0** — nothing that costs money or needs a card.
2. **Secrets** never in code, logs, tests, commits, issues, PRs or chat; never ask the owner to paste one into chat. The owner enters keys in the Mac app, the Keychain or `wrangler secret put`.
3. **Owner's systems are off-limits:** macOS settings, TCC, Keychain trust, GitHub/Cloudflare/Groq consoles — give exact steps instead.
4. **No account creation** (no Groq/Cloudflare/GitHub accounts, keys or OAuth apps) by agents.
5. **Quota:** dialogue evals and bulk model calls only at night (23:00–08:00 Europe/Berlin), budgeted; daytime only single requests.
6. **Truthful checks:** PASS / FAIL / NOT RUN with real output.
7. **No pronunciation assessment** in any form (product rule; `no_pronunciation` eval = 100 %).
8. **Dependencies** only from the ADR allow-lists (ADR-0001 Mac, ADR-0002 web/engine); anything else needs an ADR entry first.
9. **Contracts first** for behaviour shared by Swift and TypeScript (ADR-0004): update `packages/contracts` and both implementations in one PR.
10. **Privacy:** audio is never stored or logged; logs never contain utterance text or keys.

## 7. Language policy
Everything in the repository is **English**. Russian/German text is allowed only as **language data**: the Russian UI translations
(String Catalog / i18n files), utterances and vocabularies the app must understand or produce (command words, prompt examples, Russian output
headings, whisper prompt), eval and test fixtures, recorded evidence. The owner is addressed **in Russian** in chat.
UI strings: English in code (`String(localized:)` / `LocalizedStringKey` in Swift; i18n keys in the web), Russian in the catalog.

## 8. Known pitfalls
- **Free quota is the scarcest resource.** Measure before spending; the usage log/ledger shows every call. A dialog turn currently costs ≈ 2 k tokens; the 962-token output reserve is the first thing P-02 fixes.
- **Groq headers:** remaining-tokens is per minute, remaining-requests is per day; daily tokens come from our ledger.
- **Extra Groq accounts** are an owner-accepted risk (ADR-0005) — keep them as separate, switchable pools; never present them as free quota.
- **Safari/iOS audio:** playback needs a user gesture; mic + synthesis share one session; storage can be evicted; voices vary — test on devices (TESTING.md).
- **Mac audio:** voice processing gives 48 kHz × 5 channels — take channel 0; connect mixer → output in the output node's format; macOS stops the engine on configuration changes (VoiceIO restarts it, limited).
- **whisper.cpp** (`large-v3-turbo` q5_0, ≈ 760 MB RAM): do not reduce `audio_ctx` below 512 frames; language label comes from the script of the result.
- **Mac memory budget** 1.2 GB; Premium voices add 140–180 MB.
- **Keys on the Mac** are readable without prompts only by the signed app; run key-dependent checks through `dist/Lingo.app/Contents/MacOS/Lingo`.
- **The old iCloud copy** `~/Desktop/1/lingo` is obsolete; work only in `~/Developer/lingo` (and worktrees next to it).

## 9. Where to find things
| Need | Go to |
|---|---|
| Why a decision was made | `docs/decisions/` and the change's `intent.md` |
| What exactly to build | the change's `spec.md` |
| What to do next | the change's `handoff.md` → "Next step", then GitHub issues |
| How a part works | `docs/architecture/ARCHITECTURE.md`, then `MAC.md` or `WEB.md`, then the code |
| Where a file or module is | `docs/architecture/CODEBASE.md` |
| How to make a kind of change | `docs/process/EVOLVING.md` |
| All documents | `docs/README.md` |
| Data formats / API | `packages/contracts/` |
| How to test / release | `docs/process/TESTING.md`, `docs/process/RELEASE.md` |
| Start prompt for each stage | `docs/process/CODEX.md` §8 (current), `docs/process/STAGE-PROMPTS.md` (history and later changes) |
| Everything left to do, in order | `docs/plans/COMPLETION-PLAN-2026-11.md` |
| Terms | `docs/GLOSSARY.md` |
| Design | `DESIGN.md`, `docs/design/lingo-mac.webp` |

## 10. Working from the cloud (Claude Code on the web, Codex cloud, the GitHub Action)
- Cloud sessions run on Linux VMs (Ubuntu, Node 22 preinstalled) with **no Swift, Xcode or Apple frameworks**: the Mac app cannot be built,
  tested or run there. All Swift/Mac/native and mixed Swift/TS changes must be implemented and verified locally on the owner's Mac; cloud sessions prepare documentation or TS mocks within their accepted scope. Anything that needs the signed app, the Keychain, audio, `xcstringstool` or a live session is done in a
  local session on the owner's Mac — say so in the PR and in `handoff.md`.
- `area:web`, `area:engine`, `area:contracts` and docs work fully in the cloud: `npm ci && npm test`, `npx wrangler dev` with a local D1, mocked providers.
- **Never push to `main`** — always a branch and a PR. GitHub Free gives no branch protection for this private repo, so the rule is enforced
  only by you and by `.claude/settings.json` (loaded in cloud sessions together with `CLAUDE.md` → `AGENTS.md`).
- Secrets are never put into a cloud environment's env vars (anyone using the environment can read them). Tests use mocks; real provider calls,
  `wrangler secret`, migrations on the remote D1 and deploys happen at owner checkpoints from the owner's Mac.
- macOS CI minutes count ×10 against the 2,000 free Actions minutes per month: batch Swift changes and do not re-run the `mac` workflow without a reason.
