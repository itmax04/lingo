# LINGO-11: Intent — Lingo Web for friends

ID: LINGO-11-intent · Status: **accepted by the owner at H-11-0 (2026-11-13)** · Version: 1 · Date: 2026-11-13 · Owner: itmax04 · Risk: **R3**
Links: [spec.md](spec.md) · [plan.md](plan.md) · [handoff.md](handoff.md) · [ADR-0008](../../decisions/ADR-0008-web-for-friends.md) ·
prior: [LINGO-03](../LINGO-03/intent.md) (web for the owner alone; its web part is superseded by this change)

## Problem
Lingo is a native Mac app for one person. The owner wants his friends to try it, and they use phones, tablets and Windows computers.
The web version planned in LINGO-03 was designed for the owner alone: sign-in with his GitHub account, his Groq keys on the server, the
prompts and the model routing in the engine, and only the basic conversation. Since then the Mac got the vocabulary (LINGO-08), the
teacher (LINGO-05) and the Goethe B1 exam (LINGO-10), all of which exist only in Swift. Nothing of the web exists yet except the shared
TypeScript package with five ported modules.

## Desired outcome
1. **A link is enough.** The owner creates an invite on an admin page and sends the link. The friend opens it, presses one button and
   has an own, empty account. No password, no e-mail.
2. **Own keys, as on the Mac.** The friend adds free API keys in the browser (a wizard explains how to get a Groq key). Keys stay on
   the friend's device.
3. **The whole Mac app in the browser**, on any device: voice conversation in English and German, corrections, hints, "how to say",
   vocabulary, history; then the teacher, the Goethe B1 exam, and last the strict tutor.
4. **One history per friend** on all of the friend's devices.
5. **Local first.** It runs on the owner's Mac (`localhost`) and on his phones through a temporary tunnel. The owner deploys to
   Cloudflare himself from a step-by-step guide.
6. **A clear end.** After full parity is verified and the deployment is checked, the executor tells the owner in plain words (in
   Russian) that the link can be sent to friends.

## Scope
- In: `apps/web` (new), `services/engine` (new), `packages/core-ts` (ports of the Mac core), `packages/contracts` (new fixtures and the
  engine API), Swift tests that record fixtures (no Mac behaviour change), `DESIGN.md` §9, architecture and process documents.
- Out: new features of any kind; changes to the Mac app's behaviour; the Mac joining the account (LINGO-04); a native iPhone app
  (LINGO-06); Russian interface, light theme and the daily reminder in the web (decisions 12, 13).
- Paused by this change: LINGO-09 on the Mac (PRs #119, #141–#145 stay as they are, decision 9).
- Superseded by this change: the web part of LINGO-03 — steps P-07c2 and P-08…P-20, issues #10…#27 and draft PR #62. Its merged work
  (P-07a…P-07f, `packages/core-ts`), the contracts and `DESIGN.md` are reused.

## Constraints
- AGENTS.md §6: $0 and no card; no secrets in code, logs, tests, commits or chat; the owner's systems are off-limits; agents create no
  accounts or keys; bulk model calls only at night; truthful checks; no pronunciation assessment; allow-listed dependencies;
  contracts first; audio never stored or logged, logs without utterance text or keys.
- The prompts do not change. A web prompt must be byte-identical to the Mac snapshot for the same input.
- Mac work (Swift fixture recording) is done locally on the owner's Mac; macOS CI minutes count ×10, so those runs are batched.
- The owner deploys; the executor never touches the Cloudflare account, production D1 or Worker secrets.

## Owner decisions (brainstorm 2026-11-13, four rounds; translated from Russian)
| # | Topic | Decision |
|---|---|---|
| 1 | Sign-in | An invite link from the admin page creates the account at once (no password, no e-mail). Extra device: QR or code from Settings. |
| 2 | Recovery | The admin issues a one-time sign-in link for an existing friend (valid 24 h). |
| 3 | Data | Server copy in D1 plus a working copy in the browser (IndexedDB); history shared across the friend's devices. Plaintext on the server; no encryption and no separate privacy screen ("not required, make it less code"). |
| 4 | API keys | Only on the friend's device (browser); never stored on the server. Requests go directly or through a stateless transit proxy (for providers without CORS). |
| 5 | Logic placement | In the browser (TypeScript in `packages/core-ts`), like the Mac. The engine is accounts, invites, device sessions, sync, admin and the transit proxy. This replaces the WEB.md statement that the engine builds prompts, routes models and holds keys. |
| 6 | Providers | All as on the Mac: Groq, Mistral, OpenRouter, custom OpenAI-compatible; chain with fallback, organization pools, key check; onboarding wizard with how to get a free Groq key. |
| 7 | Speech recognition | Groq Whisper with the friend's key; fallback is the browser's built-in recognition. |
| 8 | Scope | Full Mac parity: core (voice dialogue EN/DE, corrections, hints, "how to say", reply options, vocabulary ★, history, key and voice settings) → Teacher (warm-up with FSRS, scenarios including custom ones, exams B1/IELTS with debrief, progress, weekly report, memory, Today) → Goethe B1 (training, mock, debriefs) → strict tutor (LINGO-09) last. |
| 9 | LINGO-09 | Paused on the Mac; PRs #141–#145 are left as they are. Port last; decide then whether to finish it on the Mac first or port it as is. |
| 10 | Owner account | The owner is a normal user with admin rights; a one-time import of the Mac history from the ZIP export (journal format v1 is shared). The Mac stays standalone (LINGO-04 later). |
| 11 | Admin | Minimal UI: create and revoke invites, a friends list (name, last sign-in, device count), block, delete. No view of friends' conversations. |
| 12 | Interface | English UI only (no Russian catalog) and dark theme only. Tutor explanations and "Translate" stay Russian; prompts unchanged. |
| 13 | Reminder | Not in the web. |
| 14 | Local testing | Mac browser on localhost; phones through a temporary cloudflared quick tunnel (ask before `brew install cloudflared`). |
| 15 | Release to friends | Only after full parity. The executor must tell the owner explicitly, in Russian, that the link can be sent to friends. The owner deploys himself (write a step-by-step deploy guide). |
| 16 | Process | New change LINGO-11 (intent, spec, plan and a new ADR replacing ADR-0003 sign-in and ADR-0005 routing and quota for the web). Mark the web part of LINGO-03 (P-07c2, P-08…P-20, issues #10…#27, draft PR #62) as superseded; reuse core-ts, contracts and DESIGN.md. The owner accepts the documents (H-11-0) before any code. |

## Assumptions (executor; each can be corrected at H-11-0)
- A-01 **Stack** as ADR-0002: React + Vite PWA, one Cloudflare Worker with static assets and D1 on the free plan, Vitest and Playwright.
  One new package, `qrcode-generator`, for the pairing QR (ADR-0008 §11).
- A-02 **Prompt parity** is proven by tests: byte-identical prompts against `packages/contracts/prompts`, and Swift-recorded fixtures
  for every other ported module.
- A-03 **Phone layout** as DESIGN.md §7: one column, bottom navigation, hints as a sheet. DESIGN.md §9 is rebased on the v2 dark tokens
  in the step that builds the shell.
- A-04 **Not ported, Mac-only:** whisper.cpp and the Apple speech engine, the diagnostic command-line modes, the speech recognition
  check window, folder sync and daily folder backups (the web has server sync and ZIP export/import), Premium system voices (the
  browser's voices instead), the Russian interface, the light theme, the reminder, the interface-language and theme settings.
- A-05 **Sessions last 90 days** of inactivity. Longer than the 30 days of ADR-0003, because a friend has no other credential.
- A-06 **Keys are entered on each device.** Pairing a second device does not copy keys: decision 4 keeps them off the server, and a
  device-to-device transfer would be new code. The friend pastes the key again.
- A-07 **Device-local settings stay device-local**, as on the Mac: the provider chain, voice settings and the learner's own scenarios
  are not synced between a friend's devices. Everything in the journal (sessions, vocabulary, cards, memory, goals) is.
- A-08 **Reply options** (decision 8 lists them in the core) exist on the Mac only in the open LINGO-09 PRs #142 and #143, not on
  `main`. They are ported together with the strict tutor (step F-22), or earlier if those PRs are merged before step F-14 starts.
- A-09 **A custom endpoint's key passes through the engine in transit** (never stored, never logged). Decision 4 allows the transit
  proxy; the settings screen says it in one line.
- A-10 **Rate-limit numbers of the provider** may be invisible to the browser (ADR-0008, Consequences). The web then pauses a pool
  from the 429 message or a default, and the Quota screen shows local usage only.
- A-11 **Capacity:** the Cloudflare free plan is enough for about 20 friends; each account may store up to 10 MB of events (a Worker
  variable the admin can raise), and pushes stop for everyone at 350 MB in total, under D1's 500 MB (spec FR-26). The size of the
  owner's Mac history is not known yet; it is measured in step F-12 and the default is corrected if it does not fit.
- A-12 **Supported browsers:** current Safari (iOS, iPadOS, macOS), Chrome (Android, Windows, macOS) and Edge. Firefox works without
  the built-in recognition fallback, which it does not have.
- A-13 **Merge authority** (accepted at H-11-0: CX-02 is extended to the LINGO-11 plan): the executor asks the owner at H-11-0 to extend CX-02 (squash-merge own PRs after green CI and an
  independent AI review without open P0/P1) to the LINGO-11 plan. Without it every PR waits for the owner.
- A-14 **The Mac may change while the port runs** only through fixes. A Mac behaviour change after a module is ported updates the
  fixture and both implementations in one PR.
- A-15 **Every friend can export and import a ZIP**, not only the owner; decision 10 is its first use.
- A-16 **A friend can delete the own account** from Settings (server data and this device's copy). It is not on the Mac; it is here
  because the history now lives on someone else's server.
- A-17 **A device without a valid session keeps nothing.** "Sign out", a session ended from another device, an expired session and
  a blocked account delete the keys and the local history copy from that browser (spec FR-07), because friends may use shared or
  borrowed computers. The history returns from the server at the next sign-in; the keys are typed again; events that a revoked
  device had not sent are lost.
- A-18 **Custom endpoints always use the transit proxy**, also when an endpoint would allow browser calls. Decision 4 names the proxy
  for providers without CORS; using it for every custom endpoint keeps the page's allowed hosts to three fixed providers (ADR-0008
  §7).
- A-19 **Small additions that no decision names:** a friend can rename the account and a device; the friends list also shows the
  creation date and the stored size (decision 11 lists name, last sign-in and device count); the turn metrics can be exported from
  Settings; the admin who lost every device signs in again with a newly set setup secret (spec FR-11).

## Definition of done
Every FAC criterion of [spec.md](spec.md) has evidence (PASS, or NOT RUN with a reason the owner accepted); `swift test`, `npm test`,
`check-english` and `secret-scan` pass; every PR had an independent AI review without open P0/P1; the owner tested the core at H-11-1,
decided the strict tutor order at H-11-2, deployed at H-11-3 and accepted the change at H-11-4; the executor has said in Russian that
the link can be sent to friends.
