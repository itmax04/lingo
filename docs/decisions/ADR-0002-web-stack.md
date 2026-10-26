# ADR-0002: Stack of Lingo Web (LINGO-03)

Status: **proposed** (accepted together with LINGO-03 plan) · Date: 2026-10-26 · Context: [LINGO-03 intent](../changes/LINGO-03/intent.md)

## Context
The owner wants Lingo on any device with an account and shared history (W1–W5), for free, for themselves and a few friends.
The Mac app (ADR-0001) is Swift; its behaviour (prompts, protocol, commands, VAD, merge rules) must stay identical on the web.

## Decision
1. **Hosting and backend — Cloudflare, free plan.** One Worker serves the static client (Workers static assets) and the API;
   **D1** stores accounts, events, budgets and usage; **Access** (Zero Trust free plan, one-time PIN to email, allow-list) protects everything;
   **Workers AI** is the last chain step through a binding (no token in code). The owner already has the account; wrangler 4.151 is installed.
2. **Language — TypeScript everywhere** (client, Worker, shared core), strict mode, ES modules, npm workspaces:
   `packages/core` (ports of the Swift core), `worker/`, `web/`.
3. **Client — React + Vite**, PWA (manifest + service worker). React because the owner's component sources (21st.dev) are React and it is the most common stack for later contributors and agents. Styling from DESIGN.md tokens as CSS custom properties; no UI kit that brings its own design.
4. **Speech recognition — Groq `whisper-large-v3-turbo`** through the Worker (W2), Workers AI Whisper as a fallback. No browser speech recognition (Chrome sends audio to Google; mixed ru/de quality is worse).
5. **Speech synthesis — the browser's `speechSynthesis`** with device voices (Premium/Enhanced on Apple devices). Server-side TTS is out of scope (cost and quota).
6. **Utterance detection — the Lingo energy VAD ported to TypeScript** (no ML VAD dependency), so the `turn` eval applies unchanged.
7. **Local storage — IndexedDB** through a small wrapper (`idb`); the event format of LINGO-01 is reused unchanged.
8. **Testing — Vitest** for `packages/core` and `web/`; `@cloudflare/vitest-pool-workers` for the Worker (runs tests inside the Workers runtime with D1).

## Allowed dependencies (initial list; anything else needs an entry here)
| Package | Where | Why |
|---|---|---|
| `react`, `react-dom` | web | UI |
| `vite`, `@vitejs/plugin-react`, `typescript` | build | build and types |
| `vite-plugin-pwa` | web | manifest + service worker |
| `idb` | web | IndexedDB wrapper |
| `jose` | worker | Access JWT validation |
| `wrangler`, `@cloudflare/workers-types`, `@cloudflare/vitest-pool-workers` | worker | deploy, types, tests |
| `vitest` | all | tests |
| `yaml` | packages/core (tests) | read the shared eval YAML sets |
Versions are pinned in `package-lock.json`; exact versions are chosen in P-00 from the npm registry (current stable, not from memory).

## Alternatives considered
- **React Native / Expo** — still needs iOS signing (free Apple ID: 7-day re-signing, SideStore) and a rewrite of the core; no gain over a website for the owner's goal.
- **Native SwiftUI for iOS (LINGO-02)** — best audio, but installation problems remain; parked.
- **Supabase / Firebase** for auth and data — good free tiers, but a second vendor and account; Cloudflare is already used and Access removes auth code. Supabase free projects also pause after inactivity.
- **Browser speech recognition** — free and simple, but worse with an accent and mixed speech, and Chrome sends audio to Google anyway.
- **In-browser whisper (WASM/WebGPU)** — keeps audio on the device but is too heavy for phones with acceptable latency.

## Consequences
- Audio of web utterances goes to Groq (W2); the Mac app keeps on-device recognition.
- One vendor (Cloudflare) for hosting, data, login and a fallback model; free-tier limits are tracked in the usage view.
- The Swift and TypeScript cores must stay in sync: parity tests on shared fixtures fail when they diverge.
