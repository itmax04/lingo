# ADR-0003: Sign-in for Lingo Web — GitHub OAuth with an allow-list

Status: **accepted** (owner, 2026-10-26) · Context: [ARCHITECTURE §8](../architecture/ARCHITECTURE.md#8-security-and-privacy)

> **LINGO-11 notice (2026-11-13).** [ADR-0008](../decisions/ADR-0008-web-for-friends.md) is **proposed** and waits for the owner (H-11-0). When accepted it replaces this ADR for Lingo Web and the engine: accounts by invite link instead of GitHub OAuth. §5 (device tokens for native clients) is decided again in LINGO-04. See the [LINGO-11 spec](../changes/LINGO-11/spec.md).

## Context
- One owner today (GitHub `itmax04`), friends possibly later. The site and API are on the public internet.
- **Cloudflare Access** was the first idea, but onboarding Zero Trust asks for payment details even on the free plan (official setup guide, checked 2026-10-26) — conflicts with "no card".
- Email one-time codes need a mail sender and a domain — not available for free without a domain.
- The owner explicitly declined passkeys and chose "Sign in with GitHub" (brainstorm 2026-10-26). It works on every device, including other people's computers.

## Decision
1. **GitHub OAuth App** (created by the owner at github.com → Settings → Developer settings → OAuth Apps; free, no card).
   - Callback: `https://<worker>.workers.dev/auth/callback` (plus `http://localhost:8787/auth/callback` in a separate dev OAuth App).
   - Scope: **none** (identity only). The engine calls `https://api.github.com/user` once to read the numeric `id` and `login`.
   - The client id is a Worker var; the client secret is a Worker secret (`GITHUB_CLIENT_SECRET`, entered by the owner with `wrangler secret put`).
2. **Allow-list by numeric GitHub user id** (`ALLOWED_GITHUB_IDS`, comma-separated Worker var). Logins can change; ids do not. Not allow-listed → 403, no account row.
3. **Sessions:** 256-bit random token; only its SHA-256 (with a pepper secret) is stored in D1 `auth_sessions`; cookie `lingo_session` — `HttpOnly; Secure; SameSite=Lax; Path=/`; 30-day sliding expiry; "Sign out" and "Sign out everywhere" in Settings.
4. **CSRF:** OAuth `state` in a short-lived signed cookie; every state-changing API request must have `Origin` equal to the site origin.
5. **Native clients (LINGO-04):** device tokens created in Settings (shown once, stored hashed, revocable, scope: sync + turn).
6. **Friends later:** add their GitHub ids to the allow-list; per-account budgets already exist in the data model.

## Alternatives considered
| Option | Why not now |
|---|---|
| Cloudflare Access (OTP to email) | requires a card at Zero Trust onboarding |
| Passkeys (WebAuthn) | declined by the owner |
| Email magic link | needs a mail provider and a domain |
| Password | must be remembered and typed on every device; brute-force protection needed — kept as an emergency fallback idea only |
| Google OAuth | equivalent; the owner chose GitHub |

## Consequences
- Signing in on a new device needs the GitHub login (GitHub's own 2FA protects the account).
- A GitHub outage blocks new sign-ins; existing sessions keep working.
- No third-party auth library; the flow is ~150 lines in the engine with tests for: forged cookie, missing state, wrong origin, non-allow-listed id, expired session.
