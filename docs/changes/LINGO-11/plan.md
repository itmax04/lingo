# LINGO-11: Plan

ID: LINGO-11-plan · Status: **accepted by the owner at H-11-0 (2026-11-13)** · Version: 1 · Date: 2026-11-13 · Risk: R3
Links: [intent.md](intent.md) · [spec.md](spec.md) · [handoff.md](handoff.md) · [ADR-0008](../../decisions/ADR-0008-web-for-friends.md)

**No code before the owner accepts these documents (H-11-0).** One step = one issue `[LINGO-11 F-xx] …` and one PR (≤ about 600
changed lines without fixtures, snapshots and generated files; a step that grows beyond it is split and the split is recorded in
`handoff.md`). Every PR: tests, green CI, an independent AI review without open P0/P1, `handoff.md` updated. Merging follows CX-02
because the owner extended it to this plan at H-11-0 (intent A-13).

Rules for every step:
- **Contracts first.** The engine API is changed in `packages/contracts/api/openapi.yaml` before the code. A ported module starts with
  the Swift test that records its fixture (spec FR-42); Swift work is local on the owner's Mac, and macOS CI runs are batched.
- **Model calls:** tests mock providers. Real requests are single daytime requests with the owner's key, typed by the owner into the
  local browser. Batches and evals only at night (23:00–08:00 Berlin) with a stated budget.
- **Tier** is the model tier of the step: strong (auth, sessions, keys in transit, isolation, data loss), standard (implementation
  from this plan), light (mechanical edits, documents).
- **Size.** Steps F-1, F-2, F-7, F-8, F-13, F-14 and F-18 are expected to exceed the 600-line limit (F-7 and F-8 port about 1 400
  and 1 300 Swift lines). Each is split into parts (`F-7a`, `F-7b`, …) when its issue is created after H-11-0, one PR per part,
  and the split is recorded in `handoff.md`; a part keeps the tier and the checks of its step.
- New screens follow the owner's frontend rules: DESIGN.md and the existing Mac screens first; external references only where they
  give no answer.

## Steps

### Stage A — Engine (milestone "LINGO-11 · A Engine")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-1 | Workspaces `services/engine` and `apps/web` (empty shell); OpenAPI v2 replacing the LINGO-03 contract; Worker with static assets; D1 migration 0001 (accounts, devices, sessions, links, attempt counters, events); sessions and cookie; `Origin` and JSON checks; security headers; `/api/setup` (first admin and admin recovery), `/api/join`, `/api/me`; `_headers` for static files; the two off switches (invites, relay); CI job for the engine | FR-01…FR-04, FR-11, FR-55, FR-58…FR-60, FR-62 | FAC-01, FAC-03 (part), FAC-18 (part), FAC-19 (part) | strong |
| F-2 | Pairing (link and code), guessing limits, devices list and sign-out, sign-in link, admin API (invites, friends, block, delete), own-account rename and delete | FR-05…FR-10, FR-12, FR-13 | FAC-02, FAC-03 (engine part), FAC-04 (engine part) | strong |
| F-3 | `/api/sync` (push, pull, cursor, strict validation with per-event results, import mode, batch limits, size counter, account cap and total threshold, the answer for a reached daily write limit); the isolation suite over every endpoint; a full batch is measured against the free plan's per-request limits (50 D1 queries with `batch()` as one, 100 bound parameters per statement, 10 ms CPU), the numbers go into WEB.md §6 and the batch limits are lowered if they do not fit | FR-14, FR-23 (engine side), FR-24, FR-26 | FAC-05, FAC-09 (engine part) | strong |
| F-4 | `/api/relay` with all refusals and limits; log-content test; two facts the Cloudflare documentation does not state are tested and recorded in `handoff.md`: whether Workers Logs or `wrangler tail` show header values (dummy key, local and at H-11-3), and what a production Worker's `fetch` does with a name that resolves to a private address (at H-11-3) | FR-18, FR-22, FR-59 | FAC-06 (relay part), FAC-07 | strong |

### Stage B — Core port (milestone "LINGO-11 · B Core port"; may run in parallel with stage A, it touches other folders)
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-5 | `parity.md` (both parts: every Mac requirement id and the Mac walk, each `port` row with its step and verifier); vocabulary port finished from the work of draft PR #62 (text rules, matcher, state, prompt block) against `fixtures/vocab` | FR-41, FR-42, FR-44 (logic), FR-53 | FAC-13 (inventory exists), FAC-14 | standard |
| F-6 | Prompt: `PromptProfile`, `PromptBuilder`, `ContextPolicy`, `PronunciationFilter`; Swift records the input of every snapshot | FR-39, FR-48 | FAC-12 (prompts), FAC-16 | standard |
| F-7 | Model layer: request types, SSE reader, OpenAI-compatible provider, rate-limit parsing, settings with pools, `ProviderChain`, key check, usage records; Swift records chain and key-check cases with a scripted transport | FR-16, FR-19, FR-20, FR-40 | FAC-08 (fixtures), FAC-12 (requests) | standard |
| F-8 | `DialogEngine` and `TurnController` (one turn end to end, voice state machine, barge-in, local commands, farewell) with fake clock and fake speech; Swift records turn traces | FR-34, FR-35, FR-40, FR-43 (logic) | FAC-14, FAC-15 (state machine) | standard |

### Stage C — Web shell (milestone "LINGO-11 · C Shell")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-9 | DESIGN.md §9 on v2 dark tokens; Vite + React + PWA shell; tokens as CSS variables; wide and narrow layouts with navigation; pages `/join`, `/pair`, `/signin`, `/setup` (account name shown, no redemption while signed in, the browser hint); Playwright set up; the colour-literal lint; the bundle scan in CI | FR-02 (pages), FR-49…FR-52, FR-54, FR-56, FR-57, FR-61 | FAC-01 (pages), FAC-17 (shell), FAC-18 | standard |
| F-10 | IndexedDB stores named by account, journal and sync loop with rejected-event handling; lost-store recovery; Settings → Devices (pairing QR as SVG, list, sign-out that clears the device, clearing on a refused session); the blocked screen; Settings → Data rename and "Delete my account"; the admin page | FR-05 (UI), FR-07, FR-09 (message), FR-10, FR-12, FR-23, FR-25, FR-28, FR-29 | FAC-02 (UI), FAC-03 (device part), FAC-04 (UI), FAC-09, FAC-11 | strong (clearing and sync: data loss) |
| F-11 | Key store, chain editor, pools, key check, Quota screen, onboarding wizard; single real requests per provider to record which rate-limit headers the browser can read (owner's keys, owner's hands) | FR-15…FR-21 | FAC-06, FAC-08, FAC-17 (wizard) | strong (key storage) |
| F-12 | Export to ZIP in the Mac layout; import from ZIP with the restore rules and the pause at the daily write limit; Swift test that restores a web export; the owner's Mac journal measured (bytes and event count only) to settle the default cap | FR-26 (default), FR-27, FR-66 (tooling) | FAC-10 | strong (import: data loss) |

### Stage D — Voice (milestone "LINGO-11 · D Voice and core screens")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-13 | Microphone, VAD and segmenter wiring, push-to-talk and continuous mode, WAV encoder and the Groq Whisper call (web-only code, FR-32), built-in recognition fallback, sentence-wise speech, voices and rate, barge-in, Wake Lock, metrics | FR-30…FR-38 | FAC-15 | standard |
| F-14 | Conversation screens: session list and filter, new session, feed, corrections and detail, edit, reply again, copy, translate, Finish and the finished card, voice panel | FR-43 | FAC-13 (rows), FAC-17 | standard |
| F-15 | Hints panel and sheet, "how to say", Vocabulary screen, voice settings; local-run and tunnel instructions | FR-44, FR-62, FR-63 | FAC-13 (rows), FAC-17, FAC-19 | standard |
| **H-11-1** | **Owner: the core on the Mac browser and on his phones through the tunnel** | | FAC-20 | owner |

### Stage E — Teacher (milestone "LINGO-11 · E Teacher")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-16 | Cards and FSRS, warm-up, stats, goal and streak, the Today screen | FR-45 | FAC-13, FAC-14 | standard |
| F-17 | Scenarios from the shared catalogue, own scenarios, task checklist, the Teacher screen | FR-45 | FAC-13, FAC-14 | standard |
| F-18 | Exams (B1 legacy and IELTS): catalogue, run, controller, exam panel, debrief with the pronunciation filter | FR-45, FR-48 | FAC-13, FAC-14, FAC-16 | standard |
| F-19 | Progress with own SVG charts, weekly report, memory screen | FR-45 | FAC-13, FAC-14 | standard |

### Stage F — Goethe B1 (milestone "LINGO-11 · F Goethe")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-20 | Goethe content, hub rules, mock draw, scoring and debrief parser, run formats `training` and `mock` | FR-46 | FAC-13, FAC-14 | standard |
| F-21 | Goethe screen: Training, Mock with preparation and notes, Debriefs, debrief card, second voice | FR-46 | FAC-13, FAC-17 | standard |

### Stage G — Strict tutor (milestone "LINGO-11 · G Strict tutor")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| **H-11-2** | **Owner: teacher and Goethe on one phone; then: finish LINGO-09 on the Mac first, or port what is on `main`** | | FAC-20 (H-11-2 part) | owner |
| F-22 | Port of the strict tutor and reply options from the Mac's `main` as decided; the step is re-planned (and split) after H-11-2 | FR-47 | FAC-13, FAC-14 | standard |

### Stage H — Release (milestone "LINGO-11 · H Release")
| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| F-23 | Full-parity verification: every `parity.md` row, the whole Playwright set, the security checks, expected free-plan load; `report.md`; the deploy guide in RELEASE.md; WEB.md, ARCHITECTURE, CODEBASE, AGENTS and ROADMAP brought to the built state | FR-41, FR-59 (platform logging), FR-64, FR-65 | FAC-01…FAC-19 | standard (guide: light) |
| **H-11-3** | **Owner: deploy by the guide, create the admin, import the Mac history** | FR-66 | FAC-21 | owner |
| F-24 | Checks on the deployed site with the owner; fixes; the release statement in Russian | FR-67 | FAC-22 | standard |
| **H-11-4** | **Owner: accept LINGO-11** | | report | owner |

## Order and parallel work
A (F-1 → F-2 → F-3 → F-4) and B (F-5 → F-6 → F-7 → F-8) are independent of each other. C needs F-1 (F-9), F-3 (F-10), F-7 (F-11).
F-13 needs F-8 and F-11. F-14 needs F-10 and F-13. E, F and G follow H-11-1 in this order; inside E the steps are independent after
F-16. Parallel sessions use one worktree per issue.

## Owner checkpoints
| H | When | What the owner does |
|---|---|---|
| H-11-0 | now | Accepts or corrects intent, spec, plan and ADR-0008; answers the open points in `handoff.md` |
| H-11-1 | after F-15 | Tries the core locally: Mac browser and phones through the tunnel (allows `brew install cloudflared` or declines), enters own keys himself, reports voice behaviour per device |
| H-11-2 | after F-21 | Tries the teacher and Goethe on one phone; decides the order for the strict tutor |
| H-11-3 | after F-23 | `wrangler login`, D1 database, two secrets, deploy, `/setup`, ZIP import — by the guide |
| H-11-4 | after F-24 | Reads `report.md`, accepts the change |

## Risks
| Risk | Mitigation |
|---|---|
| The Swift → TypeScript port is large and drifts from the Mac | Fixture first (FR-42), byte-identical prompts (FR-39), `parity.md` as the gate (FR-41), small steps |
| The Mac changes during the port | A-14: fixture and both sides in one PR; the parity source commit is recorded per step |
| Keys readable by page scripts | CSP, no third parties, no raw HTML, allow-listed dependencies, bundle scan (FR-55…FR-61); extra care in every review of `apps/web` |
| iOS Safari voice limits (gesture for audio, one audio session, barge-in) | Fake-audio tests first, devices at H-11-1, push-to-talk fallback per device family (FR-37) |
| Browser storage evicted, keys lost | Server copy and full pull (FR-28), wizard asks again, home-screen install advised; observed at H-11-1 |
| The browser cannot read rate-limit headers | 429 message parsing and default pause (FR-19); measured in F-11 |
| Browser voices are worse than the Mac's or missing for German | Voice choice per language, clear message when a language has no voice; reported per device at H-11-1 |
| Built-in recognition differs per browser and needs a fixed language | It is only the fallback; study language is used; the panel shows the recogniser (FR-32) |
| D1 free limits with imports (100 000 rows written per day for everyone, about three per event; database size) | Batches of 500 events and 1 MB, an import that pauses and resumes (FR-27), 10 MB per account and a 350 MB total threshold (FR-26), the owner's journal measured in F-12 |
| Workers CPU and D1 per-request limits on sync | Strict reader is linear; batch limits by count and bytes; measured in F-3 against the documented limits and lowered if needed |
| An invite opened inside a messenger, or the home-screen app with separate storage | The hint above the button (FR-02), pairing into the installed app (FR-05); tried at H-11-1 |
| Behaviour of the `LingoMac` target has no fixture | `parity.md` part 2 with a Playwright verifier per row (FR-41) |
| A bad release or a bad migration | Deploy guide: previous Worker version, database export before migrations, D1's 7-day restore, off switches (FR-65) |
| The relay abused | Session, host rules, suffixes, limits, no redirects (FR-22); strong-tier review of F-4 |
| macOS CI minutes (×10) for fixture recording | Fixtures are recorded locally and committed; Swift changes batched per stage |
| A friend loses every device | Admin sign-in link (FR-08); stated in the deploy guide |
