# LINGO-11: Handoff — Lingo Web for friends

Status: **documents v1 written, waiting for the owner at H-11-0; no code** · Date: 2026-11-13

## Identity
- Change LINGO-11, risk R3. Documents: [intent](intent.md), [spec](spec.md), [plan](plan.md),
  [ADR-0008](../../decisions/ADR-0008-web-for-friends.md) (proposed).
- Branch `docs/lingo-11-web-for-friends` from `origin/main` `5144f77`, worktree `.claude/worktrees/lingo-11-docs`.
- No GitHub issues or milestones yet: they are created after H-11-0 from the accepted plan (SDLC §3.4).

## State
- The owner's goal and decisions 1…16 (brainstorm 2026-11-13) are in `intent.md`. New features are paused; LINGO-09 on the Mac is
  paused with its PRs #119 and #141–#145 open and untouched.
- The web part of LINGO-03 is superseded by this change when the owner accepts it: P-07c2 and P-08…P-20, issues #10…#27, draft PR
  #62. The issues and the PR are **not closed yet** — that happens after H-11-0, with a link to this change.
- `packages/core-ts` on `main` has: events (codec, ULID, reducer), reply protocol parser, command detector, VAD and segmenter, model
  decoders. `apps/web` and `services/engine` do not exist.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Stage 0: documents | this PR | see "Checks" below | intent, spec (FR-01…FR-67, FAC-01…FAC-22), plan (F-1…F-24, H-11-0…H-11-4), ADR-0008, CORS evidence; notes in WEB.md, ARCHITECTURE.md, CODEBASE.md, docs/README.md, ADR-0002/0003/0005, AGENTS.md, ROADMAP, completion plan, LINGO-03 handoff |

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

Open P0/P1 after the fixes: **none**. Re-review of the fix commit: see the PR description and the row added below.

## Next step
After H-11-0: create the milestones and issues of the plan, mark LINGO-03 issues #10…#27 and PR #62 as superseded (comment and close,
with the owner's acceptance as the reason), then start **F-1** (strong tier) and, in a separate worktree, **F-5** (standard tier).
