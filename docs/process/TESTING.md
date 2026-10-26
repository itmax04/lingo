# Lingo — testing strategy

## Pyramid

| Level | What | Tool | Runs |
|---|---|---|---|
| Unit | pure logic: reducer/merge, ULID, reply parser, command detector, VAD/segmenter, prompt builder, router, budget math | Swift Testing (`apps/mac`), Vitest (`packages/core-ts`, `services/engine`, `apps/web`) | every PR (CI) |
| Contract / parity | same fixtures, both languages: prompt snapshots byte-identical, `commands` and `turn` eval sets, merge golden files, event schema round-trip | Swift + Vitest reading `packages/contracts` | every PR touching shared behaviour |
| Engine integration | real Workers runtime + D1: auth flow, isolation, sync idempotency, lease, turn SSE with mocked providers, budgets, error mapping | `@cloudflare/vitest-pool-workers` | every PR touching the engine |
| Browser flows | sign-in redirect, session list, text turn with a mocked engine, offline open | Playwright (Chromium + WebKit) | PRs touching the web UI |
| Offline evals | `commands` (≥ 95%), `turn` (cuts ≤ 10%, false merges ≤ 5%), `audio` (WER, language) | `lingo-eval` / TS runner | on demand, before releases |
| Model evals | `dialog` rules (all ≥ 90%, `no_pronunciation` 100%), language set 20 EN + 20 DE + 20 RU switches | eval runner against a real provider | **night only, budgeted** (SDLC §8.5) |
| Device tests | real hardware matrix below | owner checkpoint | per stage |
| Full day | 2 DE + 2 EN × 30 min, ledger of every attempt, repeated on a second day | owner checkpoint | before acceptance |

## Device matrix (owner's devices, 2026-10-26)

| Device | Browser / app | Must pass |
|---|---|---|
| iPhone Air (iOS 27) | Safari + home-screen PWA | voice turn, barge-in, Wake Lock, 30 min, offline open |
| iPhone 11 | Safari + PWA | same; it is the low-end bound for latency and memory |
| iPad | Safari + PWA | same + wide layout |
| Android phone | Chrome + PWA | voice turn, barge-in, install |
| Windows PC | Chrome / Edge | voice turn, layout, sign-in on a foreign machine and sign-out |
| MacBook Air M1 | Lingo for Mac; Safari + Chrome for the web | Mac: AC-17 30 min; web: as above |

Record for each run: OS and browser version, voice used, MediaRecorder MIME type, headphones/speaker, model and pool, stage timings.

## Latency marks (both clients)
`speech_end`, `endpoint`, `upload_start`, `transcript_ready`, `llm_start`, `first_text`, `final_text`, `tts_enqueue`, `audible_start`,
`interrupt_start`, `audible_stop`. Report median and p90 per segment, not only end-to-end.

## Rules
- Tests are deterministic: fixed clocks and seeds, no network in unit/contract tests, mocked providers in integration tests.
- No real keys in tests; synthetic data only; no recordings of the owner's voice in the repository.
- A flaky test is a bug: fix or quarantine with an issue, never retry-until-green.
- Golden files are regenerated from the reference implementation, never hand-edited to pass.
