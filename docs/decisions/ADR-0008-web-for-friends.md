# ADR-0008: Lingo Web for friends — accounts by invite, keys on the device, logic in the browser

Status: **proposed**, waiting for the owner (H-11-0) · Date: 2026-11-13 · Risk: R3 (real accounts, other people's history and keys)
Context: [LINGO-11 intent](../changes/LINGO-11/intent.md) (owner decisions 1…16 of 2026-11-13) · [LINGO-11 spec](../changes/LINGO-11/spec.md)

When accepted, this ADR **supersedes for Lingo Web and the Lingo Engine**:
- [ADR-0003](ADR-0003-authentication.md) entirely (GitHub OAuth with an allow-list);
- [ADR-0005](ADR-0005-model-routing-and-quota.md) §2…§5 as far as they describe the engine (server routes, reservations, day plan,
  Workers AI binding). §1 (a pool is one rate-limit ceiling), §3 (owner-risk organizations, as a label), §6 and §7 stay, because the Mac
  chain implements them and the web ports the Mac chain;
- [ADR-0002](ADR-0002-web-stack.md) items 3 (Russian default UI, i18n), 4 (recognition through the engine, no browser recognition) and
  9 (`/api/turn` SSE from the engine), and the `i18next`, `react-i18next` rows of its allow-list. Everything else in ADR-0002 stays.

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
  header. No probed response exposes `x-ratelimit-*` or `retry-after` to scripts (checked on 401 responses only; a 200 and a 429 with a
  real key are checked in plan step F-11).

## Decision
1. **Accounts by invite, no password and no e-mail.** An admin creates an invite; opening the link and pressing one button creates the
   account, the first device and its session. Further devices join with a pairing QR or a short code from Settings. A friend who lost
   every device gets a one-time sign-in link from the admin (24 h).
2. **One mechanism for all three links.** Invite, pairing and sign-in links carry a 256-bit random token in the URL **fragment**
   (never sent to a server by the browser, absent from request logs and `Referer`). The page sends it in a `POST` body only after a
   button press, so link previews cannot use it up. The engine stores only `HMAC-SHA-256(pepper, token)`. Every token is single-use and
   expires (invite 7 days, pairing 10 minutes, sign-in 24 hours). The short pairing code (8 characters, 40 bits) is an alias of one
   pairing record and has attempt limits.
3. **Sessions.** As ADR-0003 §3–4 otherwise: a 256-bit token stored hashed with the pepper, cookie
   `HttpOnly; Secure; SameSite=Lax; Path=/`, an `Origin` check on every state-changing request. The sliding expiry is **90 days**,
   because the session is the friend's only credential. Each session belongs to one device row and can be revoked from Settings.
4. **Admin is a flag on a normal account.** The first admin is created once with a setup secret that the owner puts into the Worker
   (`wrangler secret put`) and types into the setup page himself; the endpoint is dead as soon as an admin exists. The admin API has no
   operation that returns another account's events or settings.
5. **API keys live only in the friend's browser** (IndexedDB of that device). The engine has no provider keys, no table and no
   endpoint for them; keys are in no event, export or log.
6. **Logic runs in the browser.** Prompt building, context policy, the provider chain with fallback and pools, key checks, the dialogue
   engine, the turn state machine, the teacher, exams, Goethe and later the strict tutor are TypeScript ports of `LingoCore` in
   `packages/core-ts`, proven against Swift-recorded fixtures and the prompt snapshots (ADR-0004). The engine builds no prompt and calls
   no model.
7. **Provider calls go straight from the browser** to Groq, Mistral and OpenRouter. A **custom OpenAI-compatible endpoint always goes
   through a stateless transit proxy** of the engine (`/api/relay`): signed-in accounts only, HTTPS only, a fixed set of path suffixes,
   no IP-literal or local hosts, body and rate limits, nothing stored, key and body never logged. The Content-Security-Policy can
   therefore name three provider hosts and nothing else.
8. **Recognition: Groq Whisper with the friend's Groq key**, called from the browser. Fallback: the browser's built-in recognition in
   the study language where the browser has it. Audio is never sent to the engine.
9. **The engine is small:** accounts, invites, devices and sessions, the admin API, event sync (journal schema v1, plaintext in D1, one
   cursor per account), the transit proxy and the static site. No turns, attempts, leases, budgets or ledger tables.
10. **Interface:** English only and dark theme only for this change; no i18n library. Tutor explanations and translations stay Russian
    because the prompts are unchanged.
11. **Allow-list change (ADR-0002 table):** add `qrcode-generator` (web; draws the pairing QR; MIT, no dependencies, npm 2.0.4 checked
    2026-11-13). `i18next` and `react-i18next` are not used by LINGO-11. ZIP export and import use the browser's `CompressionStream` /
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
- **A custom-endpoint key passes through the Worker in transit.** It is never stored or logged, but the engine's operator could in
  principle read it; the settings screen says so in one line next to the custom endpoint.
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
- The LINGO-03 engine contract (`packages/contracts/api/openapi.yaml`: `/auth/*`, `/api/turn`, `/api/transcribe`, `/api/lease`,
  `/api/budget`) is replaced in plan step F-1. Nothing implements it today.
