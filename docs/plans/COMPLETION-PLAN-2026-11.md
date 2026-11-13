# Completion plan — everything left to finish Lingo

Status: current · Date: 2026-11-03 · Owner: itmax04 · Executor: Codex ([CODEX.md](../process/CODEX.md))
Links: [ROADMAP](../ROADMAP.md) · [AGENTS.md](../../AGENTS.md) · [SDLC](../process/SDLC.md)

This is the single ordered queue of the remaining work. Each row is one GitHub issue and one PR unless it says otherwise. Codex works
top to bottom and stops at every **H-x** (owner checkpoint). Changes after LINGO-05 have no accepted documents yet: their first row
is always "documents", and nothing after it starts before the owner's H-0.

## 1. Where things stand (2026-11-08)

- **Done and merged:** LINGO-01 (frozen), LINGO-07 redesign (#33), LINGO-03 Stage 0 (P-01…P-06, H-1 accepted 2026-10-31),
  LINGO-03 P-07a…P-07f (`packages/core-ts`, #56–#61), LINGO-08 vocabulary and prompting v2 (#50–#55),
  LINGO-05 documents (#67) and T-1…T-9 (#68, #70–#73, #82–#84, #86, #88–#91).
- **Accepted:** LINGO-05 (H-05, #80), by the owner on 2026-11-12; report in `docs/changes/LINGO-05/report.md`. Next: LINGO-09 (B1).
- **Parked by the owner (2026-11-01, "Mac first"):** the web part of LINGO-03 (draft PR #62 P-07c2 and P-08…P-20).
- **Owner priority since 2026-11-13: LINGO-11 — Lingo Web for friends** (section F below). New features are paused, including
  LINGO-09 (row B; its PRs #119 and #141–#145 stay open). LINGO-11 supersedes the web part of LINGO-03 (row C) once its documents
  are accepted at H-11-0.
- **GitHub:** stale Stage 0 issues #2–#7 and #9 closed with `gh` with links to their PRs (CX-03; #8 was already closed); #10 stays open for #62.
- **Owner decisions in force:** LINGO-05 Q-01…Q-04 (Mac now; all four blocks; no night evals; teacher before the new modes),
  CX-01…CX-03 ([CODEX.md](../process/CODEX.md) §1).

## 2. Queue

### A. LINGO-05 — finish the teacher on the Mac (milestone "LINGO-05 · Teacher", epic #29)

Requirements and TACs: [LINGO-05 spec](../changes/LINGO-05/spec.md). Step contents: [LINGO-05 plan](../changes/LINGO-05/plan.md).

| # | Step | Requirements | Depends on | Notes |
|---|---|---|---|---|
| A1 | T-6a exam runner (#74) | XR-01, XR-02, PX-02, PX-03, PX-05 | T-5 | likely split: catalogue + engine, then UI |
| A2 | T-6b exam debrief (#75) | XR-03, PX-04 (examFeedback) | A1 | moves the `no_pronunciation` markers into LingoCore |
| A3 | T-7 Progress screen and weekly report (#76) | GR-04, GR-05, PX-04 (weeklyReport) | T-2 | Swift Charts only |
| A4 | T-8 memory (#77) | GR-06, PX-04 (memory), GR-07 card | T-4 | privacy-critical; review with extra care |
| A5 | T-9 reminder, docs, screenshots (#78) | GR-08, TAC-09, TAC-15 | A1…A4 | updates ARCHITECTURE, MAC.md, ROADMAP, AGENTS, contracts README |
| A6 (done, in review) | LINGO-05 report (#79) | all TAC-01…TAC-16 | A5 | `report.md` with evidence per TAC (CODEX.md §8.3) |
| **H-05** | **Owner: try the teacher and accept LINGO-05 (#80)** | — | A6 | live model behaviour of `@grade`, `@task`, exams, debrief, memory, report, the reminder |

### B. LINGO-09 — new conversation modes (after H-05; owner decision Q-04 "teacher, then the modes")

The owner named "HFL" and "Stand Your Ground" modes in the LINGO-05 brainstorm (2026-11-01). Their content is **not recorded in the
repository**: Codex must not guess it. B1 starts with the owner's description.

| # | Step | Notes |
|---|---|---|
| B1 | Documents: brainstorm (ask the owner what each mode is), intent, spec, plan, issues | CODEX.md §8.2; Mac first unless the owner says otherwise |
| **H-09-0** | **Owner: accept the LINGO-09 documents** | |
| B2… | Steps from the accepted plan | issues created in B1 |
| **H-09-1** | **Owner: accept LINGO-09** | |

### C. LINGO-03 Stages 1–2 — Lingo Web and the engine (superseded by section F when H-11-0 is passed)

Issues #10…#27 exist (milestones "LINGO-03 · Stage 1 — Evidence" and "Stage 2 — Lingo Web"). The documents were accepted at H-0, but
they predate LINGO-05/08 and the redesign; the teacher, vocabulary and prompting v2 now exist only on the Mac.

| # | Step | Notes |
|---|---|---|
| **H-03-R** | **Owner: resume the web** (unpark) | asked by Codex after H-05 or H-09-1, whichever the owner prefers |
| C1 | Spec refresh: a v3 amendment of the LINGO-03 spec that adds the LINGO-08 vocabulary and the LINGO-05 teacher to the web scope (or explicitly leaves them out), rebases DESIGN.md §9 on v2 tokens, and updates the issues | docs PR; AI review; then H-0 of the amendment |
| C2 | P-07c2 (#62, draft): rebase-free update by merging `main`, finish, review, merge | TS vocabulary parity |
| C3… | P-08…P-20 as issues #12…#26, with owner gates H-2 (#11), H-3 (#14), H-4 (#25), H-5 (#27) | night-only evals; deploys by the owner ([RELEASE](../process/RELEASE.md)) |

### D. LINGO-04 — the Mac joins the account (after LINGO-03 H-5; epic #28)

| # | Step | Notes |
|---|---|---|
| D1 | Documents (STAGE-PROMPTS Prompt 5, written with CODEX.md §8.2): device tokens per ADR-0003, import, offline Mac | stop at H-04-0 |
| D2… | Steps of the accepted plan; owner gates H-04-1, H-04-2 | the owner creates and pastes device tokens |

### E. LINGO-06 — native iPhone and real time (after LINGO-04; epic #30)

| # | Step | Notes |
|---|---|---|
| E1 | Documents (STAGE-PROMPTS Prompt 7, written with CODEX.md §8.2): free signing matrix, locked screen, real-time budget | stop at H-06-0 |
| E2… | Steps of the accepted plan; owner gates H-06-1…H-06-3 | the owner installs on iPhone Air and iPhone 11 |

### F. LINGO-11 — Lingo Web for friends (current; owner priority 2026-11-13)

Documents: [intent](../changes/LINGO-11/intent.md), [spec](../changes/LINGO-11/spec.md), [plan](../changes/LINGO-11/plan.md),
[ADR-0008](../decisions/ADR-0008-web-for-friends.md). Row C is superseded by this section when H-11-0 is passed; row D (LINGO-04)
then follows LINGO-11 instead of LINGO-03 H-5.

| # | Step | Notes |
|---|---|---|
| F0 | Documents, provider CORS check, AI review, docs PR | done, this PR |
| **H-11-0** | **Owner: accept the LINGO-11 documents** | also decides whether CX-02 covers the LINGO-11 plan: CX-02 was given for the steps of this plan as it stood on 2026-11-03, so the executor does not apply it to section F without the owner's word (LINGO-11 intent A-13) |
| F1… | Steps F-1…F-24 of the accepted plan, with owner gates H-11-1 (core on devices), H-11-2 (strict tutor order), H-11-3 (deploy), H-11-4 (acceptance) | issues and milestones are created after H-11-0 |

## 3. What "finished" means

Lingo is finished when every change above has an accepted report (its last H-x closed by the owner), the ROADMAP shows all rows as done
or explicitly dropped by the owner, `main` is green, and the success metrics of the ROADMAP are measured (PASS, FAIL or NOT RUN with a
reason). The owner may stop after any change; the queue then simply ends there.

## 4. Keeping this file true

Codex updates the "Where things stand" section and the rows' state in the same PR that finishes a row, and adds the issue numbers when
it creates the issues of a new change.
