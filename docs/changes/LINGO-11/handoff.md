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
| Stage 0: documents | this PR | see "Checks" below | intent, spec (FR-01…FR-67, FAC-01…FAC-22), plan (F-1…F-24, H-11-0…H-11-4), ADR-0008, CORS evidence; notes in WEB.md, ARCHITECTURE.md, ADR-0002/0003/0005, AGENTS.md, ROADMAP, completion plan, LINGO-03 handoff |

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
- ADR numbers: 0006 is unused on `main` and on the LINGO-09 branches; this change takes 0008 after 0007.

## Executor decisions
- D-01: requirement prefix `FR` / `FAC`, plan steps `F-xx`, checkpoints `H-11-x`.
- D-02: the spec does not restate Mac behaviour. Parity is made testable by the inventory `parity.md` (FR-41, step F-5) instead of a
  second copy of 300 Mac requirements.
- D-03: custom endpoints always use the relay, even when an endpoint would allow CORS, so that the CSP names three hosts only.
- D-04: no `ajv` at run time in the engine and no ZIP package; see ADR-0008 §11.
- D-05: documents of other changes are annotated, not rewritten: WEB.md and ARCHITECTURE.md keep the LINGO-03 design under a notice
  until step F-23 rewrites them from the built state.

## Open for the owner at H-11-0
1. Accept or correct the documents (intent, spec, plan, ADR-0008).
2. Merge authority: extend CX-02 to the LINGO-11 plan (recommended), or review and merge every PR himself (intent A-13).
3. Assumptions worth a look: sessions of 90 days (A-05), keys typed on each device (A-06), reply options ported with the strict tutor
   (A-08), 20 MB per account (A-11), "Delete my account" for friends (A-16).
4. The new package `qrcode-generator` (ADR-0008 §11).

## Checks (stage 0)
See the PR description for the output of `scripts/check-english.sh`, `scripts/secret-scan.sh`, `git diff --check` and the verdict of
the independent AI review. No code changed; `swift test` and `npm test` NOT RUN (documents only).

## Next step
After H-11-0: create the milestones and issues of the plan, mark LINGO-03 issues #10…#27 and PR #62 as superseded (comment and close,
with the owner's acceptance as the reason), then start **F-1** (strong tier) and, in a separate worktree, **F-5** (standard tier).
