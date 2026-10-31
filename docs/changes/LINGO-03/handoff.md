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
| P-02a | pending PR (branch `feat/3-p02a-safety`) | PASS: `swift test --package-path apps/mac` 116 tests in 32 suites. NOT RUN: 10 live turns, night `dialog` batch, prompt compaction | Output reserve measured from the usage log (41 dialog requests: output median 70, max 204 tokens incl. reasoning): dialog reserve 450 to 300, reasoning headroom for dialog 512 to 192 (other purposes keep 512: topicPhrases and summary have few samples, recap none); `finish_reason` is now written to the usage log (old logs still decode; the dialog eval runner records it too). Not closed: the admission estimate `input + maxTokens/2` still under-reserves what Groq charges (plan F04, P-02c/d); a `length` reply is only logged, it triggers no fallback; the 41 samples were not split by level/language. |

## Executor decisions
(none yet — record as D-01, D-02, … with the reason)

## Next step

2026-10-31: P-01 is merged (PR #36); P-02a is in PR #37. Next: P-02b - compact system instructions (target 900 tokens) and a total input budget, re-record prompt snapshots in `packages/contracts/prompts`, then one night `dialog` batch (at most 15 requests, 23:00-08:00 Berlin only; the daytime quota is shared with live practice). Acceptance of P-02 (TPM charge <= 1.8 k per dialog turn after 10 live turns, no `finish_reason=length`) needs those live runs and stays NOT RUN until then. Then P-03...P-06 and the H-1 checklist.
