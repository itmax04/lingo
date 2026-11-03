---
name: Plan step
about: One step of a change's plan — one branch, one PR (docs/process/CODEX.md §9)
title: "[LINGO-NN T-x] "
labels: ""
assignees: ""
---

### Summary
<!-- What this step delivers, in two or three sentences. -->

**Change:** `docs/changes/LINGO-NN/` · **Plan row:** T-x · **Risk:** R2
**Requirements:** <!-- IDs from spec.md only, e.g. XR-01, PX-03 -->
**Depends on:** <!-- issues or merged PRs -->

### Scope (files and modules)
- 

### Acceptance checks
- [ ] <!-- TAC-xx: what proves it (test name, fixture, screenshot) -->
- [ ] `swift test --package-path apps/mac` PASS · `apps/mac/scripts/check-core-ios.sh` PASS
- [ ] `npm test` PASS (if contracts or core-ts change)
- [ ] `python3 scripts/check-design.py` PASS (if UI strings change)
- [ ] `scripts/check-english.sh` and `scripts/secret-scan.sh` PASS

### Out of scope
- 

### Definition of Done
- [ ] Acceptance checks above with real output in the PR
- [ ] `handoff.md` updated (Done row, executor decisions, Next step)
- [ ] Independent review in a fresh session without open P0/P1; verdict and SHA in a PR comment
- [ ] CI green; squash-merged under CODEX.md §6; owner's app rebuilt (Mac steps)
