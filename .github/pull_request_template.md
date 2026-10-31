## What and why
<!-- One or two sentences. Link the issue: Closes #… -->

Plan step: `LINGO-__ P-__` · Requirements: `MR-__` / `WR-__` / `WAC-__`

## How it was checked
<!-- Real commands and their output summary. PASS / FAIL / NOT RUN. -->
- [ ] `swift test` (Mac) — …
- [ ] `npm test` (TS) — …
- [ ] `scripts/check-english.sh` — …
- [ ] `scripts/secret-scan.sh` — 0 findings
- [ ] Device / eval checks (if any) — …

## Definition of Done (docs/process/SDLC.md §6)
- [ ] Scope matches the issue; nothing extra slipped in
- [ ] Tests added/updated
- [ ] Shared behaviour changed? → `packages/contracts` fixtures updated, Swift and TS both pass
- [ ] `handoff.md` updated (step, checks, executor decisions)
- [ ] ARCHITECTURE / ADR / contracts updated if structure changed
- [ ] No new dependency outside the ADR allow-lists
- [ ] UI: screenshots attached, DESIGN.md tokens only, RU and EN strings
- [ ] Free-tier impact stated (requests, tokens, D1 writes) if non-trivial
- [ ] No secrets, personal data or audio in the diff

## Screenshots / evidence
<!-- UI screenshots, metric excerpts (no utterance text, no keys). -->

## For the owner
<!-- State what changed and what the owner should review. -->
