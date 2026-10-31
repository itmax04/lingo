# P-00 — Intent: adopt the accepted upgrade plan

Risk: R1 (documents only). Authority and boundaries: [handoff.md](handoff.md) is the ledger; this file adds only the 2026-10-31 decision.

## Goal
Land the reviewed 15-document adoption delta (base `22ec44d`, `docs/upgrade-plan`) so the repository records the accepted upgrade plan,
the DG-01/02/03 acceptance and the AI-only review policy (D04-01). No product code, schema, contract, ADR or workflow changes.

## Decisions
| ID | Date | Owner's words / source | Effect |
|---|---|---|---|
| DG-01/02/03 | 2026-10-29 | "I accept H-U", "I accept H-0", "A; without my review, the AI checks remain" (translated from Russian) | See handoff.md |
| D04-01 | 2026-10-29 | AI-only review for R2/R3 | See review-policy-2026-10-29.md |
| G-CHAIN | 2026-10-31 | "I accept" (Russian, translated; recommended option: merge #1 → #31 → #34 in order after green CI and AI review, then the own docs PR) | Resolves the base blocker in handoff.md; applies only to #1/#31/#34, not #33 |

## Scope
- In: the 15 reviewed Markdown paths plus this intent (record of the G-CHAIN decision; no requirement text).
- Out: product code; LINGO-07 and LINGO-03 work; #33; any merge outside the G-CHAIN order and checks.

## Definition of done
Local checks pass; independent AI review has no open P0/P1 on the chain PRs and the own PR; chain merged in order with green CI;
own PR (rebased on the new main) merged after CI.
