# LINGO-08 handoff

Status: documents v2 in review (PR #50); V-1 core in review (PR #51). Updated 2026-10-31.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Brainstorm | — | — | Owner decisions Q-01…Q-05 in intent.md (2026-10-31) |
| Documents v1 → v2 | #50 | AI review of v1: changes required (F-01…F-19) → spec v2 | v2 fixes: stable targets (stats before the session), detection against all items, matching rules for German/English (separable verbs, participles, placeholders, endings), optional settings fields and a focus flag instead of a new mode, eval rules, budget with MR-02, profile frozen per session, data tags |

## Executor decisions
- D-01 (VR-09): "My words" is the "Questions" mode with `vocabularyFocus`, so older builds keep showing the session (review F-16).
- D-02 (PR-09): the prompt compaction open in LINGO-03 (P-02b) is done inside P-1, against the MR-02 target, measured by provider tokens.

## Next step
Apply spec v2 to the V-1 branch (matching, ★ ids, `message` in `vocab.used`, de-duplication, final removal, stats before a session,
list parsing rules, text fixtures), re-review, merge; then V-2.
