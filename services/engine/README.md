# Lingo Engine

Cloudflare Worker + D1 for Lingo Web (LINGO-11, [ADR-0008](../../docs/decisions/ADR-0008-web-for-friends.md)): accounts by invite,
sessions, later sync, admin and the relay. It builds no prompt, calls no model and holds no provider key.
Contract: [`packages/contracts/api/openapi.yaml`](../../packages/contracts/api/openapi.yaml) — changed before the code.

| Command (in `services/engine`) | What |
|---|---|
| `npm test` | type check and the tests in the Workers runtime with a local D1 |
| `npm run smoke` | starts `wrangler dev` on a throw-away database and checks the security headers on static files and API answers, then setup → cookie → me |
| `npm run dev:init` | once: writes the git-ignored `.dev.vars` (generated pepper and setup secret, `DEV_MODE=1`) and creates the local database in `.wrangler/` |
| `npx wrangler dev` | the site and the engine on `http://localhost:8787`; the setup secret for `/api/setup` is the `SETUP_SECRET` line of `.dev.vars` |

Layout: `src/index.ts` (entry: the handler only), `src/app.ts` (routing, `Origin` and JSON checks, log line), `src/http.ts`
(security headers, error codes), `src/env.ts` (bindings and switches), `src/routes.ts` (the API table), `src/auth.ts` (setup, join,
me), `src/session.ts` (cookie, session check, sliding expiry), `src/attempts.ts` (failure counters), `src/crypto.ts` (tokens,
HMAC, constant-time comparison), `migrations/`, `test/`.

Rules
- Secrets (`PEPPER`, `SETUP_SECRET`) are entered by the owner as Worker secrets (deploy guide, RELEASE.md); local values live in
  the git-ignored `.dev.vars`. A secret shorter than 43 characters (32 random bytes, base64url) counts as missing.
- `wrangler.jsonc` is the production configuration: it never sets `DEV_MODE`, keeps `observability` off and names the two off
  switches `INVITES_ENABLED` and `RELAY_ENABLED` (any value other than `1` is off).
- Static files are served by the platform, not by the Worker: their headers are in `apps/web/public/_headers` and must equal
  `SECURITY_HEADERS` in `src/http.ts` (a test compares them).
- Tokens are 32 random bytes; the database holds only `HMAC-SHA-256(pepper, token)`. Changing the pepper signs every device out.
- `DEV_MODE=1` drops `Secure` and the `__Host-` prefix of the session cookie, and only for requests to `http://localhost` or
  `http://127.0.0.1`.
- Logs hold request id, route, status, duration and account id only (spec FR-59).
