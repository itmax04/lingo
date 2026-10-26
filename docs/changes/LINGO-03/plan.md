# LINGO-03: Plan — Lingo Web with accounts

ID: LINGO-03-plan · Status: **draft** · Version: 1 · Date: 2026-10-26
Links: [intent.md](intent.md) · [spec.md](spec.md) · [ADR-0002](../../decisions/ADR-0002-web-stack.md) · [handoff.md](handoff.md)

Requirements are defined only in spec.md; this plan refers to their IDs.
After every step: checks (PASS / FAIL / NOT RUN with real output), `handoff.md` updated, a commit "LINGO-03 P-xx: …", `scripts/secret-scan.sh`, `git push origin main-en`.

## Owner checkpoints
| H | When | What the owner does | Why only the owner |
|---|---|---|---|
| H-0 | before P-01 | In the terminal: `wrangler login` (browser OAuth to the owner's Cloudflare account). In the Cloudflare dashboard: open Zero Trust, choose a team name (free plan), enable the one-time PIN login method, create the Access application for the Lingo Worker address with an allow-list of emails (the executor gives exact clicks). Enters Groq keys with `wrangler secret put GROQ_KEY_1` (typed in the terminal, never in chat) | Account login, security settings and keys belong to the owner |
| H-1 | after P-01 | Opens the spike page on the iPhone and iPad (and the Mac), runs the 10-attempt barge-in check and 10 voice turns, reports what works | Physical devices and the owner's voice |
| H-2 | after P-10 | A 30-minute live session on the phone and the Mac (the LINGO-01 AC-17 protocol), WS-02, WS-05, WS-06 with one friend's email, the PWA install | Real use |
| H-3 | after P-12 | Reviews report.md and accepts or returns the change | Acceptance |

## Steps
| Step | What | Requirements | Checks |
|---|---|---|---|
| P-00 | Baseline: verify the facts of spec §5 from official pages (Groq console limits page — the owner reads it out without keys; Cloudflare docs); node/npm/wrangler versions; repository layout for `web/`, `worker/`, `packages/core/` (npm workspaces); ADR-0002 accepted together with this plan | §5 | facts table in handoff.md |
| P-01 | **Feasibility spike on real devices** — a throwaway page on `*.workers.dev` behind Access: microphone with echo cancellation, energy VAD, MediaRecorder per utterance → Groq Whisper through a minimal Worker proxy → fixed reply text → `speechSynthesis`; barge-in timing; voice list per browser; PWA standalone mode quirks. **Gate:** if barge-in or simultaneous mic + speech fail on iOS Safari, the owner chooses a fallback before more is built | WR-15, WR-20, WS-03, WS-04 | H-1 results with numbers |
| P-02 | `packages/core`: TypeScript ports of PromptBuilder, ReplyProtocol (+ streaming parser), CommandDetector, ContextPolicy, TurnSegmenter, EnergyVAD, Merger, ULID and the event types; parity tests on the Swift fixtures (prompt snapshots byte-identical, `commands` and `turn` evals, merge property tests) | WR-06, WR-09, WR-21, WAC-06 | `npm test` |
| P-03 | Worker skeleton: static assets + API routing, Access JWT validation, accounts, D1 schema and migrations, `/api/sync`, isolation and idempotency tests | WR-01…WR-03, WR-06…WR-08, WR-26…WR-28, WAC-01, WAC-02 | `npm test` (Miniflare / workers test pool), `wrangler deploy` to the owner's account |
| P-04 | Model chain on the Worker: Groq steps with secrets, Workers AI fallback, SSE streaming, structured turn endpoint with server-side prompts, limit messages, usage log, budgets | WR-12…WR-14, WR-16…WR-18, WS-07, WS-08, WAC-08 | tests with mocked providers; one real request per provider (daytime: single requests only) |
| P-05 | `/api/transcribe`: Groq Whisper with bilingual prompt + context, Workers AI fallback, size/length limits, audio never stored; language label by script | WR-15 | tests + a few real clips from `evals/audio` (synthetic) |
| P-06 | Web client shell (React + Vite, DESIGN.md tokens): layouts for wide and narrow screens, sessions list, new-session screen, feed, input, local IndexedDB store, sync loop and status | WR-09…WR-11, WR-19, WR-23, WS-02, WS-05 | component tests, screenshots at 1280×800 and 390×844 |
| P-07 | Voice loop in the browser: push-to-talk, continuous mode, merge, barge-in, streaming speech by sentences, "repeat"/"slower" locally, turn metrics | WR-20, R-06…R-15, WS-03, WS-04, WAC-04, WAC-05 | unit tests with fake audio; device check |
| P-08 | Behaviour: commands, correction modes, recap, `@heard`, hints (four sections), vocabulary ★, topic phrases and summary as background requests after the turn | WR-21, R-16…R-28 | ported tests; `dialog` eval through the API at night (small batch) |
| P-09 | Settings and accounts: voices, T and G, interface language, delete my data, owner view of accounts/budgets/usage, device tokens; privacy note; first-run wizard | WR-04, WR-05, WR-24, WR-25, WS-01, WS-06, WS-10, WAC-12 | tests + manual |
| P-10 | PWA: manifest, icons from the app icon, service worker (app shell + offline history), iOS home-screen mode | WR-22, WAC-10 | install on the iPhone (H-2) |
| P-11 | *(optional, owner decides at H-2)* Mac app joins the account: "Lingo account" sync option using a device token, alongside the iCloud folder | WR-05, WR-06 | two-writer test Mac + browser |
| P-12 | Report: report.md with evidence for WAC-01…WAC-13, unverified items listed, code review, AGENTS.md and README updated, ADR-0002 finalized | all | H-3 |

## Order and gates
1. H-0 → P-00 → P-01 → **H-1 gate** (go / choose a fallback).
2. P-02…P-05 can be developed in parallel after the gate (core ports, Worker, chain, transcription); P-06…P-10 build on them.
3. H-2 after P-10 → P-11 if the owner wants it → P-12 → H-3.

## Risks
| Risk | Effect | Mitigation |
|---|---|---|
| iOS Safari: mic and speech synthesis in one audio session, no barge-in, synthesis needs a user gesture | Worse voice UX on the iPhone | P-01 gate; fallback: tap to stop speech, push-to-talk only on iOS, or server-side TTS later (a separate decision) |
| Free Groq quota shared by all accounts | Limits during practice | budgets (WR-16), Workers AI fallback (WR-12), evals only at night |
| Whisper minimum of 10 s per clip | Short utterances consume the audio budget faster | merge short utterances (G), count budgets like Groq does |
| Workers free CPU limit per request | Long streams cut off | streaming is I/O, not CPU; measure in P-04; keep heavy work on the client |
| Browser voices differ | Robotic voice on some devices | Premium/Enhanced selection, instructions to download voices on Apple devices |
| Cloudflare Access session expiry | Re-login on phones | default session length 24 h or longer, chosen at H-0 |
