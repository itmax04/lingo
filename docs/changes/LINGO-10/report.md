# LINGO-10 report: Goethe B1 Sprechen on the Mac (G-6, issue #103)

Date: 2026-11-12. Branch `feat/103-goethe-g6` (PR #115) from `origin/main` `c115f9c` (#114 merged). Scope of G-6: fix the open items of the
independent review of #114 (N1–N4), the live debrief checks, the architecture documents, and this report. H-10 (#104) is the owner's
checkpoint and is not started here.

## 1. Result in one table

| Part | Status | Evidence |
|---|---|---|
| Review items N1–N4 of #114 | PASS (tests pass; N1 test not checked by a revert run) | §2 |
| Live debrief checks (three single daytime requests, signed app) | **NOT RUN** | §3 |
| `docs/architecture/MAC.md`, `CODEBASE.md` for Goethe code | done | this PR |
| This report and `handoff.md` | done | this PR |
| Full Swift test run | 436 tests passed; process exit 1 after the run (see §4) | §4 |
| `check-english`, `secret-scan`, `check-design`, `check-core-ios` | PASS | §4 |
| IELTS snapshots and IELTS assertions unchanged (BAC-20) | PASS | §5 |

## 2. Review items of #114

Changed: `apps/mac/Sources/LingoMac/ExamServices.swift`, `apps/mac/Tests/LingoMacTests/GoetheMockHostTests.swift`.

- **N1** (`startExam`): the start captures `model.mockPrep?.startedAt` before the await and marks the preparation failed only if that
  stamp is unchanged. Test: `aStaleStartDoesNotFailANewerPreparation`. By reading, it fails without the fix (the cancelled start marks
  the newer preparation failed at its 50 ms check); a revert experiment was not run, so this is not verified by a failing run.
- **N2** (`finishMockPrep`): the start refusal is checked before any change, for Done and for Retry alike (the old code skipped the check
  for a failed preparation). Test: `aRefusedRetryChangesNothingAndSaysWhy` (readOnly → banner, preparation still failed and ended).
- **N3** (`discardMockPrep`): the shutdown runs only when `mockPrep == nil` as well. Test: `aNewerPreparationKeepsTheVoiceWhenAnOlderDiscardRuns`
  (a new preparation begun before the shutdown task keeps `turn`).
- **N4**: strict assertions in `aStartCancelledByNavigationDuringCreationLeavesARetryablePreparation` (failed, ended, notes kept, no
  running start); new test `discardingThePreparationWithoutAnExamShutsTheVoiceDown` (discard without an exam shuts the voice down).

Result of the Goethe host suite: `swift test --filter GoetheMockHostTests`: 15 tests passed, 0 failed.

## 3. Live debrief checks (BAC-21): NOT RUN

Reason: the signed app has no diagnostic flag that runs one debrief request on synthetic transcripts. The existing flags are
`--eval-dialog` (a bulk dialogue evaluation, night only under AGENTS.md §6.5), `--ui-goethe` and other `--ui-*` snapshot flags, and
`--check-keys`. No change adds such a flag here (scope), so the three single requests were not made. The owner's keys were not used.
BAC-21 stays open until a flag exists or the owner runs the three requests at H-10.

## 4. Checks at the reviewed head

- `swift test --package-path apps/mac`: `✔ Test run with 436 tests in 85 suites passed`. The process then exited with status 1: the
  whisper/ggml Metal backend aborted in its destructor during process exit (`ggml_abort` in `ggml_metal_device_free`, signal 6), after
  every test had passed. Not verified against `main` in this session.
- `scripts/check-english.sh`: `check-english: PASS`
- `scripts/secret-scan.sh`: `0 findings`
- `python3 scripts/check-design.py`: `design: PASS (19 exact color tokens, 88 computed contrast pairs, 652 bilingual strings)`
- `apps/mac/scripts/check-core-ios.sh`: `check-core-ios: PASS`

## 5. BAC table

Status words: PASS = checked in this session with the output above; COVERED = a test in the repository covers it, re-run in this session
as part of the 436 tests; NOT RUN = not checked here, with the reason; OPEN = needs H-10 or the owner.

| BAC | Status | Evidence / reason |
|---|---|---|
| BAC-01 | COVERED | catalogue unit tests (`GoetheCatalogTests`) in the 436 |
| BAC-02 | PASS | `git diff origin/main --stat` lists only two files outside docs (`ExamServices.swift`, `GoetheMockHostTests.swift`); no IELTS catalogue file changed |
| BAC-03 | COVERED | `GoetheActivityTests` |
| BAC-04 | COVERED | `GoetheRunTests`, `ExamTests` |
| BAC-05 | COVERED | `ExamHostTests` (microphone during preparation, Examiner lines) |
| BAC-06 | NOT RUN | audio regression test not re-run in G-6; no audio in this session |
| BAC-07 | PASS | `GoetheMockHostTests` (15 tests): topic choice, partner topic, abandon leaves no session, failed creation keeps notes |
| BAC-08 | COVERED | `GoetheRunTests`, `ExamHostTests` |
| BAC-09 | COVERED | voice tests in `ExamHostTests`; snapshot not re-shot in G-6 |
| BAC-10 | COVERED | `PromptBuilder` prompt tests in `GoetheRunTests` |
| BAC-11 | COVERED | notes are cleared on stop (`doneCreatesTheSession…`); code path review at G-5b |
| BAC-12 | COVERED | `GoetheDebriefTests` |
| BAC-13 | COVERED | `GoetheScoringTests`, `goethe-scoring.json` |
| BAC-14 | COVERED | engine tests of G-4 |
| BAC-15 | COVERED | `GoetheScoringTests`, `GoetheDebriefTests` (filter) |
| BAC-16 | PASS | `russianShortcutHasNoEffectDuringAMockButWorksInTraining`, `trainingKeepsTheAidsAndALiveTrainingLocksStarts` |
| BAC-17 | **PARTIAL: ±4 pt NOT measured** | Structure compared with the mockup for the preparation screen only (G-5b handoff). ±4 pt was **not measured**; differences listed in §6. Snapshot evidence in `evidence/g5a`, `evidence/g5b`; the Russian `ru-*` images show English text (the snapshot binary ignores `--ui-language ru`), so Russian layout is not visually checked. Re-shoot from `dist/Lingo.app` NOT RUN in G-6 |
| BAC-18 | NOT RUN in G-6 | no TypeScript change in G-6; `npm test` last run at G-1 (304 passed) |
| BAC-19 | COVERED | `GoetheHubTests`, `GoetheCatalogTests` (legacy ids); the pinned-18 validator test was an open P3 for G-2, not re-checked here |
| BAC-20 | PASS | no IELTS snapshot and no IELTS assertion edited in this change (§6) |
| BAC-21 | **NOT RUN** | §3 |
| BAC-22 | OPEN | peak memory during a Mock with two voices: `metrics.py` at H-10 |
| BAC-23 | OPEN | owner tries one Mock and one Training at H-10 (#104) |

## 6. Caveats and open items

- BAC-17: the ±4 pt criterion (DESIGN.md §8) is not met-measured. Differences found so far: Done and Finish are smaller than in the
  mockup; the Teil 1/2 cards use German task text only (BR-20). The mockup's Russian task text is content, not copied.
- Open P3 from review of #113 and #114 that were not part of N1–N4: F2 (fixed in G-5b), F3 (one-message Mock counts all three
  tasks as practised, BR-34 wording, owner decision), F4 (timer during `ending` shows only a banner), F5 (`onFailure` has no
  controller identity check), F6 (BAC-11 has no recorded-request test), F8 (Debriefs date is the last event). Not changed in G-6.
- The IELTS path was not touched: no IELTS snapshot, no IELTS assertion, no IELTS catalogue file.
- The debrief is a single request per finished session. Live behaviour with the real model was not tested in G-6.
