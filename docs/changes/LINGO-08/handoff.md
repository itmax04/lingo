# LINGO-08 handoff

Status: documents v2.1 merged (PR #50); V-1 core reworked to v2.1, in re-review (PR #51). Updated 2026-10-31.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Brainstorm | — | — | Owner decisions Q-01…Q-05 in intent.md (2026-10-31) |
| V-1 core | #51 | PASS: `swift test` 170 tests in 47 suites (golden fixtures text, matching 37 cases incl. accepted misses, selection 5 cases incl. pinned and mistakes, events round-trip; merge permutations and duplicates; final removal; same text from two devices; stats before a session; mistake outcome by fix span; old journals unchanged; validated edits); `check-core-ios` PASS; fixtures validate against the schema; `check-english`, `secret-scan --no-history` PASS | AI review of the first version: changes required (F1–F9) → reworked with spec v2.1. The selection fixture case 1 changed from v1 (rule "mistakes first" added in v2). Fixtures are not yet validated in CI (no workflow step). Re-review: changes required (R1 P1: a removed text could not be added again; R2 German stems differed from the spec; R3 worst-case matcher time; R4 a long single item was cut, not rejected; R5 minor) → fixed: removal tombstones every older add of that key and a later add is a new item (VR-02, schema), stems and endings written into VR-07b (5-letter verbs `gehen`, `sagen`, `leben`, `anrufen` now match; English `d` ending removed), bullets only before a space, placements computed once + English memo + German step budget (accepted miss), single items over 120 characters rejected and edits refused; 172 tests PASS. |
| Documents v1 → v2 | #50 | AI review of v1: changes required (F-01…F-19) → spec v2 | v2 fixes: stable targets (stats before the session), detection against all items, matching rules for German/English (separable verbs, participles, placeholders, endings), optional settings fields and a focus flag instead of a new mode, eval rules, budget with MR-02, profile frozen per session, data tags |

## Executor decisions
- D-01 (VR-09): "My words" is the "Questions" mode with `vocabularyFocus`, so older builds keep showing the session (review F-16).
- D-02 (PR-09): the prompt compaction open in LINGO-03 (P-02b) is done inside P-1, against the MR-02 target, measured by provider tokens.

## Next step
Merge V-1 after the re-review; then V-2 (settings fields, detection after each turn, recognition hint).
