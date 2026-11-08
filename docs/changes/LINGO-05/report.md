# LINGO-05 report: Teacher on the Mac

Date: 2026-11-08. Base: `main` at `82357ac` (T-1…T-9 merged). Issue: #79. Next: owner checkpoint H-05 (#80).

## 1. Verdict

All sixteen acceptance criteria (spec §7) are implemented on the Mac and covered offline: **TAC-01…TAC-16 PASS offline**, with the parts that need a live model, a real notification or the owner's hands marked NOT RUN in the table (owner decision Q-03: no live batches). Nothing in this report is a live-model result.

Re-run for this report on `82357ac`:

| Check | Result |
|---|---|
| `swift test --package-path apps/mac` | PASS, 347 tests, 75 suites |
| `npm ci && npm test` | PASS, 304 tests |
| `apps/mac/scripts/check-core-ios.sh`, `scripts/check-english.sh`, `scripts/secret-scan.sh`, `python3 scripts/check-design.py` | PASS (design: 578 bilingual strings); at merge time of each PR as listed in the evidence files |

## 2. Steps and pull requests

| Step | Issue | PR | Evidence |
|---|---|---|---|
| Documents | — | #67 | intent, spec, plan |
| T-1 cards and FSRS | — | [#68](https://github.com/itmax04/lingo/pull/68) | handoff "Done" |
| T-2 statistics, goal, streak | — | [#70](https://github.com/itmax04/lingo/pull/70) | handoff "Done" |
| T-3 warm-up engine | — | [#71](https://github.com/itmax04/lingo/pull/71) | handoff "Done" |
| T-4 Today, Teacher, warm-up flow | — | [#72](https://github.com/itmax04/lingo/pull/72) | handoff "Done" |
| T-5 scenarios | — | [#73](https://github.com/itmax04/lingo/pull/73) | handoff "Done" |
| T-6a1 / T-6a2a / T-6a2b exam runner | #74 | [#82](https://github.com/itmax04/lingo/pull/82), [#83](https://github.com/itmax04/lingo/pull/83), [#84](https://github.com/itmax04/lingo/pull/84) | [t6a1](evidence/t6a1-mac-checks.md), [t6a2a](evidence/t6a2a-mac-checks.md), [t6a2b](evidence/t6a2b-mac-checks.md) |
| T-6b exam debrief | #75 | [#86](https://github.com/itmax04/lingo/pull/86) | [t6b](evidence/t6b-mac-checks.md) |
| T-7 progress and weekly report | #76 | [#88](https://github.com/itmax04/lingo/pull/88) | [t7](evidence/t7-mac-checks.md) |
| T-8 memory | #77 | [#89](https://github.com/itmax04/lingo/pull/89) | [t8](evidence/t8-mac-checks.md) |
| T-9a reminder | #78 (part) | [#90](https://github.com/itmax04/lingo/pull/90) | [t9a](evidence/t9a-mac-checks.md) |
| T-9b docs, screenshots | #78 (rest) | [#91](https://github.com/itmax04/lingo/pull/91) | [t9b](evidence/t9b-mac-checks.md) |

T-6a1 and later PRs were squash-merged after green CI and an independent review without open P0/P1 (owner decision CX-02, CODEX.md §6; #89 by the owner). T-1…T-5 and the documents (#67) were merged earlier by merge commit, each after an AI review with its findings applied.

## 3. Acceptance criteria

Tests are in `apps/mac/Tests/LingoCoreTests/` unless stated; fixtures in `packages/contracts/`. "Suite" means the file named; the table does not list individual test names. Each criterion passed in the suite run of the PR that delivered it and in the full run above.

| TAC | Result | Evidence | Not covered / NOT RUN |
|---|---|---|---|
| 01 cards | PASS | `TeacherCardTests` (13) | — |
| 02 FSRS | PASS | `TeacherCardTests`; `fsrs.json`; reviewer's independent formula script reproduced it (0 mismatches over 27 states) | py-fsrs itself was not run (the agent environment blocked running downloaded reference code); the Swift port is checked against the reference's published test expectations. Optional for the owner: `pip install fsrs==5.1.3` and compare |
| 03 due queue | PASS | `TeacherCardTests`, `WarmupTests` | — |
| 04 warm-up | PASS | `WarmupTests` (22) | Live `@grade` quality NOT RUN (Q-03, H-05) |
| 05 scenarios | PASS | `ScenarioTests` (8); `teacher/scenarios.json`; screenshots in [t9](evidence/t9/) | Live `@task` marking NOT RUN (Q-03, H-05) |
| 06 exams | PASS | `ExamTests` (8), `ExamControllerTests` (8), `ExamDebriefTests` (10), host tests in `LingoMacTests/ExamHostTests.swift`; `teacher/exams.json`; screenshots [t6a2b](evidence/t6a2b/), [t6b](evidence/t6b/) | Real VoiceIO startup/restart, live exam and live debrief quality, live `no_pronunciation` eval NOT RUN |
| 07 statistics | PASS | `StatsTests` (6); `stats.json`, `stats.input.jsonl` | — |
| 08 memory | PASS | `MemoryTests` (19); `memory-events.jsonl` (Swift/TS parity in `npm test`); a test greps the touched files for logging | Live extraction quality NOT RUN (Q-03, H-05) |
| 09 screens | PASS | `check-design` (578 strings); `LingoMacTests/PresentationTests.swift`; screenshots RU/EN light/dark in [t6a2b](evidence/t6a2b/), [t6b](evidence/t6b/), [t7](evidence/t7/), [t8](evidence/t8/), [t9](evidence/t9/) | Screens were rendered from synthetic fixtures, not from the owner's journal |
| 10 compatibility | PASS | `WarmupTests` (unknown activity kind = nil) and the tolerant-decoding tests of each step's suite (cards, statistics, memory, weekly report); old journals decoding unchanged was checked in each step's review, not by one dedicated suite | — |
| 11 protocol | PASS | `ReplyProtocolContractTests`, `ReplyProtocolTests`; TS `reply.test.ts` with the shared fixture | — |
| 12 weekly report | PASS | `WeeklyReportTests` (15); `weekly-events.jsonl` | Live advice quality NOT RUN (Q-03, H-05) |
| 13 next activity | PASS | `TodayTests` (7) | — |
| 14 end card, suspension | PASS | `TodayTests` (end-card counts and next due time), `TeacherCardTests` (suspended cards leave the queue); screenshots in [t9](evidence/t9/) | — |
| 15 reminder | PASS (scheduling decisions) | `ReminderTests` (5) | The real notification NOT RUN. The day-change, wake and activation re-sync and the serialised syncs (PR #90 F1–F3) have no automated test; they were reviewed and are for the owner to try |
| 16 requests, prompt | PASS | `PromptBuilderTests` (snapshots in `packages/contracts/prompts/`), `PromptV2Tests`, `MemoryTests`/`WeeklyReportTests`/`ExamDebriefTests` for the per-purpose request caps | — |

## 4. Open owner checks (H-05, #80)

Live behaviour of `@grade`, `@task`, exams, debrief, memory extraction, weekly advice and a real reminder notification; a normal day of practice within quota. The checklist is posted on #80.

## 5. Known limits accepted in reviews

- T-3 R-4: "Reply again" on an answer that ended in an unrated-limit skip names the newer card.
- T-3 R-6: `warmupNamedNext` is memory-only; after a restart a card set up after the deadline is dropped and the warm-up ends.
- T-3: TS `decodeSettings` drops `activity` (the web decodes it when it implements the warm-up, D-01).
- T-8 F5: a removed fact blocks the key of its final text only.
- T-7 review notes F2 (fixture advice vs chart trend) and F3 (neutral chart colours) are not done; both would change the T-7 screenshots. They are cosmetic and stay open as a follow-up if the owner wants them.
- PR #90 notes N1–N4 (P3): no automated test for the reminder observers and serialisation; observers are never removed (the object lives for the app's lifetime).
- Several PRs exceeded the ~600-line guideline (T-1 slightly; T-6a2a and T-6a2b by owner-requested review fixes); stated in each PR.
- Web and engine do not implement the teacher yet (LINGO-03 is parked, "Mac first"); the contracts are ready for it (rule 9).

## 6. Executor decisions

D-01…D-08 are in [handoff.md](handoff.md); D-09…D-12 (memory) are in [the T-8 evidence](evidence/t8-mac-checks.md). Owner decisions Q-01…Q-04 are in [intent.md](intent.md).

## 7. Risks from the plan and how they ended

- **Free quota:** teacher requests follow PX-04 caps and skip rules (TAC-16); no live batches were run (Q-03). Real consumption over a day is an H-05 check.
- **Pronunciation rule (product rule 7):** exam debrief and weekly advice pass a shared filter that drops marker lines (TAC-06, TAC-12); the live `no_pronunciation` eval is NOT RUN.
- **Privacy:** audio is not stored; memory text and learner lines are never logged (TAC-08).
- **Model compliance with silent protocol lines:** the decoder tolerates absent or malformed `@grade`/`@task` lines (TAC-11); real compliance is H-05.
