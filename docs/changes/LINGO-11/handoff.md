# LINGO-11: Handoff — Lingo Web for friends

Status: **stage A (engine) in progress: F-1a built, F-1b next** · Date: 2026-11-13

## Identity
- Change LINGO-11, risk R3. Documents: [intent](intent.md), [spec](spec.md), [plan](plan.md),
  [ADR-0008](../../decisions/ADR-0008-web-for-friends.md) (accepted at H-11-0).
- Documents: PR #146 (merged by the owner). Stage A: milestone "LINGO-11 · A Engine" (#9), issues #147 (F-1), #148 (F-2),
  #149 (F-3), #150 (F-4). Milestones and issues of stages B…H are created when their stage starts.
- F-1 worktree `.claude/worktrees/lingo-11-f1-engine-cc30f9`: branch `feat/147-engine-skeleton` (F-1a) from `origin/main`
  `46bfe4e`; F-1b is stacked on it as `feat/147-engine-auth`.

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

## Owner's answers at H-11-0 (2026-11-13, in chat)
Accepted: the documents (intent, spec, plan, ADR-0008); CX-02 extended to the LINGO-11 plan; assumptions A-05, A-06, A-08, A-11, A-16,
A-17, A-18, A-19 confirmed; the package `qrcode-generator` allowed (ADR-0008 §11). The owner asked to start writing the engine
(step F-1) in a new session.

## Next step
**F-1b** (strong tier, issue #147, branch `feat/147-engine-auth` stacked on F-1a): tokens, sessions and cookie, attempt counters,
`/api/setup`, `/api/join`, `/api/me`. Then F-2 (#148). In a separate worktree **F-5** (standard tier) can start: its milestone and
issue are not created yet.
