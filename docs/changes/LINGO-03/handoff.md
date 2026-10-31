# LINGO-03: Handoff

Status: **documents v2 accepted at H-0 in DG-02 on 2026-10-29; implementation not started** · Default branch: `main` · Date: 2026-10-26

## State at hand-over (2026-10-26)
- Repository moved to `~/Developer/lingo` (fresh clone; the old iCloud copy `~/Desktop/1/lingo` is not used any more — the owner may delete it).
- `main` fast-forwarded to the former `main-en` (`1e254e7`); `feat/lingo-01` and `main-en` kept as history.
- Clean clone: `swift build` 24 s, `swift test` 96 tests pass (2026-10-26).
- Documents v2: [ARCHITECTURE](../../architecture/ARCHITECTURE.md), ADR-0002…0005, [SDLC](../../process/SDLC.md), [TESTING](../../process/TESTING.md), [RELEASE](../../process/RELEASE.md), [ROADMAP](../../ROADMAP.md), contracts (event schema + golden fixtures generated from the Swift code, OpenAPI).
- Mac app: LINGO-01 frozen; build 0.2.1 has the microphone-capture recovery; UI temporarily English (P-03 fixes it); Cloudflare Workers AI configured by the owner as a "Custom endpoint" chain step and verified with two requests.
- Reviews behind this plan (owner's Downloads folder, not in the repo): "Lingo — аудит и стратегия развития (2026-10-26).pdf", "Lingo — объединённое ревью и стратегия (2026-10-26).pdf", "Lingo_Mac_Web_Research_2026-10-26.pdf".

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| P-01 | pending PR (branch `feat/3-p01-monorepo`) | PASS: `swift test --package-path apps/mac` 112 tests in 30 suites; `apps/mac/scripts/build-app.sh` builds and signs `dist/Lingo.app`; `run-evals.sh commands` 99.2 % PASS; `check-core-ios.sh` PASS; `check-english`, `secret-scan --no-history`, `check-design` PASS. NOT RUN: live voice, providers | Rename-only move (deviation from plan: the per-checkout `.build` cache helper `ensure-build-dir.sh` was kept and ported, not removed): Swift package and Mac scripts to `apps/mac`, prompt snapshots to `packages/contracts/prompts`, eval sets to `packages/contracts/evals`; `dist/` stays at the repository root; lingo-eval defaults are relative to the repository root. |

## Executor decisions
(none yet — record as D-01, D-02, … with the reason)

## Next step

2026-10-31: LINGO-07 (PR #33) and P-00 are merged; Stage 0 P-01 is in review. After it merges, take P-02 (token economy, safe errors, night eval guard; no live batch before P-02b passes), then P-03…P-06, then stop at H-1 with a Russian checklist.
