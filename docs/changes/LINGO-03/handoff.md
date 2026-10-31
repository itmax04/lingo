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
| P-03 | pending PR (branch `feat/3-p03-russian-default`) | PASS: `swift test --package-path apps/mac` 116 tests in 32 suites (fresh install resolves to Russian; System and English stay explicit choices); `scripts/check-design.py` 380 bilingual strings, 0 missing; screenshots RU/EN in `evidence/P-03/` (session dates follow the UI language: "27 окт., 15:00" / "Oct 27, 3:00 PM"). NOT RUN: owner check of the default on a clean macOS user | The String Catalogs from LINGO-07 were reused, not recreated. Only the first-run default changed from "system" to "ru" (owner decision D01-01, MR-03): installs with no stored language key now start in Russian; stored values ("system", "en", "ru") are kept. The screenshots are explicit-language renders (`--ui-language ru` / `en`); the default itself is covered by the unit test. |

## Executor decisions
(none yet — record as D-01, D-02, … with the reason)

## Next step

2026-10-31: P-01 (PR #36) and P-02a (PR #37) are merged; P-03 is in its PR. Next: P-04 (history export coverage and restore before any scheduled backup; the owner chooses the folder), then P-05 and P-06. P-02b (prompt compaction, night `dialog` batch of at most 15 requests, 23:00-08:00 Berlin) is still open and is run at night.
