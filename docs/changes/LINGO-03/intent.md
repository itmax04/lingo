# LINGO-03: Intent — Lingo Web with accounts

ID: LINGO-03-intent · Status: **draft** (awaiting the owner's acceptance) · Version: 1 · Date: 2026-10-26
Result owner: itmax04 · Links: [spec.md](spec.md), [plan.md](plan.md), [ADR-0002](../../decisions/ADR-0002-web-stack.md),
[LINGO-01 intent](../LINGO-01/intent.md), [DESIGN.md](../../../DESIGN.md)
Source of decisions: the conversation of 2026-10-26, answers W1–W5 (table below); the owner's quotes are translated from Russian.

## Problem
Lingo works only on the owner's Mac (LINGO-01). The owner wants to practise on **any device** — iPhone, iPad, another computer —
and to **log in with an account** so that the history is the same everywhere.
The native iPhone path (LINGO-02) depends on SideStore and a free Apple ID: the signature expires every 7 days, setup needs a computer,
and SideStore support for iOS 27 is unverified. A website has none of these problems.

## Desired outcome
**Lingo Web**: a web app (installable as a PWA) for voice conversation practice in English and German, with the same behaviour as the Mac app:
1. the owner logs in with their email and sees all their sessions on any device;
2. speaks, and the assistant answers by voice; push-to-talk and a continuous dialogue with barge-in;
3. Russian only on an explicit request; commands "repeat", "slower", "how do I say", "explain", "let's continue";
4. correction modes (as we go, after the conversation, on request), hints and a starred vocabulary;
5. a few friends invited by the owner get their own accounts with separate histories;
6. everything stays free.

Voice pipeline on the web: browser microphone (echo cancellation) → utterance detection in the browser → speech recognition by **Groq Whisper in the cloud**
→ the LLM chain on the server → speech synthesis by the device's own voices (Premium voices on Apple devices).

## Users and systems
- **Users:** the owner and up to a few invited friends (W1). Each has an account and a separate history. No public sign-up.
- **Devices:** any modern browser — Safari on iPhone and iPad, Safari and Chrome on the Mac, browsers on other computers.
- **Systems:**
  - Cloudflare (the owner's existing account): Workers (API and static site), D1 (database), Access (login, Zero Trust free plan), Workers AI (fallback model);
  - Groq API (free tier, the owner's keys): chat models and Whisper speech recognition;
  - GitHub `itmax04/lingo` (private), branch `main-en`.
- **Reuse:** the Lingo design (DESIGN.md), the reply protocol, prompts, command vocabularies, correction logic, the event journal format
  and the merge rules of LINGO-01 are ported to TypeScript and checked against the same fixtures (prompt snapshots, eval sets).

## Scope
In LINGO-03:
- a server on Cloudflare Workers: login check, accounts, history sync, the LLM chain and the speech-recognition proxy with keys kept on the server, per-account daily quotas, a usage log;
- a web client (PWA) following DESIGN.md: three columns on wide screens (Mac, iPad landscape), one column on a phone; sessions, voice, commands, corrections, hints, vocabulary, settings;
- history stored in the browser (works offline for reading) and synced through the account;
- a sync API that the Mac app can use later (the Mac client itself is optional in this change, see plan P-11).

Not in LINGO-03:
- public sign-up and use by strangers (W1) — a separate change if ever needed;
- a native iPhone/iPad app (LINGO-02 stays parked);
- voice with a locked screen (browsers stop audio) — a known limitation of the web;
- pronunciation assessment in any form (Q7 stays);
- paid plans of any provider.

## Constraints
- **Budget:** $0 — Cloudflare free plan, Groq free tier, a free `*.workers.dev` address. If a limit would require paying, the feature degrades instead.
- **Audio:** for the web, recorded utterances are sent to Groq for recognition (W2). This **changes R-08 for the web client only**: audio leaves the device, is not stored by Lingo, and is never written to the server's database. The Mac app keeps on-device recognition.
- **Keys:** model keys exist only as Cloudflare Worker secrets. They never reach the browser, the repository, logs or chat. The owner enters them in the terminal (`wrangler secret put`), not in chat.
- **Shared quota:** all accounts share the owner's free Groq quota (per organization: chat models per model; Whisper ≈2000 requests and 28,800 audio seconds per day, every clip counted as at least 10 s). Each account gets a daily budget; the owner's account comes first.
- **Login:** Cloudflare Access with a one-time PIN sent to an allowed email address; the allow-list is managed by the owner.
- **Privacy:** friends' dialogues are stored in the owner's Cloudflare account. A short privacy note in the app explains what is stored and how to delete it; an account can delete all its data.
- **Latency:** as in LINGO-01 — quality first, up to 8–10 s from the end of an utterance to the start of the reply is acceptable (Q3).
- **Browsers:** iOS Safari limits audio (playback needs a user gesture, the mic and speech synthesis share one audio session). Whether barge-in works on the iPhone is checked first (plan P-01) before the rest is built.
- **Git:** branch `main-en`, no force-push, no merge into `main` without the owner. The repository and docs are in English (Q30).
- **Executor:** Claude Code; questions to the owner only at checkpoints H-0…H-3 of plan.md.

## Owner decisions (2026-10-26)
| # | Question | Decision |
|---|---|---|
| W1 | Who uses the site | "Only me and people I know": login through Cloudflare Access (up to 50 people for free), the owner's keys on the server; can be opened to everyone later |
| W2 | Speech recognition on the web | Groq Whisper in the cloud (the same whisper family as on the Mac; audio goes to Groq) |
| W3 | Order of work | Switch to the website now; LINGO-01 is frozen in its current state (AC-17, H-3…H-5 postponed) |
| W4 | Why not React Native | React Native would still need iOS signing (the same 7-day problem) and a rewrite of the core; a website removes installation entirely (executor's recommendation, the owner chose the website) |
| W5 | Accounts | "I want to create an account so I can sync with any app": history is tied to an account, not to an iCloud folder |

## Assumptions (non-blocking; can be corrected at acceptance)
- **B-1.** The site lives at a free `*.workers.dev` address under the owner's Cloudflare account; a custom domain is optional and out of scope.
- **B-2.** The interface language is Russian by default with English available (the same String-catalog approach as the Mac app).
- **B-3.** Friends use the same models through the owner's keys; the daily budget per friend is small by default (proposed: 60 chat turns and 30 minutes of recognized audio) and the owner can change it.
- **B-4.** The web client stores the history in IndexedDB and works offline for reading; new turns need the network.
- **B-5.** The frontend is React + TypeScript built with Vite (ADR-0002); the owner's frontend rules apply (DESIGN.md first; components checked against 21st.dev and component.gallery when their tools are available).
- **B-6.** The event format of LINGO-01 (R-34…R-39) is reused unchanged, so the Mac app can join the same account later without migration.

## Open questions (answered by the plan's measurements)
- Does barge-in work on iOS Safari with echo cancellation and speech synthesis at the same time? (P-01, H-1)
- Are Groq Whisper latency and quality with the owner's accent good enough on the web (median ≤ 2 s per utterance)? (P-01, P-06)
- Which device voices does each browser expose (Premium voices in Safari, none in some browsers)? (P-01)
