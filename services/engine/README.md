# Lingo Engine

Cloudflare Worker + D1 for Lingo Web (LINGO-11, [ADR-0008](../../docs/decisions/ADR-0008-web-for-friends.md)): accounts by invite,
sessions, later sync, admin and the relay. It builds no prompt, calls no model and holds no provider key.
Contract: [`packages/contracts/api/openapi.yaml`](../../packages/contracts/api/openapi.yaml) — changed before the code.

| Command (in `services/engine`) | What |
|---|---|
| `npm test` | type check and the tests in the Workers runtime with a local D1 |
| `npm run smoke` | starts `wrangler dev` on a throw-away database and checks the security headers on static files and API answers, then setup → cookie → me → pairing by code → devices → sign-out → invite → join → sign-in link → block → unblock → delete |
| `npm run dev:init` | once: writes the git-ignored `.dev.vars` (generated pepper and setup secret, `DEV_MODE=1`) and creates the local database in `.wrangler/` |
| `npx wrangler dev` | the site and the engine on `http://localhost:8787`; the setup secret for `/api/setup` is the `SETUP_SECRET` line of `.dev.vars` |

Layout: `src/index.ts` (entry: the handler only), `src/app.ts` (routing, `Origin` and JSON checks, log line), `src/http.ts`
(security headers, error codes), `src/env.ts` (bindings and switches), `src/routes.ts` (the API table), `src/auth.ts` (setup, join,
me, redeeming a pairing link or code and a sign-in link), `src/devices.ts` (pairing record, devices list, rename, sign-out), `src/admin.ts` (invites, accounts list, sign-in link, block, unblock, delete — admin only), `src/account.ts` (own account: rename, delete), `src/session.ts` (cookie, session check, sliding expiry), `src/attempts.ts` (failure counters, the atomic typed-code limit), `src/crypto.ts` (tokens,
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
- Signing a device out deletes its row; the session goes with it. Expired links and devices with an ended session are removed
  when an account creates a pairing record.
- Typed pairing codes (40 bits) are counted before they are looked at, by one conditional statement (`reserveCodeAttempt`);
  link tokens (256 bits) are counted after a failure. Client buckets in `attempts` are keyed hashes, never addresses.
- Rules that span tables are triggers in `migrations/0002_guards.sql`: a session belongs to its device's account, the admin
  flag never changes, the admin is never blocked.
- Every `/api/admin/` handler starts with `requireAdmin`: a signed-in account that is not the admin gets 404, like an unknown
  path, before the body is looked at. The admin API returns account rows only — never events, settings or session data.
- The admin account is never blocked or deleted: the statements carry `is_admin = 0` (403 `admin_protected`); migration 0002
  refuses blocking, nothing in the database refuses deleting. Deleting an account needs its current name in the body and
  cascades to its sessions, devices, events and links.
- A sign-in link (24 hours) is made for an active account only and replaces that account's previous unused one. Blocking
  an account and "Sign out everywhere else" remove its unused pairing record and sign-in link.
- An invite's id is the first 32 hex characters of its token's HMAC; the invite list holds unused, unexpired invites only.
- Logs hold request id, route, status, duration and account id only (spec FR-59).
