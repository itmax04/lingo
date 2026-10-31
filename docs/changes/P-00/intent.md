# P-00 — Intent: adopt the accepted upgrade plan

Status: accepted by the owner (DG-01 H-U, DG-02 H-0, DG-03 = A on 2026-10-29). Risk: R1 (documents only).

## Goal
Land the reviewed 15-document adoption delta (base `22ec44d`, `docs/upgrade-plan`) so the repository records the accepted
upgrade plan, the DG-01/02 acceptance and the AI-only review policy (D04-01). No product code, schema, contract, ADR or workflow changes.

## Scope
- In: the 15 Markdown paths of the adoption candidate; this intent; the `/sdlc:run` process wording.
- Out: product code, LINGO-07 and LINGO-03 work, any merge of #1/#31/#34/#33 without gate G-CHAIN.

## Decisions
- Q-01 (2026-10-29, owner): DG-03 = A — own docs PR and its merge after AI checks; no manual owner review of documents.
- Q-02 (2026-10-29, owner): D04-01 — AI-only review for R2/R3.
- A-01: the PR is stacked on `docs/upgrade-plan` (PR #34) because main differs from the base in 44 paths; it lands after G-CHAIN.

## Definition of done
`scripts/check-english.sh` and `scripts/secret-scan.sh` pass; independent AI review has no open P0/P1; PR is open, CI green,
stacked on #34; merge only after G-CHAIN.
