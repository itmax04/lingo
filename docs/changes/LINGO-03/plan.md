# LINGO-03: Plan

ID: LINGO-03-plan · Status: **pending acceptance (H-0)** · Version: 2 · Date: 2026-10-26
Links: [intent](intent.md) · [spec](spec.md) · [handoff](handoff.md) · [SDLC](../../process/SDLC.md) · [TESTING](../../process/TESTING.md) · [RELEASE](../../process/RELEASE.md)

Every step is a GitHub issue titled `[LINGO-03 P-xx] …` in the milestone of its stage. Work per [SDLC](../../process/SDLC.md):
branch → PR → green CI → owner merges; update `handoff.md` after each step.

## Owner checkpoints
| H | When | What the owner does |
|---|---|---|
| H-0 | now | Accept intent/spec/plan/ADRs (or ask for changes) |
| H-1 | after P-02…P-05 | 30-minute Mac session (AC-17 protocol); reports cut-offs, refusals, voice; confirms Russian UI |
| H-2 | before P-09 | Cloudflare + GitHub setup: `wrangler login`; create two GitHub OAuth Apps (prod + dev) and give the executor the **client ids** (not secrets); enter secrets with `wrangler secret put` (GitHub client secret, session pepper, Groq keys incl. optional extra accounts); tell the executor the GitHub numeric id is `itmax04`'s (the executor reads it from the public API) |
| H-3 | after P-09 | Device spike: open the spike URL on iPhone Air, iPhone 11, iPad, Android, Windows; run the 10-attempt barge-in check and 10 voice turns each; report what works |
| H-4 | after P-19 | Full day (WS-11) twice, phone + Mac; sign-in on a foreign computer and sign-out; PWA install |
| H-5 | after P-20 | Review report.md and accept LINGO-03 |

## Stage 0 — Stabilise (milestone "LINGO-03 · Stage 0 — Stabilise")
| Step | What | Req. | Depends | Checks |
|---|---|---|---|---|
| P-01 | Monorepo move: Swift package → `apps/mac`; snapshots → `packages/contracts/prompts`; evals → `packages/contracts/evals`; fix paths in scripts, tests, docs, CI; remove the iCloud `.build` symlink helper | MR-01 | — | `swift test --package-path apps/mac` (96+), `apps/mac/scripts/build-app.sh`, CI green |
| P-02 | Token economy on the Mac: measure reply-length distribution from the usage log, set per-purpose output reserve, compact system instructions, total input budget; re-record snapshots; one night `dialog` batch (≤ 15 requests) | MR-02 | P-01 | tests; usage log shows ≤ 1.8 k TPM charge per dialog turn; eval thresholds held |
| P-03 | Russian UI on the Mac: String Catalog (extract keys with `-emit-localized-strings` + `xcstringstool sync`, Russian texts from `git show feat/lingo-01:<file>`), compile in `build-app.sh`, Interface-language setting, missing-translation check | MR-03 | P-01 | screenshot RU/EN, check script 0 missing |
| P-04 | History export (on demand + daily to a chosen folder) and restore notes | MR-04 | P-01 | test with a temp folder |
| P-05 | Voice stability: `--audio-stability <file> --duration <min>`; key check for 404/405 custom endpoints; key pools with organization labels and owner-risk flag | MR-05, MR-06, MR-07 | P-01 | 30-min stability run file; tests |
| P-06 | English migration leftovers + `scripts/check-english.sh` enforced in CI (allow-list for language data) | MR-08 | P-01 | CI step green |

## Stage 1 — Evidence (milestone "LINGO-03 · Stage 1 — Evidence")
| Step | What | Req. | Depends | Checks |
|---|---|---|---|---|
| P-07 | npm workspaces skeleton: root `package.json`, `packages/core-ts` (event types, ULID, reducer/merge, reply parser, command detector, VAD + segmenter) with parity tests against `packages/contracts` | WR-05, WR-08, WR-20 (VAD), WR-21 (commands) | P-01 | `npm test`: merge golden file, `commands` ≥ 95 %, `turn` thresholds, protocol tests |
| P-08 | Engine skeleton: Worker + static assets, `wrangler.jsonc`, D1 migration 0001 (accounts, auth_sessions, devices, events, turns, attempts, leases, budgets), GitHub OAuth + sessions + origin checks, `/api/me` | WR-01…WR-04, WR-27 | P-07, **H-2** | engine tests (vitest-pool-workers): auth flows, forged cookie, foreign id, wrong origin |
| P-09 | Voice spike page (behind sign-in): mic + level meter + VAD → MediaRecorder → `/api/transcribe` (Groq Whisper) → fixed reply → `speechSynthesis`; barge-in timer; Wake Lock; metrics export; deploy to `*.workers.dev` | WR-17, WR-20 | P-08 | deployed URL; local tests |
| P-10 | Model comparison on the language set (20 EN + 20 DE + 20 RU switches) for 120b, 20b, qwen, Workers AI 20b/120b — **night, budgeted**; choose routes | WR-14 | P-08 | eval report in `evidence/` |
| P-11 | Tempo and tokens: from H-1 data and P-10, calibrate the day plan (replies per session, tokens per turn, headroom) | WR-15 | H-1, P-10 | capacity table in handoff |
| — | **H-3 gate**: device results decide Stage 2 voice design (continuous on iOS or push-to-talk only + tap to stop) | | P-09 | owner report |

## Stage 2 — Lingo Web (milestone "LINGO-03 · Stage 2 — Lingo Web")
| Step | What | Req. | Depends | Checks |
|---|---|---|---|---|
| P-12 | Sync API + idempotency + cursor + validation; isolation tests; storage hygiene hooks | WR-05…WR-07, WR-10 | P-08 | engine tests incl. WS-09 simulation |
| P-13 | Turn API: TS prompt builder (snapshots byte-identical), router with pools and per-purpose routes (incl. owner-risk pools), Workers AI binding, SSE stream, attempts/states, cancel, status, lease, budgets, `/api/budget` | WR-11…WR-16 | P-07, P-08, P-11 | engine tests with mocked providers; one real request per pool (daytime single) |
| P-14 | Transcribe API hardening: fallback, limits, context hint, conservative audio-second accounting | WR-17 | P-09 | tests |
| P-15 | Web shell: React + Vite + PWA skeleton, DESIGN.md tokens, i18n ru/en, layouts wide/narrow, sessions list, new session, feed, text input, IndexedDB store, sync loop | WR-09, WR-19, WR-22, WR-23 | P-12 | Playwright flows; screenshots 1280×800, 390×844 |
| P-16 | Web voice loop: mic modes, VAD/segmenter, recorder, transcribe, streaming speech by sentence, barge-in, local repeat/slower, Wake Lock, stage metrics, honest states | WR-20, WR-26 | P-13, P-14, P-15, H-3 | unit tests with fake audio; device re-check on iPhone |
| P-17 | Behaviour: commands, correction modes, recap, `@heard`, hints (4 sections), vocabulary ★, topic phrases and summary as background requests after the turn | WR-21 | P-16 | ported tests; night `dialog` eval via engine |
| P-18 | Settings, privacy note, first-run, export, delete my data, Resources screen, signed-in devices, sign out everywhere | WR-02, WR-24, WR-25, WS-10 | P-15 | tests + screenshots |
| P-19 | CI completion (bundle scan, Playwright, path filters) and production deploy per RELEASE.md | WR-18, WR-27…WR-29 | P-15 | deploy checklist |
| P-20 | Report: report.md with evidence for WAC-01…WAC-14 after H-4; README/AGENTS/ARCHITECTURE updated | all | H-4 | H-5 |

## Parallel work
Independent after P-01: P-02, P-03, P-04, P-05, P-06 (different files; use separate worktrees).
Independent after P-07/P-08: P-09, P-10, P-12. P-13 waits for P-11; P-16 waits for H-3.

## Risks
| Risk | Effect | Mitigation |
|---|---|---|
| iOS Safari voice limits (mic + synthesis, barge-in, user-gesture audio) | worse phone UX | P-09 + H-3 gate before P-16; fallback push-to-talk + tap-to-stop |
| Free quota for 4 × 30 | refusals in the 3rd/4th session | P-02 economy, routes over several pools, Workers AI 20b reserve, full-day test |
| Extra Groq accounts suspended (AUP) | loss of extra pools, possibly the main one | owner risk accepted; one-switch disable; main org + Workers AI still work |
| Workers free CPU (10 ms) | long requests cut | streaming is I/O; keep parsing light; measure in P-13 |
| D1 500 MB | writes fail later | archive at 400 MB (WR-10) |
| Browser storage eviction | local history lost | server copy is the source; export |
| Two implementations drift (Swift/TS) | different behaviour | contracts + parity tests in CI |
| GitHub Actions free minutes | CI throttled | path filters; macOS jobs only for `apps/mac` changes |
