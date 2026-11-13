# ADR-0002: Stack of Lingo Web and the Lingo Engine

Status: **accepted** (owner brainstorms 2026-10-26) · Version 2 (replaces the v1 draft of the same day) · Context: [ARCHITECTURE](../architecture/ARCHITECTURE.md), [LINGO-03](../changes/LINGO-03/intent.md)

> **LINGO-11 notice (2026-11-13).** [ADR-0008](../decisions/ADR-0008-web-for-friends.md) is **accepted** (owner, H-11-0, 2026-11-13). It replaces, of this ADR: in item 1 the Workers AI fallback and the D1 tables for attempts and budgets; in item 3 the i18n part (Russian default UI); item 4 (recognition through the engine, Workers AI Whisper, no browser recognition); item 9 (`/api/turn`); and the `i18next` rows of the allow-list. It adds `qrcode-generator`. The rest of this ADR stays (Worker with static assets and D1, TypeScript, React + Vite PWA, `speechSynthesis`, the ported VAD, IndexedDB, the test tools). See the [LINGO-11 spec](../changes/LINGO-11/spec.md).

## Context
- The owner practises mostly on a phone (iPhone Air, iPhone 11), also on an iPad, an Android phone, a Windows PC and other people's computers; the Mac app stays standalone.
- Budget $0 (no card anywhere). Native iOS needs re-signing every 7 days without a paid Apple account, so the first cross-device client is a website.
- The owner's Cloudflare account exists (Workers AI already used by the Mac chain). Cloudflare Access is **not** used (ADR-0003).
- Two independent reviews (2026-10-26) agreed on this stack.

## Decision
1. **Hosting and backend — Cloudflare free plan.** One Worker serves the static client (Workers Static Assets) and the API; **D1** stores accounts, events, attempts and budgets; **Workers AI** is a fallback model through the Worker binding; the address is a free `*.workers.dev` name.
2. **Language — TypeScript, strict**, ES modules, npm workspaces (`apps/web`, `services/engine`, `packages/core-ts`); Node ≥ 22 (owner's Mac: Node 26, npm 11, wrangler 4.151).
3. **Client — React + Vite**, installable PWA (manifest + service worker), styles from DESIGN.md tokens as CSS custom properties (no UI kit that brings its own design), i18n with Russian as the default UI language and English available.
4. **Recognition — Groq `whisper-large-v3-turbo`** through the engine; Workers AI Whisper as fallback. No browser speech recognition (Chrome sends audio to Google; mixed ru/de is worse).
5. **Synthesis — the browser's `speechSynthesis`** with device voices; best voice per language auto-selected (Premium/Enhanced on Apple), changeable in Settings.
6. **Utterance detection — the Lingo energy VAD and segmenter ported to TypeScript** (no ML VAD), so the `turn` eval applies unchanged.
7. **Local storage — IndexedDB** via `idb`; events in the shared schema v1 (packages/contracts).
8. **Testing — Vitest** (`packages/core-ts`, `apps/web`), `@cloudflare/vitest-pool-workers` for the engine (real Workers runtime + D1), Playwright for a small set of browser flows (WebKit + Chromium) where possible.
9. **Streaming — server-sent events** from `/api/turn` (works through Workers without WebSockets; WebSockets/Durable Objects only in LINGO-06 if real-time needs them).

## Allowed dependencies (anything else needs an entry here first)
| Package | Where | Why |
|---|---|---|
| `react`, `react-dom` | web | UI |
| `vite`, `@vitejs/plugin-react`, `typescript` | build | build, types |
| `vite-plugin-pwa` | web | manifest + service worker |
| `idb` | web | IndexedDB wrapper |
| `i18next`, `react-i18next` | web | ru/en UI strings |
| `wrangler`, `@cloudflare/workers-types`, `@cloudflare/vitest-pool-workers` | engine | deploy, types, tests |
| `vitest` | all | tests |
| `@playwright/test` | web (dev) | browser flow tests |
| `ajv` | core-ts, engine | validate events and requests against `packages/contracts` schemas |
| `yaml` | core-ts (tests) | read shared eval YAML sets |
| `@types/node` | core-ts, engine (dev) | types for Node APIs used by tests and tools (reading `packages/contracts`) — added in LINGO-03 P-07a |

No auth library is needed for GitHub OAuth (two HTTPS calls); no ORM (plain D1 prepared statements); no state-management library unless a measured need appears.
Exact versions are chosen when the workspace is created (current stable from the npm registry, pinned in `package-lock.json`).

## Alternatives considered
- **React Native / Expo** — still needs iOS signing (7-day re-sign) and a rewrite; no gain for the goal.
- **Native SwiftUI on iOS** — best audio and works with a locked screen; parked to LINGO-06 as a thin client of the same engine.
- **Supabase / Firebase** — second vendor; Supabase free projects pause after inactivity; Cloudflare is already in use.
- **In-browser whisper (WASM/WebGPU)** — keeps audio local but too slow and heavy for phones.
- **Durable Objects from day one** — not needed for request/response + SSE; kept for real-time (LINGO-06).

## Consequences
- Web audio goes to Groq for recognition (owner decision W2); the Mac keeps on-device recognition.
- One vendor (Cloudflare) for hosting, data and a fallback model; free-tier limits are tracked (ARCHITECTURE §6.2, §7).
- Swift and TypeScript implement some behaviour twice; parity is enforced by `packages/contracts` fixtures (ADR-0004).
