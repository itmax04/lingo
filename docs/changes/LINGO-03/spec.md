# LINGO-03: Specification — Lingo Web with accounts

ID: LINGO-03-spec · Status: **draft** · Version: 1 · Date: 2026-10-26 · Owner: itmax04
Links: [intent.md](intent.md) (goal, scope, decisions W1–W5, assumptions B-1…B-6) · [plan.md](plan.md) · [ADR-0002](../../decisions/ADR-0002-web-stack.md) ·
[LINGO-01 spec](../LINGO-01/spec.md) (behaviour reused by reference) · [DESIGN.md](../../../DESIGN.md)

IDs in this change use a `W` prefix (`WS-`, `WR-`, `WAC-`) so they never clash with LINGO-01 IDs.
Where behaviour is the same as on the Mac, the requirement says "as R-nn" and LINGO-01 spec is the source of truth for the details.

## 1. Terms
- **Account** — one person allowed by the owner; identified by the email that Cloudflare Access verified.
- **Device** — one browser profile (or, later, the Mac app) with its own `deviceId` and its own event stream.
- **Server** — the Lingo Worker on Cloudflare: static site + API + D1 database.
- **Budget** — the per-account daily allowance of chat turns and recognized audio seconds.
- Everything else as in LINGO-01 spec §1 (session, utterance, turn, command, chain, reply protocol).

## 2. Scenarios
- **WS-01. First login.** The owner opens the site on an iPhone. Cloudflare Access asks for an email and sends a one-time code.
  After the code the app opens; on the first visit a short wizard asks for microphone access and explains what is stored (privacy note, WR-24).
- **WS-02. Same history everywhere.** The owner creates a session on the Mac browser, says three utterances, then opens the site on the iPad.
  Within 10 s of opening (or of pressing "Sync") the session and all its messages are there, in the same order.
- **WS-03. Voice turn on a phone.** The owner taps the microphone, speaks a German sentence, taps again (or pauses for T in continuous mode).
  The utterance appears as a bubble with its language; the reply appears as it streams and is spoken by the German device voice.
- **WS-04. Barge-in on a phone.** While the assistant speaks, the owner starts talking. Speech stops (target ≤ 0.7 s, measured in P-01/H-1; if the browser cannot do it, a tap on the panel stops speech and this is documented).
- **WS-05. Offline reading.** Without a network the site opens from the cache, shows the history, hints and vocabulary; voice and input are disabled with the reason.
- **WS-06. A friend.** The owner adds a friend's email to the allow-list. The friend logs in and sees an empty Lingo; the friend cannot see the owner's sessions, and the owner's account does not show the friend's.
- **WS-07. Budget reached.** A friend has used the daily budget. The next turn is not sent; the app says "Daily limit reached, resets at 00:00 UTC". The owner's account is not affected.
- **WS-08. Provider limits.** All Groq steps return 429. The server falls back to Workers AI; if that fails too, the reply says which limit was hit and when to retry (as S-18 and R-52).
- **WS-09. Two devices offline.** Two browsers add 25 messages each to the same session while offline; after both reconnect and sync, both show all 50 messages in the same order, with no duplicates or losses (as S-19).
- **WS-10. Delete my data.** In Settings → Data an account deletes all its data; the server removes its events and usage records and the browser clears its local copy.
- All conversation scenarios of LINGO-01 (S-01, S-05…S-16) apply unchanged to the web client.

## 3. Requirements

### Accounts and access
- **WR-01. Login.** The whole site, including the API, is behind Cloudflare Access (one-time PIN to email, allow-list of emails). No request reaches the Worker without a valid Access identity, except the device-token API of WR-05.
- **WR-02. Identity.** The Worker validates the `Cf-Access-Jwt-Assertion` JWT (signature against the team's public keys, audience = the Access application) and maps the verified email to an account id. Headers that only *claim* an identity are never trusted.
- **WR-03. Isolation.** Every database query is scoped by account id. Tests prove that one account can neither read nor write another account's events.
- **WR-04. Allow-list.** Only the owner manages who can log in (in the Cloudflare dashboard). The app lists the accounts that exist and their budgets for the owner only.
- **WR-05. Device tokens (for the Mac app, optional in this change).** A logged-in account can create a long random device token in Settings; it is shown once, stored on the server only as a hash, can be revoked, and authorizes only the sync API of that account.

### Sync and storage
- **WR-06. Event format.** Exactly the LINGO-01 event format (R-35): `v`, `id` (ULID), `device`, `seq`, `lamport`, `ts`, `type`, `session`, `payload`; unknown types and fields are preserved.
- **WR-07. Server store.** D1 table of events per account with a unique `(account, id)`; a per-account monotonic server cursor. Writes are idempotent (re-sending the same events changes nothing).
- **WR-08. Sync API.** `POST /api/sync` with the device's new events and its last cursor → stores them and returns the events of other devices after that cursor plus the new cursor. Batches ≤ 500 events; payload size limited.
- **WR-09. Merge.** The client builds state with the LINGO-01 merge rules (R-37), ported to TypeScript and checked by the same property tests (commutative, idempotent).
- **WR-10. Local store.** The browser keeps its own events and a cache of the others in IndexedDB; the UI renders from local state and never waits for the network to show history.
- **WR-11. When to sync.** On open, when the tab becomes visible, every 30 s while visible, after each turn, and with a "Sync" button. Status in the sidebar: "Synced at HH:MM", "Offline", "Sync error — retrying".

### Model chain and speech recognition (server)
- **WR-12. Chain.** The Worker runs the LINGO-01 chain logic (R-29, R-52) in TypeScript: steps "provider + model + key", fallback on 429/5xx/network/refusal/first-token timeout, honest limit messages, usage records. Default order: Groq `openai/gpt-oss-120b` → Groq `openai/gpt-oss-20b` → Groq `qwen/qwen3.8-27b` → Workers AI `@cf/openai/gpt-oss-120b` (through the Workers AI binding, no token).
- **WR-13. Prompts on the server.** The client sends a structured turn (session settings, summary, the context window, the detected command); the server builds the prompt with the ported `PromptBuilder` (R-25). The API does not accept free-form system prompts, so the owner's keys cannot be used as a general-purpose chatbot.
- **WR-14. Streaming.** The reply streams to the client (server-sent events) so that text appears as it is generated and speech starts with the first finished sentence (R-13).
- **WR-15. Recognition.** `POST /api/transcribe` with one utterance (≤ 60 s, ≤ 4 MB, `audio/webm` or `audio/mp4`) → Groq `whisper-large-v3-turbo` with the bilingual prompt and the conversation context (R-51); fallback to Workers AI Whisper. The language label follows the script of the result (Cyrillic → ru), as on the Mac. Audio is forwarded and discarded: never stored, never logged.
- **WR-16. Budgets.** Per account per UTC day: chat turns and recognized audio seconds (counted as Groq counts them, ≥ 10 s per clip). Defaults: owner — unlimited within provider limits; friends — 60 turns and 1800 s. Checked before calling a provider.
- **WR-17. Usage log.** One D1 row per provider call: account, purpose, provider, model, status, limit kind, retry-after, tokens or audio seconds, latency. No utterance text, no audio, no keys.
- **WR-18. Keys.** Groq keys are Worker secrets (`GROQ_KEY_1…N`). They never appear in responses, logs, the client bundle or the repository; a check scans the built client for key patterns.

### Web client
- **WR-19. Layout.** DESIGN.md tokens only. ≥ 1100 px wide: the three columns of the Mac mockup (sidebar | feed + voice panel + input | hints). Narrower: one column with the sidebar and the hints as slide-over panels. Touch targets ≥ 44 pt on touch devices.
- **WR-20. Voice in the browser.**
  - Microphone with `echoCancellation`, `noiseSuppression`, `autoGainControl` on.
  - Utterance detection: the LINGO-01 energy VAD and segmenter (pause T, merge G, R-10/R-11) ported to TypeScript and checked on the same `turn` eval timelines.
  - Push-to-talk (button, space on keyboards, Esc cancels) and continuous mode (R-06, R-07).
  - Barge-in while speaking (R-12) with a raised VAD threshold; target ≤ 0.7 s on phones, ≤ 0.5 s on the Mac.
  - Speech synthesis with the device voices (`speechSynthesis`); the best voice per language is chosen automatically (names containing "Premium", then "Enhanced"), changeable in Settings.
- **WR-21. Commands, corrections, hints, vocabulary, recap.** As R-14…R-23 and R-27…R-28. The local command detector is the ported `CommandDetector`, checked on the same `commands` eval (≥ 95%).
- **WR-22. PWA.** Web app manifest and a service worker: "Add to Home Screen" on iOS opens full-screen; the app shell and the history work offline.
- **WR-23. Interface language.** Russian by default, English available; all UI strings in a translation catalog.
- **WR-24. Privacy note and data deletion.** First-run note: what is stored (text of the dialogues, settings), what is sent to providers (utterance audio to Groq for recognition, text to the model providers), and how to delete everything (WS-10).
- **WR-25. Settings.** Voice per language and rate; pause T and merge G; interface language; sync status; device tokens (WR-05); "Delete my data"; the owner sees accounts, budgets and today's usage.

### Operations and security
- **WR-26. Deployment.** One Worker serves the static client and the API (`wrangler deploy`); D1 migrations are versioned in the repository; the deploy is reproducible from a clean clone.
- **WR-27. Logs.** Worker logs contain request ids, statuses, latencies and account ids, never utterance text, audio or keys.
- **WR-28. Abuse limits.** Request size limits (WR-08, WR-15), per-account rate limit (≤ 30 API calls per minute), only known purposes accepted by the chat endpoint.

### Threat model (short)
| Asset | Threat | Measure |
|---|---|---|
| Groq keys | Leak through the client, logs, repo | Worker secrets only (WR-18), bundle scan, secret-scan in CI-style checks |
| Owner's quota | A friend or a leaked session burns it | Access allow-list (WR-01), per-account budgets (WR-16), rate limit (WR-28), structured prompts only (WR-13) |
| Dialogue history | Another account reads it | JWT validation (WR-02), account-scoped queries + isolation tests (WR-03) |
| Audio | Stored or logged | Forwarded to Groq and discarded (WR-15); W2 documents that it leaves the device |
| Sync data | Duplicates, losses, conflicts | Idempotent writes (WR-07), LINGO-01 merge rules (WR-09), WS-09 test |
| Device tokens | Theft | Hash only on the server, revocable, sync-only scope (WR-05) |

## 4. Acceptance criteria
| AC | Criterion | How it is checked |
|---|---|---|
| WAC-01 | Login works only for allow-listed emails; without Access the API answers 401/403; a forged identity header is rejected | Worker tests with signed/unsigned/forged JWTs + a manual login on the deployed site (H-2) |
| WAC-02 | Account isolation: no cross-account reads or writes | Worker integration tests (two accounts) |
| WAC-03 | Sync: WS-02 within 10 s; WS-09 — 0 losses, 0 duplicates, same order on both devices | TS property tests + a scripted two-device run against the deployed API + manual WS-02 (H-2) |
| WAC-04 | Voice on iPhone Safari, iPad Safari and Mac Chrome/Safari: push-to-talk and continuous mode work; `speech_end → first_audio` median ≤ 8 s, p90 ≤ 10 s | H-1 (spike) and H-2 live session with the client's metrics export |
| WAC-05 | Barge-in: phone ≤ 0.7 s in ≥ 8 of 10 attempts, Mac ≤ 0.5 s in ≥ 9 of 10; if a browser cannot, the limitation and the fallback (tap to stop) are documented | H-1, H-2 |
| WAC-06 | Behaviour parity with the Mac: prompt snapshots identical to `Tests/LingoCoreTests/Snapshots`; `commands` eval ≥ 95%; `turn` eval thresholds of LINGO-01 met; reply-protocol tests ported | `npm test` in the repository |
| WAC-07 | Dialogue quality: the `dialog` eval through the server endpoint meets the LINGO-01 thresholds (all rules ≥ 90%, `no_pronunciation` 100%) — run at night in small batches | eval runner against the deployed API |
| WAC-08 | Budgets and limits: WS-07 and WS-08 behave as specified; usage rows are written for every provider call without text or audio | Worker tests with mocked providers + the usage view |
| WAC-09 | No secrets: no key patterns in the client bundle, repository, history or Worker logs; `scripts/secret-scan.sh` = 0 findings | scan of `web/dist` + secret-scan |
| WAC-10 | PWA: installs to the iOS home screen; offline the history, hints and vocabulary open (WS-05) | H-2 |
| WAC-11 | UI follows DESIGN.md at desktop and phone widths; Russian and English interface | screenshots at 1280×800 and 390×844 next to the mockup in report.md; owner's verdict at H-2 |
| WAC-12 | Data deletion: WS-10 removes server events and usage rows of that account only | Worker test + manual check |
| WAC-13 | Reproducible: clean clone → `npm ci && npm test && npm run build` passes; `wrangler deploy` with documented secrets and migrations | commands with output in report.md |

## 5. Decisions and assumptions
- Owner decisions: W1–W5 (intent.md). LINGO-01 decisions Q1–Q30 stay valid unless W1–W5 change them (R-08 changes for the web client only, W2).
- Assumptions: B-1…B-6 (intent.md). Executor decisions go to `handoff.md`.
- Facts to verify in P-00 (third-party sources as of 2026-10-26): Groq Whisper free limits (20 RPM, 2000 RPD, 7200 audio s/hour, 28,800 audio s/day, ≥ 10 s billed per clip, 25 MB per file); Cloudflare Zero Trust free plan (≤ 50 users, one-time PIN); D1 free (5 GB, 5 M rows read and 100 K rows written per day, reset 00:00 UTC, enforced since 2026-09-01); Workers free request and CPU limits.
