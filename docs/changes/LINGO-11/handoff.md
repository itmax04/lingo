# LINGO-11: Handoff — Lingo Web for friends

Status: **stage A (engine) in progress: F-1 merged, F-2a built (PR #153 open), F-2b built (review running, no PR yet)** · Date: 2026-11-14

## Identity
- Change LINGO-11, risk R3. Documents: [intent](intent.md), [spec](spec.md), [plan](plan.md),
  [ADR-0008](../../decisions/ADR-0008-web-for-friends.md) (accepted at H-11-0).
- Documents: PR #146 (merged by the owner). Stage A: milestone "LINGO-11 · A Engine" (#9), issues #147 (F-1), #148 (F-2),
  #149 (F-3), #150 (F-4). Milestones and issues of stages B…H are created when their stage starts.
- F-1 worktree `.claude/worktrees/lingo-11-f1-engine-cc30f9`: branch `feat/147-engine-skeleton` (F-1a) from `origin/main`
  `46bfe4e`; F-1b is stacked on it as `feat/147-engine-auth`.
- F-2 uses the same worktree: branch `feat/148-engine-pairing` (F-2a) from `origin/main` `1fed4e1`; F-2b is stacked on it as
  `feat/148-engine-admin`.

## State
- The owner's goal and decisions 1…16 (brainstorm 2026-11-13) are in `intent.md`. New features are paused; LINGO-09 on the Mac is
  paused with its PRs #119 and #141–#145 open and untouched.
- The web part of LINGO-03 is superseded by this change: P-07c2 and P-08…P-20. Issues #10…#27 and draft PR #62 were commented
  "superseded by LINGO-11 (H-11-0)" and closed as not planned on 2026-11-13; no branch was deleted.
- `packages/core-ts` on `main` has: events (codec, ULID, reducer), reply protocol parser, command detector, VAD and segmenter, model
  decoders. `services/engine` exists since F-1a; `apps/web` is an empty shell (`public/` with `_headers` and a placeholder page)
  until F-9.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Stage 0: documents | #146 | see "Checks" below | intent, spec (FR-01…FR-67, FAC-01…FAC-22), plan (F-1…F-24, H-11-0…H-11-4), ADR-0008, CORS evidence; notes in WEB.md, ARCHITECTURE.md, CODEBASE.md, docs/README.md, ADR-0002/0003/0005, AGENTS.md, ROADMAP, completion plan, LINGO-03 handoff |
| F-1a: engine foundation (#147, part 1 of 2) | this PR | see "Checks (F-1a)" | workspaces `services/engine`, `apps/web` (shell); OpenAPI v2 (setup, join, me) replacing the LINGO-03 contract; Worker shell (routing, typed errors, `Origin` and JSON checks, log line, security headers); `_headers`; migration 0001; the two switches as variables; CI steps |
| F-1b: engine auth (#147, part 2 of 2) | this PR (stacked on F-1a) | see "Checks (F-1b)" | link and session tokens as HMACs; session cookie with sliding expiry; attempt counters; `/api/setup` (first admin and recovery), `/api/join` (atomic invite redemption), `/api/me`; the invites switch; `npm run dev:init`; the smoke run walks setup → cookie → me |
| F-2a: pairing, limits, devices (#148, part 1 of 2) | #153 | see "Checks (F-2a)" | contract first; `/api/pairings`, `/api/pair` (link and typed code), the atomic typed-code limit, `/api/devices`, rename, sign-out (one, others, this device); migration 0002 (triggers); hashed attempt buckets; cleanup of expired links; review items R5, R8, R9, B2/N1 |
| F-2b: admin and own account (#148, part 2 of 2) | PR from `feat/148-engine-admin`, stacked on #153 | see "Checks (F-2b)" | contract first; `/api/sign-in`; `src/admin.ts` (invites create/list/revoke, accounts list with total size, sign-in link, block, unblock, delete with typed name); `src/account.ts` (own rename, delete); N3 and N6 decided; `test/admin.test.ts` (23 tests); smoke extended; review notes of F-2b fixed or answered |

## Split of F-2 (plan "Size" rule)
- **F-2a — devices**: FR-05, FR-06, FR-07 (engine part); FAC-02 and the devices part of FAC-03; the open review items of F-1.
- **F-2b — admin and own account**: sign-in link (FR-08, reusing `redeemForAccount` in `src/auth.ts` with kind `signin`), admin
  API (FR-09, FR-12, FR-13: invites, friends, block, unblock, delete), own-account rename and delete (FR-10); FAC-04. Both
  parts keep the tier (strong). Each part changes `openapi.yaml` for its own paths: a test now requires the route table and
  the file to list the same operations.

## Split of F-1 (plan "Size" rule)
- **F-1a — foundation**: OpenAPI v2, workspaces, Worker shell, security headers and `_headers`, migration 0001, CI. No route yet:
  `src/routes.ts` is empty, the shell is tested with a test route table.
- **F-1b — auth**: HMAC tokens, sessions and cookie, attempt counters, `/api/setup`, `/api/join`, `/api/me`, the invites switch,
  the local development secrets file. Both parts keep the tier (strong) and the checks of F-1.

## Facts found in stage 0
- **Provider CORS** ([evidence](evidence/cors-2026-11-13.txt), curl without a key, 2026-11-13 17:16 UTC):
  | Endpoint | Preflight | Request without key | Browser can call directly |
  |---|---|---|---|
  | Groq `/openai/v1/chat/completions`, `/audio/transcriptions`, `/models` | 204, `allow-origin: *`, `allow-headers: authorization,content-type` | 401 with `allow-origin: *` | yes |
  | Mistral `/v1/chat/completions`, `/models` | 200, `allow-origin: *`, `Authorization` allowed | 401 with `allow-origin: *` | yes |
  | OpenRouter `/api/v1/chat/completions`, `/models` | 204, `allow-origin: *`, `Authorization` allowed | 401 / 200 with `allow-origin: *` | yes |
  | Cloudflare REST `/client/v4/accounts/…/ai/v1/chat/completions` | 405, no CORS header | 401, no CORS header | **no** → relay |
  Not verified: a 200 and a 429 with a real key (same headers expected, checked in F-11). No response listed `x-ratelimit-*` or
  `retry-after` in `access-control-expose-headers`, so the browser probably cannot read them (spec FR-19).
- `qrcode-generator` on npm: version 2.0.4, MIT, no dependencies (`npm view`, 2026-11-13).
- Reply options (LINGO-09 MR-49…MR-54) are only in the open PRs #142 and #143, not on `main` (intent A-08).
- ADR numbers: 0006 was never used (checked on `main` and on every remote branch); this ADR takes the number after the highest
  existing one (0007) and leaves 0006 unassigned, so that no number is ever given out of order.
- **Cloudflare free plan**, read from Cloudflare's documentation on 2026-11-13 (D1 limits and pricing, Workers limits, Workers Logs,
  static-asset headers, rate-limiting rules): D1 500 MB per database, 100 000 rows written and 5 million read per day, an index
  adds a written row, 50 queries per Worker request (`batch()` counts as one), 100 bound parameters per statement, 2 MB per row,
  7 days of point-in-time restore; Workers 100 000 requests per day, 10 ms CPU, 50 subrequests per request; headers of static
  files come from a `_headers` file. **Not stated in the documentation** (tested in F-1, F-4 and at H-11-3 instead of assumed):
  whether Workers Logs are on by default (the page contradicts itself), whether platform logs show header values, what a Worker's
  `fetch` can reach, whether static-file requests count against the daily requests, and whether the free rate-limit rule works on
  `*.workers.dev`.
- The Mac has no Groq transcription request (`audio/transcriptions` does not occur in `apps/mac/Sources`): the web's Groq Whisper
  call is new code (spec FR-32).
- The size of the owner's Mac journal was **not measured** (owner data); it is measured in step F-12 (spec FR-26).

## Executor decisions
- D-01: requirement prefix `FR` / `FAC`, plan steps `F-xx`, checkpoints `H-11-x`.
- D-02: the spec does not restate Mac behaviour. Parity is made testable by the inventory `parity.md` (FR-41, step F-5) instead of a
  second copy of 300 Mac requirements.
- D-03: custom endpoints always use the relay, even when an endpoint would allow CORS, so that the CSP names three hosts only
  (intent A-18, for the owner to confirm).
- D-04: no `ajv` at run time in the engine and no ZIP package; see ADR-0008 §11.
- D-05: documents of other changes are annotated, not rewritten: WEB.md and ARCHITECTURE.md keep the LINGO-03 design under a notice
  until step F-23 rewrites them from the built state.
- D-06 (F-1a): errors are `{code, message}` with the code list in `openapi.yaml`; a test keeps the engine's list and the file's
  list equal. State-changing = `POST`; the engine has no `PUT`/`PATCH`/`DELETE` and answers 405 to them and to `OPTIONS` (no CORS).
- D-07 (F-1a): the pepper and the setup secret count as missing below 43 characters (32 bytes in base64url); a missing or short
  pepper answers 500 `engine_misconfigured` on every route.
- D-08 (F-1a): both switches are fail-closed: only the value `1` switches invites or the relay on.
- D-09 (F-1a): the CSP is `default-src 'none'` plus `'self'` for scripts, styles, images, fonts, manifest and workers, the three
  provider hosts in `connect-src`, `base-uri 'none'`, `form-action 'none'`, `frame-ancestors 'none'`. Inline `style` attributes are
  therefore blocked; F-9 styles through classes and CSS variables, or amends the policy in `http.ts` and `_headers` together.
- D-10 (F-1a): until F-9 the Worker's static directory is `apps/web/public`; F-9 points it at the built site.
- D-11 (F-1a): `events.seq` is a plain rowid without `AUTOINCREMENT`: a new row always gets a value above every existing one, and
  an account's cursor never exceeds its own highest row, so reuse after a deletion cannot hide an event. F-3 confirms it.
- D-12 (F-1a): `@cloudflare/vitest-pool-workers` 0.23.0 (the ADR-0002 allow-list name) is kept although npm marks it as renamed
  to `@cloudflare/vitest-plugin`; moving needs an allow-list entry first. It needs vitest 4.1, so the engine uses 4.1.12 and
  `core-ts` stays on 5.0.5.
- D-13 (F-1a): a smoke script (`npm run smoke -w services/engine`) starts `wrangler dev` in CI: unit tests call the handler
  directly and cannot see that the entry module loads in the real runtime or that the platform applies `_headers` to static files.
- D-14 (F-1b): account and device ids are random UUIDs. Display names are trimmed and counted in characters (1–40), as SQLite's
  `length()` counts them; control characters (C0, DEL, C1) and bidirectional overrides are refused with 400 (review B1).
- D-15 (F-1b): the common refusal of a link is 410 `link_invalid`; over the client limit it is the same body with status 429.
  `/api/setup` is not a link and answers 403 `secret_invalid`, and 429 `too_many_attempts` over a limit. The global setup limit is
  20 failures in 10 minutes. A request without the secret or the token field is 400 and is not counted as a guess.
- D-16 (F-1b): limits look at the current and the previous 10-minute window, so sequential attempts never put more than the
  limit into 10 minutes; the price is that a client at the limit waits up to 20 minutes. The check reads before the failure is
  written, so a burst of parallel requests can pass the limit (review B2/N1): accepted for 256-bit link tokens and the setup
  secret; F-2 decides it again for typed codes. The client is the `CF-Connecting-IP` address (an IPv6 /64; an IPv4-mapped
  address, dotted or hex, as IPv4); without the header (local runs) every client shares one bucket.
- D-17 (F-1b): `/api/setup` and `/api/join` answer 409 `already_signed_in` only for a working session. A request with an ended
  session or a blocked account's session may redeem; the new cookie replaces the old one.
- D-18 (F-1b): a cookie value that is not a 43-character token is `session_ended`, like an unknown token. `account_blocked` does
  not clear the cookie, so unblocking restores access on the same device (FR-09).
- D-19 (F-1b): the cookie's `Max-Age` is 90 days and is sent again whenever the expiry is extended; the extension also updates
  the device's `last_seen_at`, so "last seen" has a resolution of one day and costs at most two row writes per device and day.
  The session update is conditional on the `extended_at` that was read, so parallel requests at the day boundary extend once.
- D-20 (F-1b): the setup request may carry `name` (default "Admin"); it is used only when the account is created.
- D-21 (F-2a): the API has no path parameters and no method but `GET` and `POST`; ids travel in the body
  (`/api/devices/rename`, `/api/devices/sign-out`). A device id of another account is answered like an unknown one, 404.
- D-22 (F-2a): signing a device out deletes its row (the session cascades); `sessions.revoked_at` is still honoured but no
  code sets it. The list shows devices with a working session only. Creating a pairing record removes the account's devices
  whose session ended and expired links of every account (used invites included, once past their expiry).
- D-23 (F-2a): the previous unused pairing record is deleted, not marked revoked; "Sign out everywhere else" also deletes the
  account's unused pairing record, so a stranger who was just signed out cannot come back with a pending code.
- D-24 (F-2a): typed-code alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no I, O, 0, 1), 8 symbols, 40 bits. Lower case, spaces
  and hyphens are ignored. The code's HMAC has the prefix `code:`, so it lives in another domain than token hashes. A
  malformed code is a counted failure (410), not 400. A code collision between two live records (2^-40 per pair) would
  answer 500 to the creating request; not handled.
- D-25 (F-2a, decides B2/N1): a typed-code attempt is counted *before* the code is looked at, by one conditional upsert
  (`reserveCodeAttempt`): it writes the client's and the global `codes` counter only while the client has fewer than 10 and
  all clients at most 100 failures in the current and previous window. D1 runs statements one at a time, so parallel
  requests cannot pass a limit, and a refused request writes nothing. A successful redemption takes the count back in its
  own batch, guarded on the request's stamp. Link tokens (256 bits) keep the read-then-record order of D-16. The global
  limit therefore lets 101 failures through and then refuses for up to 20 minutes (the two-window rule of D-16).
- D-26 (F-2a, R5): client buckets in `attempts` are the first 32 hex characters of `HMAC(pepper, bucket)`; the global
  buckets keep the names `setup` and `codes`.
- D-27 (F-2a, R8): migration 0002 adds triggers: a session's account equals its device's account; a device never changes
  its account; the admin flag never changes on an existing row; an admin row is never blocked. Deleting the admin is not
  stopped by the database (the tests' cleanup deletes every account); F-2b refuses it in code, with a test.
- D-28 (F-2a): a record of a blocked account is refused like an unknown one and is not used up.
- D-29 (F-2a, R9): a leading byte order mark in a JSON body is ignored (RFC 8259 allows it); invalid UTF-8 and an empty body
  are `json_required`.
- D-30 (F-2b): admin paths are `/api/admin/…`; `requireAdmin` runs before any body field is looked at, and a signed-in
  non-admin gets 404 `not_found` (an unknown path's answer). The checks before the handler (method 405, `Origin`/JSON 403,
  no session 401) answer as on any path, so admin paths can be told from unknown ones; they are public in the contract
  anyway (review N1 of F-2b). An invite's public id is the first 32 hex characters of its token's HMAC: not
  redeemable, the token cannot be derived from it.
- D-31 (F-2b): new error codes: 403 `admin_protected` (blocking or deleting the admin; wipes nothing on the client),
  400 `confirmation_mismatch` (typed name differs from the current name; compared after trimming, case-sensitive),
  409 `account_not_active` (sign-in link for a blocked account).
- D-32 (F-2b, decides N6): "Sign out everywhere else" also deletes the account's unused sign-in link; blocking deletes the
  unused pairing record and sign-in link, so unblocking does not revive them; a pairing record is inserted only while the
  account is active, so a block racing with `POST /api/pairings` leaves none (review N3 of F-2b). A used invite is removed
  by the housekeeping of expired links once its 7 days pass, or with its account, whichever is first (review N2 of F-2b:
  fewer rows holding the name).
- D-33 (F-2b): "last sign-in" in the accounts list is the creation time of the newest device with a working session
  (`null` when none); no new column. Device count counts working sessions only.
- D-34 (F-2b, decides N3): the invite list holds unused, unrevoked, unexpired invites; creating an invite or a sign-in link
  deletes expired links of every kind (housekeeping, as `createPairing`). Revoking deletes the row; a used invite is 404.
- D-35 (F-2b): the admin row is protected in code (`is_admin = 0` in the delete and block statements), tested on both
  delete paths; migration 0002 still refuses blocking only.
- D-36 (F-2b, review N4): no sign-in link for the admin's own account (403 `admin_protected`): a 24-hour bearer link would
  be an admin credential; the admin adds devices by pairing (10 minutes) or by setup recovery (FR-11). This narrows FR-08
  ("an existing active account") to friends, in line with FR-12, which lists the actions on friends. The message of
  `admin_protected` became "This is not possible for the admin account."

## Constraints found in F-1
- A project hook blocks any command line that contains the deploy, secret or login sub-commands of wrangler, even inside a text
  being written; such text is written with the editor tools, and these commands are never put into npm scripts.
- `.claude/settings.json` denies `gh pr merge`: a CX-02 merge needs the owner's approval of the prompt, or the owner's hands.
- The Workers runtime refuses an entry module that exports anything but handlers (found by the smoke run): `src/index.ts`
  exports the default handler only.

## Open for the owner at H-11-0
1. Accept or correct the documents (intent, spec, plan, ADR-0008).
2. Merge authority: extend CX-02 to the LINGO-11 plan (recommended), or review and merge every PR himself (intent A-13).
3. Assumptions worth a look: sessions of 90 days (A-05), keys typed on each device (A-06), reply options ported with the strict tutor
   (A-08), 10 MB per account and 350 MB in total (A-11), "Delete my account" for friends (A-16), signing out or a blocked account
   clears keys and the local history from that browser (A-17), custom endpoints always through the relay (A-18), the small
   additions of A-19 (renaming, stored size in the friends list, admin recovery with a new setup secret).
4. The new package `qrcode-generator` (ADR-0008 §11).

## Checks (stage 0)
Run on 2026-11-13 on the commit that contains this text:
| Check | Result | Output |
|---|---|---|
| `scripts/check-english.sh` | PASS | `check-english: PASS` |
| `scripts/secret-scan.sh` | PASS | `0 findings` |
| `git diff --check origin/main` | PASS | no output, exit 0 |
| `swift test`, `npm test` | NOT RUN | documents only, no code changed |

### Independent AI review of the documents
Two fresh `sdlc:reviewer` runs (Opus, high effort, mode `documents`) reviewed commit `e093232`; a third fresh run reviewed the fix
commit. Reviewer output is not an owner decision; every finding was checked against the repository before it was fixed.

**Review A** (first run): verdict changes-required — 4 P1, 14 P2, 8 P3. **Review B** (second run): verdict changes-required —
1 P1, 5 P2, 9 P3. They overlap; the merged list:

| Sev | Finding | Result |
|---|---|---|
| P1 | Local journal and keys not tied to an account: sign-out, remote sign-out, block and a link opened on a signed-in device left keys and history in the browser (A F-1, B F1) | fixed: FR-02 (no redemption while signed in, account name shown), FR-07 (sign-out and a refused session clear the device), FR-23 (stores named by account), FR-52, threat rows, FAC-01, FAC-03; intent A-17 |
| P1 | FR-17, FR-21, FR-29, FR-30 without a FAC; FR-42, FR-53, FR-61 in no plan step (A F-2, B F2) | fixed: FAC-06, FAC-09, FAC-15, FAC-17; plan F-5, F-9, F-10, F-11 |
| P1 | FR-26 told the friend to delete old sessions, which frees nothing in an append-only journal (A F-3) | fixed: message corrected, size counter, cap as a variable; owner's journal size stated as not measured, measured in F-12 |
| P1 | Parity inventory missed LINGO-03 MR-01…MR-08, LINGO-07 and Mac features without a spec id; ids collide between specs (A F-4, B F3) | fixed: FR-41 has two parts (requirement ids qualified by change, and a walk of the Mac) and a named verifier per row; FAC-13 |
| P2 | Sync numbers unchecked against the free plan; 20 × 20 MB does not fit 500 MB (A F-5, F-17; B F5, F6) | fixed with numbers from Cloudflare's documentation: 1 MB batches, 10 MB per account, 350 MB total, import pauses at the daily write limit; measured in F-3 |
| P2 | Token use not atomic; no cross-kind test (B F4) | fixed: conditional update in FR-02, FAC-01 |
| P2 | Anonymous traffic can exhaust the free quota or lock typed codes (A F-6) | fixed in part and accepted: no write once over the limit, IPv6 by /64, threat row; the rest is an accepted risk (site down until the next UTC day) |
| P2 | No admin recovery (A F-7) | fixed: FR-11, intent A-19 |
| P2 | Relay: only a host-name check, URL tricks, content type, `Set-Cookie`, local development (A F-8, B F9) | fixed: strict URL rules, JSON or event-stream only, listed headers back, off in local development; reachability of internal addresses from a production Worker is not documented → tested in F-4 |
| P2 | Platform logs may record `Authorization` (A F-9) | fixed: observability set off explicitly; header capture is not documented → tested in F-4, wording of the guide follows |
| P2 | Messenger in-app browser uses up the invite; iOS home-screen app has separate storage (A F-10) | fixed: hint in FR-02, pairing into the installed app in FR-05, risk row, H-11-1 check in FAC-20 |
| P2 | Groq Whisper call is new code without a Mac counterpart (A F-11) | fixed: FR-32 specifies it as web-only, FAC-15 |
| P2 | Rejected events could stall the push queue; unknown types (A F-12) | fixed: per-event results in FR-24; unknown types are kept, as `core-ts` already does |
| P2 | Tiers and step sizes (A F-13) | fixed: F-10, F-11, F-12 are strong; the size rule names the steps that are split when their issues are created |
| P2 | Release gate left out FAC-20 and FAC-21; teacher and Goethe never tried on a phone (A F-14, B F12) | fixed: FR-67, FAC-20 (H-11-2 part) |
| P2 | FAC-16 implied a live eval (A F-15) | fixed: offline cases only, stated |
| P2 | Notices in other documents imprecise (A F-16; B F11, F14) | fixed: ADR-0008 header, ADR-0002 and ADR-0005 notices, WEB.md notice, docs/README.md, CODEBASE.md, ROADMAP rows, AGENTS.md §2 |
| P2 | No rollback or stop in the deploy guide; "cannot be undone" against D1's restore (A F-18) | fixed: FR-65, FR-09 |
| P3 | Pairing code as HMAC; QR drawing and CSP; `_headers`; Vite dev server (A F-19, F-20; B F8, F10) | fixed: FR-05, FR-55, ADR-0008 §11 |
| P3 | Unlabelled executor additions (A F-21; B F7) | fixed: intent A-18, A-19; the shortcut rule of FR-53 |
| P3 | Testability details: 91 days, colour lint, FAC-19 phone part, voice quality, admin self-delete (A F-22; B F13) | fixed: FAC-03, FAC-17, FAC-19, FR-33, FR-09 |
| P3 | "401 only" in ADR-0008; list of replaced API paths (A F-23) | fixed |
| P3 | Completion plan against A-13 (A F-24) | fixed: the H-11-0 row says CX-02 is not applied to section F without the owner |
| P3 | Check output only in a PR that did not exist; AGENTS.md still listed H-05 as open; ADR number unexplained (A F-25; B F15) | fixed: this section, AGENTS.md §1, "Facts" above. Not done: the spec has no scenario section — its acceptance table is the list of scenarios |
| P3 | `__Host-` cookie prefix (A F-26) | fixed: FR-04 |

Open P0/P1 after the fixes: **none**.

**Review C** (third run, fresh `sdlc:reviewer`, Opus, high, on `e093232..0924ac4`): verdict **approved**, no P0/P1. Mechanical
checks by the reviewer: FR-01…FR-67 all defined, every FR covered by a FAC and a plan step, numbering intact. Its 4 P2 and 7 P3
were fixed in the next commit:

| Sev | Finding | Result |
|---|---|---|
| P2 | A bare 401/403 (broken deployment, missing pepper, failed `Origin` check) could wipe every device | fixed: wipe only on typed codes `session_ended` / `account_blocked`; the engine answers 500 when pepper or database is missing; the guide warns that changing the pepper signs everyone out (FR-07, FAC-03) |
| P2 | "Nothing readable offline" cannot hold for an offline device | fixed: deletion at the first contact after the session ended; every local store is deleted before a link is redeemed on a browser with no valid session (FR-07) |
| P2 | Admin recovery makes the setup secret a standing admin credential | fixed: at least 32 random bytes (shorter counts as not configured), its own global failure limit, the guide says it is a standing credential (FR-11, FAC-04) |
| P2 | Atomic use not implementable in a D1 batch | fixed: stamped `UPDATE` plus `INSERT … SELECT … WHERE EXISTS` guarded on the stamp (FR-02, FAC-01) |
| P3 | A repeated push could inflate the size counter; the 350 MB total ignored indexes | fixed: only newly inserted events count; the total includes an index overhead measured in F-3 (FR-24, FR-26, FAC-09) |
| P3 | Threat row overstated protection against the admin | fixed: threat row and ADR-0008 Consequences state that an admin can open a friend's history through a sign-in link, visible in the Devices list |
| P3 | Wipe lists differed between FR-07, FR-23, FAC-03 | fixed: one list, every store of the account |
| P3 | LINGO-01 S-xx and LINGO-09 rows missing from the parity sources | fixed: intro and FR-47 |
| P3 | Relay: special-use names, methods | fixed: FR-22, FAC-07 |
| P3 | Placeholder "row added below" | fixed: this section |
| P3 | ROADMAP row said H-05 awaited; grammar in the ARCHITECTURE notice | fixed |

Not checked by the reviewers: Cloudflare figures against live sources (read by the executor from the documentation on 2026-11-13),
section numbers of the WEB.md and ARCHITECTURE.md notices line by line, GitHub state.

## Checks (F-1a)
Run on 2026-11-13 on the commit that contains this text (Node 26, wrangler 4.162.0):
| Check | Result | Output |
|---|---|---|
| `npm ci && npm test` | PASS | core-ts: 7 files, 304 tests passed; engine: `tsc` clean, 1 file, 19 tests passed |
| `npm run build` | PASS | exit 0 |
| `npx wrangler d1 migrations apply lingo --local` | PASS | `11 commands executed successfully`, `0001_init.sql ✅` |
| `npm run smoke -w services/engine` | PASS | `/ → 200 text/html`, `/join → 200 text/html`, `/api/nope → 404 application/json`, `smoke: PASS` (the three headers on each) |
| `scripts/secret-scan.sh` | PASS | `0 findings` |
| `scripts/check-english.sh` | PASS | `check-english: PASS` |
| `swift test` | NOT RUN | no Swift file changed |

Acceptance covered by F-1a: FAC-18 (part: headers on static files and API answers, foreign `Origin` refused), FAC-03 (part: a
missing pepper gives 500, not 401), FAC-19 (part: migration and local start by the commands of `services/engine/README.md`).
FAC-01 and the session part of FAC-03 belong to F-1b.

## Checks (F-1b)
Run on 2026-11-13 on the commit that contains this text (Node 26, wrangler 4.162.0):
| Check | Result | Output |
|---|---|---|
| `npm ci && npm test` | PASS | core-ts: 7 files, 304 tests passed; engine: `tsc` clean, 2 files, 43 tests passed |
| `npm run build` | PASS | exit 0 |
| `npm run smoke -w services/engine` | PASS | 10 lines `ok`, among them `POST /api/setup → 200 and the development cookie`, `GET /api/me with the cookie → the admin`; `smoke: PASS` |
| Mutation check of the tests (by hand, not in CI) | PASS | seven guards removed one at a time — the `used_at IS NULL` condition, the stamp guard of the inserts, the client limit, the revoked check, the once-a-day extension, the global setup limit, the blocked check — each made 1–2 tests fail; restored, all passed |
| `scripts/secret-scan.sh` | PASS | `0 findings` |
| `scripts/check-english.sh` | PASS | `check-english: PASS` |
| `swift test` | NOT RUN | no Swift file changed |

Acceptance covered by F-1 after F-1b — engine part; the pages of FAC-01 ("the page shows the account name") are F-9, creating and
revoking an invite through the API is F-2 (tests insert link rows directly):
| Check | Tests (`services/engine/test/auth.test.ts`) |
|---|---|
| FAC-01 | redeem; one refusal for used, expired, revoked, unknown, malformed and other-kind tokens; four concurrent redemptions → one account and session; `GET` changes nothing; no token in D1 in clear; no redemption on a signed-in device |
| FAC-03 (part) | once-a-day extension; a session unused for 91 days refused; `session_ended` and `account_blocked` typed; no cookie → `not_signed_in`; missing pepper or database → 500 |
| FAC-04 (setup part, ahead of F-2) | admin created once; recovery signs the same admin in and creates nothing else; 404 without or with a short secret; client and global limits; refusals write nothing |
| FAC-18 (part), FAC-19 (part) | `shell.test.ts` and the smoke run |

## Checks (F-2a)
Run on 2026-11-14 on the commit that contains this text (Node 26, wrangler 4.162.0):
| Check | Result | Output |
|---|---|---|
| `npm test` (all workspaces) | PASS | core-ts: 7 files, 304 tests passed; engine: `tsc` clean, 3 files, 67 tests passed (again after the review fixes) |
| `npm run build` | PASS | exit 0 |
| `npm run smoke -w services/engine` | PASS | 14 lines `ok`, among them `POST /api/pair with the typed code → 200 and a second session`, `GET /api/devices → two devices`, `POST /api/sign-out → 200, then GET /api/me → 401`; `smoke: PASS` (migration 0002 applied by wrangler) |
| Mutation check of the tests (by hand, not in CI) | PASS | 16 guards removed one at a time — the reservation's limit condition, the global codes limit, the refund, the refund's guard, the kind check, `used_at IS NULL`, the expiry, the active-account condition, the `code:` prefix, the account condition of rename and of sign-out, "others keeps the caller", "others cancels the pairing record", the live-session filter of the list, cancelling the previous record, the hashed bucket — each made 1–3 tests fail (the prefix after a test was added for it); restored, all passed |
| `scripts/secret-scan.sh` | PASS | `0 findings` |
| `scripts/check-english.sh` | PASS | `check-english: PASS` |
| `git diff --check origin/main` | PASS | no output |
| `swift test` | NOT RUN | no Swift file changed |
| Real D1 concurrency | NOT RUN | local miniflare runs statements one by one; the burst tests (30 and 120 parallel requests) prove the statement's condition, not real interleaving. The design relies on D1 executing one statement at a time |

Acceptance covered by F-2a (`services/engine/test/devices.test.ts`, `shell.test.ts`):
| Check | Tests |
|---|---|
| FAC-02 | by link; by code; one refusal for reused, expired, cancelled, unknown, malformed, other-kind; one record used once by concurrent token and code requests; nothing in clear; client limit shared with link attempts, refused without a write, recovery; IPv6 /64 burst; global typed-code limit with links still working |
| FAC-03 (engine part) | list with the current device; rename; sign-out of another device, of this device, of all others; an expired device is not listed; blocked account refused. The browser-store parts are F-10 |
| FAC-05 (ahead of F-3) | another account's device id is 404 for rename and sign-out; lists hold own devices only |

Open review items of F-1 after F-2a: R5 fixed (D-26, D-22); R8 fixed (D-27; admin deletion in F-2b); R9 fixed (charset
parameter, invalid UTF-8, `PUT`/`PATCH`/`DELETE`/`HEAD`, route table equal to the contract); B2/N1 decided (D-25).
Still open: R3 (F-3), R4 (F-4), R11 (F-3 / F-23), N2 (F-23), R1 (F-15).

## Checks (F-2b)
First run on 2026-11-14 on `e7b06a5`; rerun after the review fixes on `eb81229` (Node 26, wrangler 4.162.0), same results
unless noted:
| Check | Result | Output |
|---|---|---|
| `npm test` (all workspaces) | PASS | core-ts: 7 files, 304 tests; engine: `tsc` clean, 4 files, 90 tests |
| `npm run build` | PASS | exit 0 |
| `npm run smoke -w services/engine` | PASS | 21 lines `ok`, among them `GET /api/admin/accounts as the friend → 404`, `POST /api/sign-in with the admin's link → 200 in the friend's account`, `POST /api/admin/accounts/block for the admin's own account → 403`, `delete with a wrong name → 400; with the name → 200, then GET /api/me as the friend → 401`; `smoke: PASS` |
| Mutation check (by hand, not in CI) | PASS | on `eb81229`: the new `is_admin = 0` of the sign-in link removed → 1 test fails ("is made for an active, existing friend's account only"); restored. The `status = 'active'` of the pairing insert (review N3) has no test: the race needs two interleaved requests, which miniflare does not run. On `e7b06a5`: 25 guards removed one at a time (admin gate; invite list unused/unexpired/kind/revoked; revoke kind/unused; invites switch; housekeeping; sign-in link active-only, cancels previous, this account only, kind; block not-admin, removes links, keeps used invite; delete not-admin, typed name; `admin_protected`; live-session filter of the list; sign-out-others cancels sign-in link; own rename/delete take the session's account; unblock target only) — each made 1–6 tests fail (unblock after a test was added); restored, all pass |
| `scripts/check-english.sh` | PASS | `check-english: PASS` |
| `scripts/secret-scan.sh` | PASS | `0 findings` |
| `git diff --check` | PASS | no output |
| Independent review | PASS | fresh `sdlc:reviewer` (Opus, high) on `4c40ba9..655330a`: approve with notes, no P0/P1/P2; see "Independent AI review of F-2b" |
| CI | see the PR | pushed with `eb81229` and this handoff |
| `swift test` | NOT RUN | no Swift file changed |

Acceptance covered (`services/engine/test/admin.test.ts`): FAC-04 engine part (sign-in link, block, unblock, delete, non-admin
404 on every admin path, admin cannot block or delete itself, no request grants the flag, own rename and delete, blocked
message); FAC-05 part (two friends and the admin against every route: no answer holds the other account's data; admin
answers hold no events, device names or session data). The `/admin` page itself is F-9…F-10.

### Independent AI review of F-2b
Fresh `sdlc:reviewer` (Opus, high effort, mode `pr feat/148-engine-admin`) on `655330a`, run from a separate session's
worktree with no history of the build. Verdict: **approve with notes**, no P0/P1/P2. It ran `npm test -w services/engine`
(90 tests, admin 23), the smoke run, both scripts — PASS. Not checked by it: production D1 (foreign-key enforcement assumed
from D1's default, seen in miniflare and local `wrangler dev`), real concurrency, the 25-guard mutation check, CI, `npm run
build`, core-ts. Fixes in `eb81229`. Reviewer output is not an owner decision.
| ID | Sev | Finding | Result |
|---|---|---|---|
| N1 | P3 | D-30 said `requireAdmin` runs before the body is read; the shell's method, `Origin`/JSON and session checks run first, so admin paths can be told from unknown ones | answered: FR-12 holds for well-formed requests of signed-in non-admins, and the paths are public in the contract; D-30 and the contract's `NotAdmin` reworded |
| N2 | P3 | The housekeeping of expired links also removes a used invite after 7 days, against D-32 | answered: kept (fewer rows holding a name); D-32 reworded |
| N3 | P3 | A block landing between a friend's session check and the pairing insert leaves a record that an unblock within 10 minutes revives | fixed: the insert runs only for an active account, else 403 `account_blocked`; contract says so. No test (needs real interleaving) |
| N4 | P3 | A sign-in link can be made for the admin's own account: a 24-hour bearer admin credential | fixed: refused with 403 `admin_protected` (D-36), test and mutation check |
| N5 | P3 | Contract said "no count of sessions" while `deviceCount` counts sign-in sessions; handoff said 22 tests (23); `/api/account/delete` can answer 404 after a concurrent delete | fixed: "conversation sessions" and a note on `deviceCount`; count 23; 404 added to the contract |

### Independent AI review of F-2a
Fresh `sdlc:reviewer` (Opus, high effort, mode `pr 153`) on `4fa07f7`. Verdict: **approve with notes**, no P0/P1/P2. It ran
`npm test -w services/engine` (67 tests), `devices.test.ts` six times, the smoke run, both scripts — PASS — and the reserve
statement in sqlite3 3.43.2 (client 9 / global 100 → 2 rows changed; the next call 0). Not checked by it: real D1
concurrency, production D1's `meta.changes` for upserts, core-ts, the mutation check. Reviewer output is not an owner decision.
| ID | Sev | Finding | Result |
|---|---|---|---|
| N1 | P3 | Two assertions of the 0002 test matched `/admin\|UNIQUE/` and would pass without the triggers | fixed: exact trigger messages, and a blocked admin inserted while no admin exists |
| N2 | P3 | FR-06 says "10 minutes", the code refuses for up to 20 | fixed: wording of FR-06 in `spec.md` |
| N3 | P3 | `POST /api/pairings` deletes expired links of every account, against the letter of FR-14 | answered: housekeeping of dead rows, returns nothing (D-22). **Constraint for F-2b**: the admin's invite list shows unexpired invites only |
| N4 | P3 | Contract: no 400 on three paths, 403 `origin_refused`/`json_required` not listed for signed-in `POST`s, no `Set-Cookie` on the 200 of `/api/devices/sign-out` | fixed in `openapi.yaml` |
| N5 | P3 | No test that the device cleanup leaves another account's ended device alone | fixed: test |
| N6 | P3 | "Sign out everywhere else" cancels only `pair` records | **constraint for F-2b**: decide and test whether an unused `signin` link is cancelled too |

### Independent AI review of F-1a
Fresh `sdlc:reviewer` (Opus, high effort, mode `pr 151`) on commit `c9fc12b`, read through git only; it ran no command.
Verdict: **approve with notes**, no P0/P1. Reviewer output is not an owner decision.
| ID | Sev | Finding | Result |
|---|---|---|---|
| R1 | P2 | The `Origin` check compares with the request URL; behind the cloudflared tunnel of FR-63 the Worker may see `http` while the browser sends `https`, and every `POST` would be refused | answered, not changed here: the URL that `wrangler dev` reports behind a tunnel was not observed (the reviewer inferred it). **Constraint for F-15**: before the tunnel instructions are written, run the smoke through a tunnel; if the origins differ, add a development-only allowance (with `DEV_MODE=1`), tested and absent from `wrangler.jsonc`. The same applies to the development cookie rule |
| R2 | P2 | A used invite could never point at its account, so deleting the account left the invite row with the friend's name | fixed: the CHECKs allow `account_id` on a used invite; F-1b's redemption batch sets it; test "an invite has a name and no account…" |
| R3 | P3 | A body without `Content-Length` is read whole before the size check | open, for F-3 (which brings the large bodies): read with a stream reader that stops at the limit |
| R4 | P3 | `RELAY_ENABLED=1` is also read by `wrangler dev`; FR-22 wants the relay off locally unless a development variable turns it on | **constraint for F-4**: `relayEnabled` must also require that `DEV_MODE` is not `1`, or an explicit development variable |
| R5 | P3 | `attempts.bucket` would hold client addresses in clear and grow | answered in F-1b: `recordFailure` deletes windows older than the previous one in the same batch, so an address stays at most 20 minutes after its last failure; hashing the bucket is left to F-2 with the typed-code limit. Cleanup of expired links: F-2 |
| R6 | P3 | The global setup limit of 20 and the `too_many_attempts` code were not recorded | recorded in D-15 (F-1b) |
| R7 | P3 | "No `GET` changes state" against the expiry refresh of `GET /api/me` | fixed: wording in `openapi.yaml` |
| R8 | P3 | The database does not enforce: a session's account equals its device's account; the admin cannot be blocked | part fixed (`code_hash` only for pairing); the rest is open for F-2, which writes the first code that could break them |
| R9 | P3 | The routes-against-contract test looped over an empty table; missing cases (charset parameter, invalid UTF-8, `PUT`/`DELETE`) | routes exist from F-1b on; the missing cases are open for F-2 |
| R10 | P3 | `preview_urls` not disabled | fixed, with a test |
| R11 | P3 | A D1 point-in-time restore reissues `seq` values | **constraint for F-3 / F-23**: a cursor epoch, or a forced full pull after a restore in the deploy guide |
| R12 | P3 | No `Allow` header on 405; a clone path with spaces breaks the vitest config | path fixed (`fileURLToPath`); `Allow` not added |

### Independent AI review of F-1b
Two fresh `sdlc:reviewer` runs (Opus, high effort, mode `pr 152`): run 1 on `7473f32` (findings N1–N6), run 2 on `e6e2f5e`
(findings B1–B4). Both: verdict **approve with notes**, no P0/P1/P2; both ran `npm test -w services/engine` (43 tests) and the
smoke run, PASS. Fixes in `2bfe80e`. Reviewer output is not an owner decision.
| ID | Sev | Finding | Result |
|---|---|---|---|
| B1 | P3 | A name with NUL passes the 1–40 check in JS but fails SQLite's `CHECK (length(name) …)` (which stops at NUL), giving 500 instead of 400; newlines and bidi overrides were stored | fixed: control characters (C0, DEL, C1) and bidi overrides are `invalid_request`; tests for `deviceName` and `name`; D-14 |
| B2 / N1 | P3 | The limit is read before the failure is written, so a burst of parallel attempts passes it; D-16 overstated | answered: accepted for 256-bit tokens and the setup secret, wording of D-16 corrected. **Constraint for F-2**: decide a conditional increment for the typed codes (about 40 bits) |
| B3 / N5 | P3 | D-17 (an ended or blocked account's session may redeem) and the default names "Admin"/"Browser" untested | fixed: two tests |
| B4 / N4 | P3 | Any IPv6 with a `.` counted as IPv4-mapped (NAT64 `64:ff9b::…` too); hex `::ffff:cb00:7109` fell into an IPv6 bucket | fixed: only the `::ffff:` prefix, dotted or hex, maps to IPv4; tests. A missing `CF-Connecting-IP` still shares one bucket (local runs only, D-16) |
| N2 | P3 | While the setup secret is set, a stranger can keep the global setup limit tripped and block admin recovery | **constraint for F-23**: the deploy guide removes the setup secret after the first setup and explains that recovery means setting it again; threat table entry |
| N3 | P3 | `InvalidRequest` said a wrong length gives 400, but a token or secret of the wrong length is a counted failure (410 / 403) | fixed: wording in `openapi.yaml` |
| N6 | P3 | The daily extension was not conditional, so parallel requests at the day boundary each wrote | fixed: `AND extended_at = ?` the value read; D-19 |

Found while waiting for CI: the smoke step hung on the Linux runner after its checks, because `npx` did not pass SIGTERM on to
wrangler and workerd. Fixed on F-1a (`5434501`, merged into F-1b): wrangler runs in its own process group, the script exits
explicitly, and the CI step has a 3-minute timeout.

## Owner's answers at H-11-0 (2026-11-13, in chat)
Accepted: the documents (intent, spec, plan, ADR-0008); CX-02 extended to the LINGO-11 plan; assumptions A-05, A-06, A-08, A-11, A-16,
A-17, A-18, A-19 confirmed; the package `qrcode-generator` allowed (ADR-0008 §11). The owner asked to start writing the engine
(step F-1) in a new session.

## Next step
State on 2026-11-14: **F-1 is done.** PR #151 (F-1a) and PR #152 (F-1b) are squash-merged into `main` (`4d0c03c`, `1fed4e1`);
issue #147 is closed; CI on `main` at `1fed4e1` is green (`ts`, `repo`, `mac`). Verified on `1fed4e1`'s tree before the merge:
engine 45 tests, core-ts 304 tests, smoke, check-english PASS, secret-scan 0 findings. NOT RUN: real D1 concurrency (local
miniflare runs requests one by one, so the race tests check the guards, not real interleaving).
Merging: `gh pr merge` is denied in `.claude/settings.json`; the owner runs it himself after green CI and review (as for
#151/#152). The branches `feat/147-engine-skeleton` and `feat/147-engine-auth` are kept (never deleted by agents).

1. **F-2a is built and reviewed** on `feat/148-engine-pairing`, PR #153: it waits for green CI and the owner's merge.
2. **F-2b is built and reviewed** on `feat/148-engine-admin` (`c05862c` contract, `e7b06a5` code, `eb81229` review
   fixes); see "Checks (F-2b)", its review and decisions D-30…D-36. The PR is open, stacked on #153; it waits for green CI
   and the owner's merge: #153 first, then F-2b (`gh pr merge` is denied to agents). That closes #148.
   The local branch `feat/148-engine-admin` in the worktree `148-engine-admin-274c14` still points at `655330a`; the remote
   branch holds the reviewed commits (pushed from a detached HEAD in another worktree). Fetch before using it.
   Next after the merge: **F-3** (sync, strong tier: data loss and concurrency).
3. In a separate worktree **F-5** (stage B, standard tier) can start in parallel: its milestone and issue are not created yet.
