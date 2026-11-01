# LINGO-05 handoff

Status: documents v1.1 written (answers to the AI review of v1), in re-review. Updated 2026-11-01.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Documents v1 | #67 | AI review: changes-required (F-01…F-18) | Owner decisions Q-01…Q-03 in intent.md (2026-11-01): Mac now, all four blocks plus useful additions, no night evals |
| Documents v1.1 | #67 | AI re-review pending | All findings answered (the spec v1.1 header lists where); Q-04: the teacher goes before the new HFL / Stand Your Ground modes |

## Executor decisions
- D-01 (intent): TS ports of cards, FSRS, statistics and memory deferred to the web work; contracts and core-ts event/tag support now.
- FSRS reference: py-fsrs 5.1.3 (`fsrs/fsrs.py`, `tests/test_basic.py`) read from GitHub. Running the downloaded reference code was
  blocked by the agent environment, so the Swift port is checked against the reference's published test expectations instead of
  vectors produced by the reference itself. Optional for the owner: `pip install fsrs==5.1.3` and compare `fsrs.json`.

## Next step
Re-review of intent/spec/plan v1.1, merge, then T-1 (cards and FSRS; the port and its py-fsrs checks already pass in the T-1 worktree).
