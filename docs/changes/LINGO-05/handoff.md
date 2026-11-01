# LINGO-05 handoff

Status: documents merged (#67); T-1 in PR #68. Updated 2026-11-01.

## Done
| Step | PR | Checks | Notes |
|---|---|---|---|
| Documents v1 | #67 | AI review: changes-required (F-01…F-18) | Owner decisions Q-01…Q-03 in intent.md (2026-11-01): Mac now, all four blocks plus useful additions, no night evals |
| Documents v1.1 | #67 | AI re-review: approve-with-notes (no P0/P1); notes N-01…N-18 applied | All findings answered (the spec v1.1 header lists where); Q-04: the teacher goes before the new HFL / Stand Your Ground modes |
| T-1 cards and FSRS | #68 | `swift test` PASS (220); `npm test` PASS (287); check-core-ios, check-english, secret-scan PASS; FSRS vs py-fsrs 5.1.3 test expectations PASS; the reviewer's independent formula script reproduced `fsrs.json` (27 states, 0 mismatches); py-fsrs itself NOT RUN; AI review approve-with-notes, notes F-1…F-9 applied | 621 changed lines without fixtures (86 of them pretty-printed schema JSON), slightly above the 600 guideline, accepted as stated in the PR |

## Executor decisions
- D-01 (intent): TS ports of cards, FSRS, statistics and memory deferred to the web work; contracts and core-ts event/tag support now.
- FSRS reference: py-fsrs 5.1.3 (`fsrs/fsrs.py`, `tests/test_basic.py`) read from GitHub. Running the downloaded reference code was
  blocked by the agent environment, so the Swift port is checked against the reference's published test expectations instead of
  vectors produced by the reference itself. Optional for the owner: `pip install fsrs==5.1.3` and compare `fsrs.json`.

## Next step
Merge PR #68, then T-2 (statistics core, `goal.set`, goal per day and streak, `stats.json`).
