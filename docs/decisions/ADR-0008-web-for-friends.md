# ADR-0008: Lingo Web for friends — accounts by invite, keys on the device, logic in the browser

Status: **proposed**, waiting for the owner (H-11-0) · Date: 2026-11-13 · Risk: R3 (real accounts, other people's history and keys)
Context: [LINGO-11 intent](../changes/LINGO-11/intent.md) (owner decisions 1…16 of 2026-11-13) · [LINGO-11 spec](../changes/LINGO-11/spec.md)

When accepted, this ADR **supersedes for Lingo Web and the Lingo Engine**:
- [ADR-0003](ADR-0003-authentication.md) entirely (GitHub OAuth with an allow-list);
- in [ADR-0005](ADR-0005-model-routing-and-quota.md): §2 (server routes per purpose), §4 (reservation) and §5 (day plan and budgets),
  and whatever in §1 and §3 places pools, keys or the Workers AI binding in the engine. What stays: §1 (a pool is one rate-limit
  ceiling), §3 (additional organizations are an owner-risk label), §6 and §7, because the Mac chain implements them and the web
  ports the Mac chain;
- in [ADR-0002](ADR-0002-web-stack.md): from item 1 the Workers AI fallback and the D1 tables for attempts and budgets (the Worker,
  static assets, D1 and the `*.workers.dev` address stay); from item 3 only the i18n part (Russian default UI; React, Vite, PWA and
  the DESIGN.md tokens stay); item 4 entirely (recognition through the engine, Workers AI Whisper, no browser recognition); item 9
  (`/api/turn` SSE from the engine); and the `i18next`, `react-i18next` rows of its allow-list. Everything else in ADR-0002 stays.

The Mac app is not affected. ADR-0003 §5 (device tokens for native clients) returns in LINGO-04 with its own decision.

## Context
- The owner wants friends to test the whole Mac feature set on any device: he sends a link, the friend gets a clean account, adds own
  API keys as in the Mac app, and practises. No new features. He deploys to Cloudflare himself after a locally working version.
- Friends are not GitHub users, and there is no mail sender at $0 (ADR-0003 context), so neither GitHub OAuth nor e-mail codes fit.
- The Mac keeps all logic on the device with the user's own keys. The LINGO-03 design moved prompts, routing and keys to the engine with
  the owner's Groq keys; with friends that would spend the owner's quota and make him hold other people's usage.
- Browser calls to providers were probed on 2026-11-13 without a key
  ([evidence](../changes/LINGO-11/evidence/cors-2026-11-13.txt)): Groq (chat, transcription, models), Mistral and OpenRouter answer the
  preflight and the request with `Access-Control-Allow-Origin: *` and allow the `Authorization` header. The Cloudflare REST API
  (`api.cloudflare.com/client/v4/accounts/…/ai/v1`, the owner's "custom endpoint") answers the preflight with 405 and sends no CORS
  header. No probed response exposes `x-ratelimit-*` or `retry-after` to scripts (checked without a key: 401 responses and one 200
  from OpenRouter's model list; a 200 and a 429 with a real key are checked in plan step F-11).

## Decision
1. **Accounts by invite, no password and no e-mail.** An admin creates an invite; opening the link and pressing one button creates the
   account, the first device and its session. Further devices join with a pairing QR or a short code from Settings. A friend who lost
   every device gets a one-time sign-in link from the admin (24 h).
2. **One mechanism for all three links.** Invite, pairing and sign-in links carry a 256-bit random token in the URL **fragment**
   (never sent to a server by the browser, absent from request logs and `Referer`). The page sends it in a `POST` body only after a
   button press, so link previews cannot use it up. The engine stores only `HMAC-SHA-256(pepper, token)`. Every token is single-use and
   expires (invite 7 days, pairing 10 minutes, sign-in 24 hours); it is consumed by one conditional update, so concurrent requests
   cannot use it twice. The short pairing code (8 characters, 40 bits) is an alias of one pairing record, is stored as an HMAC too
   and has attempt limits. A link is not redeemed on a device that is already signed in, and the page that redeems a link shows
   which account it signed into.
3. **Sessions.** As ADR-0003 §3–4 otherwise: a 256-bit token stored hashed with the pepper, cookie
   `HttpOnly; Secure; SameSite=Lax; Path=/`, an `Origin` check on every state-changing request. The sliding expiry is **90 days**,
   because the session is the friend's only credential. Each session belongs to one device row and can be revoked from Settings.
   A device without a valid session keeps nothing: signing out, a revoked or expired session and a blocked account clear the keys
   and the local history copy from that browser, and local stores are named by the account id.
4. **Admin is a flag on a normal account, and there is exactly one admin.** It is created once with a setup secret that the owner puts into the Worker
   (`wrangler secret put`) and types into the setup page himself; the owner then deletes the secret, and the endpoint answers 404 without it. Setting a
   new secret later lets the same admin sign in again after losing every device; it never creates a second account. The admin API has no
   operation that returns another account's events or settings.
5. **API keys live only in the friend's browser** (IndexedDB of that device). The engine has no provider keys, no table and no
   endpoint for them; keys are in no event, export or log.
6. **Logic runs in the browser.** Prompt building, context policy, the provider chain with fallback and pools, key checks, the dialogue
   engine, the turn state machine, the teacher, exams, Goethe and later the strict tutor are TypeScript ports of `LingoCore` in
   `packages/core-ts`, proven against Swift-recorded fixtures and the prompt snapshots (ADR-0004). The engine builds no prompt and calls
   no model.
7. **Provider calls go straight from the browser** to Groq, Mistral and OpenRouter. A **custom OpenAI-compatible endpoint always goes
   through a stateless transit proxy** of the engine (`/api/relay`): signed-in accounts only, HTTPS only, a fixed set of path suffixes,
   no IP-literal or local hosts, no user name, query or other port in the address, body and rate limits, only JSON or event-stream
   answers, nothing stored, key and body never logged, off in local development unless switched on. The Content-Security-Policy can
   therefore name three provider hosts and nothing else.
8. **Recognition: Groq Whisper with the friend's Groq key**, called from the browser. Fallback: the browser's built-in recognition in
   the study language where the browser has it. Audio is never sent to the engine.
9. **The engine is small:** accounts, invites, devices and sessions, the admin API, event sync (journal schema v1, plaintext in D1, one
   cursor per account), the transit proxy and the static site. No turns, attempts, leases, budgets or ledger tables.
10. **Interface:** English only and dark theme only for this change; no i18n library. Tutor explanations and translations stay Russian
    because the prompts are unchanged.
11. **Allow-list change (ADR-0002 table):** add `qrcode-generator` (web; draws the pairing QR; MIT, no dependencies, npm 2.0.4 checked
    2026-11-13). Only its module matrix is used; the QR is drawn as SVG elements by the app, because the package's own helpers
    produce HTML strings and data URLs, which the CSP and the no-raw-HTML rule exclude. `i18next` and `react-i18next` are not used
    by LINGO-11. ZIP export and import use the browser's `CompressionStream` /
    `DecompressionStream` and a small own reader, no package. Event validation in the engine uses the strict reader of `core-ts`, not
    `ajv` at run time (ajv compiles validators with code generation; whether the Workers runtime allows that is not verified, so the
    engine does not depend on it).

## Alternatives considered
| Option | Why not |
|---|---|
| Keep GitHub OAuth, add friends' ids to the allow-list (ADR-0003 §6) | friends need a GitHub account; the owner asked for "a link and it works" |
| Password or e-mail code | a password must be stored and protected against guessing; e-mail needs a sender and a domain ($0 rule) |
| Passkeys | declined by the owner earlier (ADR-0003); account recovery would still need the admin link |
| Keys on the server, encrypted per account | the owner decided keys never rest on the server; a leak of D1 plus the secret would expose every friend's key |
| Engine builds prompts and calls models (LINGO-03 design) | spends the server's limits for everyone, needs the ledger and budgets, and forks the logic away from the Mac |
| Every provider call through the proxy | adds a hop to each token stream and puts every key in transit through the Worker; unnecessary where the provider allows CORS |
| Custom endpoints called directly | the owner's own custom endpoint has no CORS; arbitrary hosts in `connect-src` would defeat the CSP |
| End-to-end encrypted history | the owner chose plaintext on the server and less code (decision 3) |

## Consequences
- **Script injection is the main threat**, because keys are readable by the page's scripts. Measures are requirements, not advice: a
  strict CSP without inline scripts, no third-party script, font or analytics, allow-listed dependencies only, React's escaping with no
  raw HTML insertion, and a CI scan of the built bundle (spec FR-55…FR-61).
- **A custom-endpoint key passes through the Worker in transit.** It is never stored or logged by the engine, and platform logging
  is kept off (whether Cloudflare's own logs can show header values is not documented and is tested in plan step F-4), but the
  engine's operator could in principle read it; the settings screen says so in one line next to the custom endpoint.
- **Rate-limit headers are probably unreadable on direct calls.** Cooldowns then come from the 429 body text (as Swift
  `RateLimitKind` / `tryAgainSeconds` already does) or a default pause, and the Quota screen shows the locally counted usage without
  the provider's "remaining" numbers. This is a known parity gap, confirmed or lifted in F-11.
- **Keys are entered on every device** and can disappear when the browser evicts site storage (Safari is known to clear script-written
  storage of sites that are not used for a while; to be observed on the owner's phones at H-11-1). History is safe on the server; the
  app asks for the key again. Installing the PWA to the home screen is recommended in onboarding.
- **Plaintext history in D1.** The admin UI shows no conversations, but whoever holds the Cloudflare account can read the database.
  The owner accepted this (decision 3); it is stated once in the deploy guide, not in the UI.
- **Losing every device needs the admin.** There is no self-service recovery.
- **The owner's quota is not shared.** Each friend's requests count against the friend's own provider account; the multi-account risk
  of ADR-0005 §3 stays the personal choice of whoever adds a second organization.
- **Two implementations of the whole core** (Swift and TypeScript). Every ported module gets a Swift-recorded fixture first; a Mac
  behaviour change after the port must update the fixture and both sides in one PR (AGENTS.md §6.9). This is the main cost of the
  decision and the reason the plan ports in small, fixture-backed steps.
- The LINGO-03 engine contract (`packages/contracts/api/openapi.yaml`) is replaced as a whole in plan step F-1: `/auth/*`,
  `/api/turn…`, `/api/transcribe`, `/api/lease` and `/api/budget` go; `/api/me`, `/api/sync`, `/api/export` and `/api/account/data`
  are redefined for accounts by invite. Nothing implements it today.
- **Free-plan numbers** behind the limits of the spec were read from Cloudflare's documentation on 2026-11-13: D1 500 MB per
  database, 100 000 rows written and 5 million read per day (an index adds a written row), 50 queries per Worker request with
  `batch()` counted as one, 100 bound parameters per statement, 7 days of point-in-time restore; Workers 100 000 requests per day,
  10 ms CPU and 50 subrequests per request. Not stated there, and therefore tested instead of assumed: header values in platform
  logs, what `fetch` reaches from a Worker, and rate-limit rules for `*.workers.dev`.
