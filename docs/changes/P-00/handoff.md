# P-00 active decision and adoption handoff

Date: 2026-10-29 (Europe/Berlin). Status at this build: adoption delta committed on branch `docs/p-00-adoption` (published as PR #35; the chain #1/#31/#34 was merged on 2026-10-31 under G-CHAIN); formal P-00 adoption on main is not claimed. No product implementation is completed.

## Actual owner decisions

| Decision | Date | Accepted scope |
|---|---|---|
| G-CHAIN | 2026-10-31 | Merge #1 → #31 → #34 in order after green CI and AI review; excludes #33 |
| DG-01 / H-U | 2026-10-29 | Upgrade amendment v1, reviewed P-00 annotations, stage prompts and source precedence; document acceptance only. |
| DG-02 / H-0 | 2026-10-29 | LINGO-03 intent/spec/plan v2 with reconciliation/execution annotations; requirements and plan acceptance, not runtime or device results. |
| DG-03 / A | 2026-10-29 | P00-GATES v1 intent/contract/risk/DoD and future own docs PR plus checked own merge. The owner clarified that AI checks remain and owner manual review is not required. |

Source: actual direct owner replies preserved in the self-contained SDLC packet. Receipt SHA-256: `aceeda3a5b925f126f4aef8e35593ec2bd30a5fe8b799e8e09fe199d3dfc9164`. Approved reference base: `22ec44de924f79eaa867c816c08276bb5c88484f`; patch SHA-256: `03906ce2571ad2f30c37460b18b36b1c32812fb6369ad4cd5a585fc292508ab6`; reference tree fingerprint: `5715153dbdaa728734ac5be1aebcc962cbf68dc18631ef2c16bad8d339b620ba`. These identify the accepted reference; acceptance-status edits create a separately hashed candidate and do not reuse reference hashes as new-result proof.

Current bounded execution plan: P00-ADOPTION-PLAN-03 v1, SHA-256 `c3cb420c5635f59554178d089f126c136cea8c21829a00dab2da1b771ae08428`; observable specification P00-ADOPTION-SPEC-02 v1, SHA-256 `3bef66fdd2ea23287cc8b9705d362a11620b6b5639520d546d624e3a97bacdeb`. Only the local adoption tasks (ADA-T01/T02/T03/T04/T07, named in the STAGE-PROMPTS Prompt 0 entry) execute in this build. The packet carries exact patches/manifests and actual check/review/recovery evidence; this ledger does not pre-assert their results.

## Authority and remaining boundaries

DG-03 A permits only the reviewed 15-document delta plus its explicit acceptance-status records inside those paths, on an own codex/ branch and own PR to compatible main, after current local checks, AI review, full publication-history secret scan, CI/workflow/base/diff and verified $0 conditions. No additional manual owner document review is required. The current build does not publish or merge.

Current main differs from the approved baseline across 44 paths, 35 outside the own 15. Existing PRs #1/#31/#34 were not merged by DG-03 A; they were merged on 2026-10-31 under the separate owner decision G-CHAIN, with green CI and independent AI review; #33 remains outside it. No import, retarget, edit or implicit merge of that chain, direct main push, force/history rewrite or protection bypass. Dependent publication waits for compatible scoped base resolution; local delivery may complete while it is blocked.

D04-01 retains AI-only implementation/review for R2/R3 without a mandatory human reviewer. Current R1 author self-review is not an independent AI release review. Preserve $0/no card, no secrets/audio/utterance diagnostics/pronunciation assessment, Russian first-run with Russian/English/System choices, offline read-only seeded fixtures and owner-run accounts/settings/production/migrations/devices. No future product/device/duration gate is closed; LINGO-07 precedes LINGO-03 Stage 0.

## Historical preparation handoff

The following record predates DG-01/DG-02/DG-03. Its then-pending decisions and preparation-only authority are historical; the active sections above supersede them. Original observations remain evidence of that preparation, not new tests.

### P-00 local documentary build handoff

Date: 2026-10-29. Source: docs/upgrade-plan 22ec44de924f79eaa867c816c08276bb5c88484f. Product cursor: P-00.
Status: local candidate prepared for verification; H-U/H-0 pending. Unapplied, unpublished; no LINGO-03 implementation completion.

P00-D01 freezes source/access and 30 issue mappings. P00-D02 reconciles targeted process/status/WS-09/Q1 records. P00-D03 assembles the candidate and exact-base final-docs.patch. D04 evidence and D05 transfer are in the accompanying phase-04 packet, identified by its PHASE-RESULT and file hashes; this file does not pre-assert a pending check PASS.

Current [review policy D04-01](review-policy-2026-10-29.md) supersedes the historical human requirement: AI-only implementation/review for R2/R3, no mandatory human reviewer. R1 author self-review is the current check level. The original phase-00/01/02/03 artifacts remain unchanged in the packet; derived English transport records carry the new policy explicitly.

The original 80 implementation rows/dependencies remain unchanged. Product requirements and ADRs are preserved except the explicit WS-09 fixture clarification, which retains read-only offline behavior. Russian first-run remains required; the redesign System default is an unresolved code gap. No Swift/TS/runtime/schema or visual asset changes, installs, provider/ImageGen calls, new CI runs, GitHub mutations or production operations.

Next: verify the exact local patch/candidate and all preparation AC in phase 05; return failures to build. Formal P-00 adoption, H-U/H-0 decisions and publication need separate recorded authority. Do not infer acceptance from packet readiness, tests or open/merged PRs. Future product/device/night/release checks remain NOT RUN here.
