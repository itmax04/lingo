# Running Lingo with the Codex agent

Status: current · Date: 2026-11-03 · Owner: itmax04
Links: [AGENTS.md](../../AGENTS.md) · [SDLC](SDLC.md) · [completion plan](../plans/COMPLETION-PLAN-2026-11.md) · [STAGE-PROMPTS](STAGE-PROMPTS.md)

This is the operating manual for finishing Lingo with OpenAI Codex (the Codex CLI on the owner's Mac, and Codex cloud for the parts
that allow it). It does not change any rule: [AGENTS.md](../../AGENTS.md) §6 and the [SDLC](SDLC.md) still apply word for word.
Where this file and an accepted spec disagree, the spec wins; where it and AGENTS.md disagree, fix this file.

## 1. Owner decisions behind this manual (2026-11-03, translated from Russian)

| ID | Question | Answer | Effect |
|---|---|---|---|
| CX-01 | What does "finish with Codex" cover? | "LINGO-05 + the roadmap" | Detailed issues for the remaining LINGO-05 steps (T-6a…T-9, H-05); the later changes are an ordered plan in which Codex first writes the documents and stops at the owner's H-0 |
| CX-02 | May Codex merge its own PRs? | "Yes, itself" | Codex squash-merges its own PR after green CI and an independent review with no open P0/P1 (§5). Owner checkpoints H-x, accounts, keys, settings and production deploys stay with the owner |
| CX-03 | Stale GitHub issues of LINGO-03 Stage 0 | "Close with a link to the PR" | Done in the PR that added this file; GitHub issues now show only open work |

CX-02 is the "explicit scoped authority" the [SDLC](SDLC.md) §4 asks for. It covers product and docs PRs of the steps listed in the
[completion plan](../plans/COMPLETION-PLAN-2026-11.md), one at a time, and nothing else: not the parked draft PR #62, not other
agents' PRs, not a red PR, not a PR whose review has an open P0/P1.

## 2. Where Codex runs

| Work | Where | Why |
|---|---|---|
| Anything in `apps/mac/` (Swift), mixed Swift + TS changes, screenshots, `build-app.sh`, `--check-keys`, audio | **Codex CLI on the owner's Mac** in `~/Developer/lingo` (own worktree) | Swift, Xcode, the signed app and the Keychain exist only there (AGENTS §10) |
| TS-only (`packages/core-ts`, `apps/web`, `services/engine`), docs | Codex CLI on the Mac, or Codex cloud | Node 22 and `npm test` work in the cloud with mocks |
| Live model calls, evals | nowhere in LINGO-05 (owner decision Q-03); later only at night, budgeted (AGENTS §6.5) | free quota |
| Deploys, `wrangler secret`, remote D1, accounts, OAuth apps, macOS settings | **the owner only** — Codex writes exact steps | AGENTS §6.2–6.4 |

Codex reads `AGENTS.md` itself. `CLAUDE.md`, `.claude/` and `.sdlc/` belong to Claude Code: do not edit them and do not treat the
Claude SDLC plugin state as the cursor. The cursor is the change's `handoff.md` → "Next step" plus the open issues of the milestone.

Suggested local setup (the owner's own `~/.codex/config.toml`; never put keys into the repository): sandbox "workspace-write" with
network access for `gh` and `npm`, approvals "on-request". Commands that need the owner's systems are asked for, not forced.

## 3. One step = one session = one PR

Run this loop for every step. Do not ask the owner between ready steps (AGENTS §5 "Autonomy").

1. **Pick the step.** `git fetch origin && gh issue list --milestone "<milestone>" --state open`. Take the lowest-numbered issue that
   is not `owner-checkpoint` and not `blocked`, whose "Depends on" items are closed. Cross-check with `handoff.md` → "Next step";
   if they disagree, the handoff wins and you fix the issue.
2. **Own worktree.** `git worktree add ../lingo-<step> -b <type>/<issue>-<slug> origin/main`. Never work in another agent's directory.
3. **Read** AGENTS.md, ARCHITECTURE, MAC.md (or WEB.md), EVOLVING, the change's `intent.md`, `spec.md`, `plan.md`, `handoff.md`, the
   issue, and the code it names. Requirement IDs (CR, WR, SR, XR, GR, PX, TAC) are defined only in `spec.md`.
4. **Implement exactly the issue.** Contracts first for shared behaviour (AGENTS §6.9 with LINGO-05 decision D-01). No new dependency
   outside the ADR allow-lists. UI strings English in code, Russian in the String Catalog. DESIGN.md tokens only.
   If the step grows past ~600 changed lines without fixtures and catalogues, split it (engine part, then UI part) and say so in the issue.
5. **Check** (§4) and keep the real output.
6. **Update** the change's `handoff.md` (a row in "Done", executor decisions D-xx, "Next step") in the same PR.
7. **Commit and open the PR** with `.github/pull_request_template.md` filled; body starts with `Closes #<issue>`.
8. **Independent review** (§5), fix findings, re-review until there is no open P0/P1.
9. **Merge** (§6), then rebuild the owner's app: `apps/mac/scripts/build-app.sh` (Mac steps only).
10. **Report** in Russian (SDLC §10) as an issue comment on the epic and continue with the next step.

## 4. Checks per area

Run what the diff touches; report PASS / FAIL / NOT RUN with the real numbers.

| Area touched | Commands |
|---|---|
| Swift | `swift build --package-path apps/mac && swift test --package-path apps/mac` · `apps/mac/scripts/check-core-ios.sh` |
| UI strings, tokens | `python3 scripts/check-design.py` (bilingual strings, contrast) · screenshots RU/EN, light/dark (`--ui-snapshot`) on a synthetic journal, never the owner's data |
| TS, contracts | `npm ci && npm test` |
| Prompts | the prompt snapshot tests (re-record and explain every snapshot change in the PR) |
| Always | `scripts/check-english.sh` · `scripts/secret-scan.sh` (0 findings before every push) |

A unit test is not live evidence: anything that needs the real model, a microphone, a notification or the owner's eyes is NOT RUN
with a reason, and is listed for the owner checkpoint.

## 5. Independent review

The reviewer is a **fresh Codex session** that did not write the code (for example `/review` in a new Codex CLI session, or a new
session started with the prompt below). It reads, runs read-only checks and writes findings; it never edits.

```text
You are the independent reviewer of PR <number> in itmax04/lingo. Do not edit files.
Read AGENTS.md, docs/process/SDLC.md §6, the change's spec.md (the requirement IDs named in the PR),
plan.md and handoff.md, then `gh pr diff <number>` and the code around every hunk.
Check: the PR does exactly its issue; every named requirement and TAC is met or honestly NOT RUN;
event and settings compatibility (old journals decode, additive events, tolerant decoding);
Swift/TS parity and contracts fixtures; prompt sizes and stripTags/rule 7; quota per purpose;
privacy (no utterance text, facts or keys in logs); no pronunciation assessment; DESIGN.md tokens,
RU and EN strings, accessibility labels; races (double clicks, overlapping turns, cancellation);
tests cover the edge cases the spec lists. Run `swift test --package-path apps/mac` and/or `npm test`
if the diff touches them.
Output: a verdict (approve / approve-with-notes / changes-required) and findings F-1… with
priority P0–P3, file:line, a concrete failing scenario and a suggested fix. P0/P1 block the merge.
```

Record the verdict and the reviewed commit SHA in the PR (a comment) and in `handoff.md`. After fixes, re-review only the new commits
plus anything they touch.

## 6. Merge rules (CX-02)

Codex may run `gh pr merge <number> --squash --delete-branch=false` when **all** hold:
- CI is green on the PR head (`gh pr checks <number>`), and the head is the SHA that was reviewed;
- the last review has no open P0/P1 and every P2 is fixed or answered in the PR;
- the DoD checklist (SDLC §6) is complete; `handoff.md` is updated;
- the step is not an owner checkpoint and needs no owner action first.

Never: force-push, rebase a pushed branch, rewrite history, delete branches, push to `main`, merge someone else's PR, merge a red PR.
To bring a branch up to date, merge `origin/main` into it with a normal merge commit. macOS CI minutes count ×10: do not re-run the
`mac` workflow without a reason.

## 7. When to stop

Stop and write to the owner in Russian (few questions, multiple choice, a recommended option) only at:
- an owner checkpoint issue (`owner-checkpoint` label, H-x): give the exact checklist and what to send back;
- an action the owner must do: accounts, keys, devices, money, macOS or console settings, deploys;
- a requirement that is wrong or contradicts another one (propose the spec change; do not silently deviate);
- the end of a change: the final report (SDLC §10) mapping every TAC to evidence.

Record each answer in `intent.md` (owner decisions) or `handoff.md` (executor decisions).

## 8. Start prompts

### 8.1 Next step of the current change

```text
You are the Codex executor of Lingo (itmax04/lingo), working locally on the owner's Mac in
~/Developer/lingo. Follow AGENTS.md and docs/process/CODEX.md exactly.
Current change: LINGO-05 (docs/changes/LINGO-05/), milestone "LINGO-05 · Teacher".
Take the next step as CODEX.md §3: lowest open unblocked issue of the milestone, cross-checked
with handoff.md "Next step". Own worktree and branch, one PR, checks of §4 with real output,
handoff.md updated, independent review in a fresh session (§5), merge under §6, rebuild the app,
Russian report as a comment on the epic, then continue with the next step in a new session.
Stop only at §7. No live model calls (LINGO-05 Q-03). Never edit CLAUDE.md, .claude/ or .sdlc/.
```

### 8.2 Documents of a new change (LINGO-09, LINGO-03 resume, LINGO-04, LINGO-06)

```text
You are the Codex executor of Lingo (itmax04/lingo). Follow AGENTS.md and docs/process/CODEX.md.
Write the documents of <CHANGE> as docs/plans/COMPLETION-PLAN-2026-11.md describes it:
first a short brainstorm with the owner in Russian (at most 5 multiple-choice questions with a
recommended option), then docs/changes/<CHANGE>/intent.md, spec.md (requirement IDs and TACs),
plan.md (steps of ≤ 600 lines) and handoff.md, using LINGO-05 as the model of form and depth.
Independent review of the documents in a fresh session; fix P0/P1. Open one docs PR, then create
one GitHub issue per plan step from .github/ISSUE_TEMPLATE/step.md in the change's milestone, and
an owner-checkpoint issue for H-0. Stop at H-0 (owner accepts the documents). Do not write code.
```

### 8.3 Final report of a change

```text
You are the Codex executor of Lingo. For <CHANGE>, write docs/changes/<CHANGE>/report.md:
every TAC with PASS / FAIL / NOT RUN and its evidence (PR, test name, fixture, screenshot),
the owner's open checks, known limits and the executor decisions. Update ROADMAP.md, the
architecture guides and AGENTS.md §1–3 if they changed. One docs PR, review, merge under §6;
then the owner-checkpoint issue for acceptance with a Russian checklist. Stop there.
```

## 9. Issue format

Step issues use [`.github/ISSUE_TEMPLATE/step.md`](../../.github/ISSUE_TEMPLATE/step.md): title `[<CHANGE> <step>] <what>`, labels
`area:*` + `type:*`, the change's milestone, and the sections Summary, Requirements, Depends on, Scope (files), Acceptance checks,
Out of scope, Definition of Done. Owner checkpoints carry the `owner-checkpoint` label and are never closed by Codex: the owner
closes them, or Codex closes them after recording the owner's written acceptance in `handoff.md`.
