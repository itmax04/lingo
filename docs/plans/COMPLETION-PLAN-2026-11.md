# Completion plan — everything left to finish Lingo

Status: current · Version: 2 · Date: 2026-11-07 (v1: 2026-11-03) · Owner: itmax04 · Executor: Codex ([CODEX.md](../process/CODEX.md)) or Claude Code
Links: [ROADMAP](../ROADMAP.md) · [AGENTS.md](../../AGENTS.md) · [SDLC](../process/SDLC.md) · [audit 2026-11-07](../audits/AUDIT-2026-11-07.md)

This is the single ordered queue of the remaining work. Each row is one GitHub issue and one PR unless it says otherwise. The executor
works top to bottom and stops at every **H-x** (owner checkpoint). Changes after LINGO-05 have no accepted documents yet: their first
row is always "documents", and nothing after it starts before the owner's H-0.

v2 adds, from the [audit of 2026-11-07](../audits/AUDIT-2026-11-07.md): the unblocking of PR #84 (A-01), an early owner smoke test of
the teacher with the live model (H-05a, A-07), a small hardening track R1…R3 for privacy and quota (A-03…A-06), the owner acceptance
debt folded into H-05 (A-08), and size estimates for the later changes. Rows marked **proposal** need the owner's yes (§6).

## 1. Where things stand (2026-11-07)

- **Done and merged:** LINGO-01 (frozen), LINGO-07 redesign (#33), LINGO-03 Stage 0 (P-01…P-06, H-1 accepted 2026-10-31),
  LINGO-03 P-07a…P-07f (`packages/core-ts`, #56–#61), LINGO-08 vocabulary and prompting v2 (#50–#55),
  LINGO-05 documents (#67), T-1…T-5 (#68, #70–#73), T-6a1 (#82), T-6a2a (#83). Owner's app: build 203 at `1a67e90`.
- **Blocked:** PR #84 (T-6a2b, exam UI): independent review changes-required since 2026-11-04 — F-1 P1 (automatic journal selection
  cancels the first exam), F-2 P2 (typed Finish is taken as an exam answer). Its last `mac` CI run was cancelled, not failed.
- **Parked by the owner (2026-11-01, "Mac first"):** the web part of LINGO-03 (draft PR #62 P-07c2 and P-08…P-20).
- **Never run (owner decisions or skipped at acceptance):** any live model check of the teacher (Q-03); LINGO-08 E-1 (PAC-03, PAC-04);
  the 30-minute live session AC-17; backup/restore with the real buttons; the RU/EN walk-through; LINGO-01 formal H-5.
- **Owner decisions in force:** LINGO-05 Q-01…Q-04 (Mac now; all four blocks; no night evals; teacher before the new modes),
  CX-01…CX-03 ([CODEX.md](../process/CODEX.md) §1).

## 2. Queue

### A. LINGO-05 — finish the teacher on the Mac (milestone "LINGO-05 · Teacher", epic #29)

Requirements and TACs: [LINGO-05 spec](../changes/LINGO-05/spec.md). Step contents: [LINGO-05 plan](../changes/LINGO-05/plan.md).

| # | Step | Requirements | Depends on | Notes |
|---|---|---|---|---|
| A1 | T-6a2b exam UI — finish PR #84 (#74) | XR-02, PX-02…PX-05 | #83 | Fix F-1 (tell explicit navigation from the automatic selection of a just-created session; tolerate the `session.created` observer firing before `createSession` returns) and F-2 (route an unambiguous Finish through `finishSession` before the exam answer path; keep whole-utterance Done/Fertig as part completion). Regressions must register the real `store.observe → model.apply` callback, both exam languages, nil initial selection. Fresh re-review, green CI on the final head, merge, rebuild. Closes #74 |
| R1 | Privacy: no provider error text in the unified log | AGENTS §6.10 | — | Audit A-03 / F02. Log status, error kind, limit class only; the UI keeps the redacted text. Test: an error echoing an utterance never reaches `Log`. Small, can run in parallel with A1 (different files) |
| **H-05a** | **Owner: 15-minute smoke test of the teacher with the live model** (**proposal**) | — | A1, R1 | Daytime single requests, no batch (allowed by AGENTS §6.5; Q-03 forbids only night batches). Checklist: one warm-up, one DE scenario, one Goethe and one IELTS exam part, Finish; owner reports what felt wrong. Findings become fixes before A2 |
| A1f | Fixes from H-05a | as found | H-05a | 0…2 PRs; prompt snapshots re-recorded under rule 7 |
| A2 | T-6b exam debrief (#75) | XR-03, PX-04 (examFeedback) | A1 | moves the `no_pronunciation` markers into LingoCore; runtime filter |
| A3 | T-7 Progress screen and weekly report (#76) | GR-04, GR-05, PX-04 (weeklyReport) | T-2 | Swift Charts only; likely split engine/UI |
| A4 | T-8 memory (#77) | GR-06, PX-04 (memory), GR-07 card | T-4 | privacy-critical; review with extra care; likely split extraction/UI |
| A5 | T-9 reminder, docs, screenshots (#78) | GR-08, TAC-09, TAC-15 | A2…A4 | updates ARCHITECTURE, MAC.md, ROADMAP, AGENTS, contracts README |
| A6 | LINGO-05 report (#79) | all TAC-01…TAC-16 | A5 | `report.md` with evidence per TAC (CODEX.md §8.3) |
| **H-05** | **Owner: try the teacher and accept LINGO-05 (#80)** | — | A6 | Live `@grade`, `@task`, exams, debrief, memory, report, reminder. v2 also folds in the acceptance debt (audit A-08): one 30-minute real session (AC-17), backup → restore with the real buttons, a RU/EN look. One checklist, one sitting |

Estimate: 7–10 PRs (A1, R1, 0–2 fixes, A2, A3 ×1–2, A4 ×1–2, A5, A6).

### R. Hardening — quota correctness (after H-05, before LINGO-09; **proposal**)

Small Mac PRs that keep the 4 × 30 day honest before more model purposes and the web are added. Contracts first where TS mirrors them.

| # | Step | Notes |
|---|---|---|
| R2 | Admission estimate and unknown usage | Audit A-04/A-05 (F04, F06): reserve `input + maxTokens` (+ reasoning headroom where used), calibrated from the usage log; unknown usage counted and shown separately, never as 0 |
| R3 | Eval night gate | Audit A-06 (F03): Europe/Berlin, checked before every case, stop at 08:00. Only needed before the owner allows evals again |

### B. LINGO-09 — new conversation modes (after H-05; owner decision Q-04 "teacher, then the modes")

The owner named "HFL" and "Stand Your Ground" modes in the LINGO-05 brainstorm (2026-11-01). Their content is **not recorded in the
repository**: the executor must not guess it. B1 starts with the owner's description.

| # | Step | Notes |
|---|---|---|
| B1 | Documents: brainstorm (ask the owner what each mode is), intent, spec, plan, issues | CODEX.md §8.2; Mac first unless the owner says otherwise |
| **H-09-0** | **Owner: accept the LINGO-09 documents** | |
| B2… | Steps from the accepted plan | issues created in B1; estimate 3–5 PRs (modes reuse the scenario/exam activity plumbing) |
| **H-09-1** | **Owner: accept LINGO-09** | |

### C. LINGO-03 Stages 1–2 — Lingo Web and the engine (resume needs the owner)

Issues #10…#27 exist (milestones "LINGO-03 · Stage 1 — Evidence" and "Stage 2 — Lingo Web"). The documents were accepted at H-0, but
they predate LINGO-05/08 and the redesign; the teacher, vocabulary and prompting v2 now exist only on the Mac, and `core-ts` has no cards,
FSRS, statistics or teacher logic (audit A-11).

| # | Step | Notes |
|---|---|---|
| **H-03-R** | **Owner: resume the web** (unpark) | asked after H-05 or H-09-1, whichever the owner prefers |
| C1 | Spec amendment v3: web scope of LINGO-08 vocabulary and the LINGO-05 teacher (**owner choice**: "conversation + vocabulary first, teacher later" recommended, or full parity), DESIGN.md §9 rebased on v2 tokens, issues updated | docs PR; AI review; then H-0 of the amendment |
| C2 | P-07c2 (#62, draft): update by merging `main`, finish, review, merge | TS vocabulary parity |
| C3… | P-08…P-20 as issues #12…#26, with owner gates H-2 (#11), H-3 (#14), H-4 (#25), H-5 (#27) | night-only evals; deploys by the owner ([RELEASE](../process/RELEASE.md)) |
| C-T | Teacher on the web (only if C1 chooses it): TS ports of cards/FSRS, stats, warm-up, scenarios, exams, memory, with the existing fixtures as parity tests | +8–12 PRs |

Estimate: 15–18 PRs without the teacher, 25–30 with it.

### D. LINGO-04 — the Mac joins the account (after LINGO-03 H-5; epic #28)

| # | Step | Notes |
|---|---|---|
| D1 | Documents (STAGE-PROMPTS Prompt 5, written with CODEX.md §8.2): device tokens per ADR-0003 §5 (not device flow, upgrade plan F08), import, offline Mac; teacher events in the sync | stop at H-04-0 |
| D2… | Steps of the accepted plan; owner gates H-04-1, H-04-2 | the owner creates and pastes device tokens; estimate 4–6 PRs |

### E. LINGO-06 — native iPhone and real time (after LINGO-04; epic #30)

| # | Step | Notes |
|---|---|---|
| E1 | Documents (STAGE-PROMPTS Prompt 7, written with CODEX.md §8.2): free signing matrix, locked screen, real-time budget | stop at H-06-0 |
| E2… | Steps of the accepted plan; owner gates H-06-1…H-06-3 | the owner installs on iPhone Air and iPhone 11; reuses `LingoCore` (builds for iOS); estimate 6–10 PRs |

## 3. Order at a glance

```
A1 ─┬─ H-05a ─ A1f ─ A2 ─ A3 ─ A4 ─ A5 ─ A6 ─ H-05 ─ R2 ─ R3 ─ B (LINGO-09) ─ H-03-R ─ C (web) ─ D (LINGO-04) ─ E (LINGO-06)
R1 ─┘
```

A3 and A4 depend only on T-2/T-4 and may run in parallel worktrees once A2 is under review. Total remaining: about 40–60 PRs and
12–15 owner checkpoints.

## 4. What "finished" means

Lingo is finished when every change above has an accepted report (its last H-x closed by the owner), the ROADMAP shows all rows as done
or explicitly dropped by the owner, `main` is green, and the success metrics of the ROADMAP are measured (PASS, FAIL or NOT RUN with a
reason). The owner may stop after any change; the queue then simply ends there. A sensible stopping point is after H-05 + R2: a complete
Mac teacher with honest quota accounting.

## 5. Keeping the queue moving

- A step is done only when merged and the owner's app is rebuilt; a review with changes-required is picked up in the next session, not
  left open (audit A-12: #84 waited three days).
- Author and reviewer are separate fresh sessions; the reviewer posts the verdict as a PR comment (CODEX.md §5).
- A cancelled CI run is re-run once; it is neither PASS nor FAIL.
- The executor updates §1 and the rows' state in the same PR that finishes a row, and adds the issue numbers when it creates the issues
  of a new change.

## 6. Open owner decisions (asked in Russian, recommended option first)

| ID | Question | Recommended |
|---|---|---|
| CP-01 | Add the 15-minute live smoke test H-05a after A1? | Yes |
| CP-02 | Fold AC-17, backup/restore and RU/EN into the H-05 checklist? | Yes |
| CP-03 | Run the hardening R2/R3 before LINGO-09? | Yes (R1 privacy runs now regardless) |
| CP-04 | Web scope at resume (C1) | Conversation + vocabulary first, teacher later |
