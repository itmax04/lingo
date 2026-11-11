# LINGO-10 handoff: Goethe-Zertifikat B1 Sprechen on the Mac

## Identity
- Change: LINGO-10 (LINGO-09 is already reserved for new conversation modes). Risk proposal: R2. No GitHub issue yet.
- Worktree and branch: `.claude/worktrees/keen-spence-171b93`, `claude/keen-spence-171b93`, HEAD `030eaa3` (same as `origin/main` on 2026-11-09).
- Uncommitted: this file, `intent.md`, `spec.md`, `plan.md`, `docs/ROADMAP.md` and `design/goethe-b1-2026/` (the owner's two ImageGen mockups). Nothing else. Do not commit or push unless the owner asks.
- Phase: documents v1.1 accepted by the owner on 2026-11-09, including the assumptions listed under Open. Implementation not started; no code yet. The uncommitted files exist only in this worktree, so continue here. No code before the owner approves them.

## Goal and scope
Adapt the Goethe-Zertifikat B1 Sprechen exam into the Teacher on the Mac. Done for this stage means `docs/changes/LINGO-10/` holds intent, spec and plan, an independent AI review of those documents has run, and the work stops for the owner's approval before any code.

Hard constraints: no copied exam material (LINGO-05 XR-01); no pronunciation assessment (AGENTS.md §6.7); $0; the IELTS exam stays unchanged; DESIGN.md wins over the mockups; talk to the owner in Russian and write repository files in English.

Out of scope, paused by the owner until this is finished: custom training timer, own-vocabulary mode with PDF and pasted material, the exam title reading "Free conversation: …". H-05 (#80) stays open and independent.

## Owner decisions (2026-11-09, answered "yes" to all recommendations)
| ID | Decision |
|---|---|
| Q1 | Simulate the pair exam. Lingo is the partner, plans Teil 1, reacts to the learner's talk and asks a question, and reads its own pre-written talk from the catalogue; the learner gives feedback and asks a question. |
| Q2 | Goethe only: A-E per criterion and points per Teil, with no overall total and no pass or fail. The model returns only the letter; the app computes the points. Keep the "practice estimate" note. This replaces the B1-B2 ranges of XR-03 for Goethe. |
| Q3 | No 4-week plan now. An exam-date plan is a later, separate feature. |
| Q4 | 12 original tasks per part with categories (for example Alltag, Arbeit, Freizeit, Umwelt, Gesundheit). The six existing tasks and their ids stay. |
| Q5 | Exam screen reached from Teacher with Training (any single Teil, hints on, immediate corrections) and Mock exam (15 min preparation with notes and a choice of two topics, unassessed introduction of about 1 min, Teil 1, Teil 2, Teil 3 with answers on the learner's own talk and then feedback and a question on the partner's talk; no Hints, Translate or In Russian; strict timers; debrief at the end). |
| Q6 | Training has only Teil 1, Teil 2 and Teil 3. The mockup's "Whole exam" segment is dropped. |
| Q7 | A "Debriefs" tab: a plain list (date, mode, topic) that opens the stored session with its debrief card. No charts. |
| Q8 | No stars and no search. Keep category chips and the real per-task practice count from the journal. |
| Q9 | "Useful phrases for Teil N": about 10 original phrases per Teil in the catalogue, Training only. |
| Q10 | "My presentation plan" is the same notes field, also available in Training Teil 2. |
| Q11 | Mock exam task content is German only; Russian glosses stay in Training; the interface stays Russian. Teil 2 timer 4 min, labelled "3-4 min". |

## Mockup review (`design/goethe-b1-2026/`)
Matches DESIGN.md on colours, flat surfaces and no pronunciation rating. Corrections the executor applies without asking: page title 24 pt; right panel 272 pt and collapsing below 1280 pt; tabs locked during a running mock; notes stay on screen for the whole exam and stay on the Mac (never sent to a model). Live Teil and debrief screens have no mockup and build on the existing conversation view under DESIGN.md. The exact ImageGen prompt lives in the parent session; DESIGN.md §8 asks to preserve it, so request it if it should be stored.

## Facts
Official format: see the section "Goethe B1 Sprechen: official format" of the LINGO-05 handoff (`.claude/worktrees/exam-stuck-finishing-handoff-b3e193/docs/changes/LINGO-05/handoff.md`, uncommitted there; read only). Sources: [Durchführungsbestimmungen B1](https://www.goethe.de/pro/relaunch/prf/de/Durchfuehrungsbestimmungen_B1.pdf), [Übungssatz Erwachsene](https://www.goethe.de/pro/relaunch/prf/materialien/B1/B1_Uebungssatz_Erwachsene.pdf), [Modellsatz Sprechen](https://bfu.goethe.de/b1_mod/sprechen.php).
- Maxima, confirmed on the Modellsatz page: Teil 1 Erfüllung 8, Interaktion 4, Wortschatz 8, Strukturen 8 (28); Teil 2 12, 4, 12, 12 (40); Teil 3 Erfüllung 16; Aussprache 16 over all parts. Without Aussprache the honest maximum is 84.
- The Durchführungsbestimmungen allow only the listed point values per criterion (no intermediate values).
- Letter-to-points mapping, confirmed on Übungssatz Erwachsene p. 48 ("Sprechen - Bewertung", columns A to E): maximum 4 is 4/3/2/1/0; 8 is 8/6/4/2/0; 12 is 12/9/6/3/0; 16 is 16/12/8/4/0. The printed values are the points; no later multiplier is stated.
- Criteria: Teil 1 Erfüllung, Interaktion, Wortschatz, Strukturen; Teil 2 Erfüllung, Kohärenz, Wortschatz, Strukturen; Teil 3 Erfüllung (Übungssatz pp. 47-48). The older Modellsatz page says Interaktion for Teil 2; follow the Übungssatz.
- Rule to spec: E on Erfüllung of Teil 1 scores 0 points and makes that task's total 0 (Übungssatz p. 47, footnote).
- The sheet is dated 08/2014 and the Übungssatz 10/2017. The Durchführungsbestimmungen of 2025-09-01 (p. 10 §5) keep the fixed values and give no per-criterion table, so the mapping is the latest available, not a 2025 statement.

Code findings at `030eaa3`:
- `ExamRun`: fixed phases per kind, `validSelection` requires exactly 3 linked ids, `goethe2` is 180 s. Mock and Training need a format and subsets; new `ExamPhase` raw values must be additive (journal `exam.part`), with `packages/contracts/events/event.schema.json`, `packages/core-ts/src/events/payloads.ts` and fixtures updated in the same PR (AGENTS.md §6.9).
- `Activity` (`SessionSettings.swift`): add optional fields only, so older sessions decode.
- `examBlock` caps the exam data at 700 scalars, so a full partner talk cannot be sent; the catalogue needs a short talk summary for prompts. Field limits of XR-01 need an extension for the talk.
- `examinerRule` is one constant and suspends spoken corrections; Training needs its own rule and snapshot. Mock keeps silent `@fix`.
- `ExamDebrief`: 4 global criteria and `examFeedbackMaxTokens` 900. Goethe needs 9 criteria per Teil, learner turns grouped by part through `exam.part` events, the introduction excluded, points computed by the app, and a fallback when the letters cannot be parsed. The pronunciation filter stays.
- `SpeechSink.speak` takes a `voiceID` per utterance. The Mac has 10 German voices, including Petra (Premium).
- `MainView` shows `VoicePanel` extras and `InputBar` during exams; `ExamServices.startExam(kind)` starts directly from `TeacherView`. Debriefs are stored as `summary` messages and rendered in `ChatViews`.

## Done (2026-11-09)
- `intent.md` (Q1-Q19, assumptions A-01...A-13), `spec.md` v1.1 (BR-01...BR-42, BAC-01...BAC-23), `plan.md` v1.1 (G-1...G-6 with G-5a and G-5b, H-10), and a LINGO-10 row in `docs/ROADMAP.md`.
- Source check, Übungssatz Erwachsene read with PDFKit: the asterisk for "E makes the task 0" is on the Aufgabe 1 Erfüllung row only (p. 47), and the point table matches (p. 48). "Ohne Auto" appears on p. 28, so the mockup's topic "Ohne Auto leben" is official material and is excluded (BR-06, A-10).

## Verified
At HEAD `030eaa3`, with the uncommitted documents above:
- `scripts/check-english.sh`: `check-english: PASS`.
- `scripts/secret-scan.sh`: `0 findings`.
- NOT RUN: build and tests; no code changed.
- `sdlc:reviewer`, `documents` mode on the three files: first verdict changes-required with 3 P1 (F-01 Training could not give corrections because the other exam prompt branches forbid them; F-02 the partner would repeat the Examiner's question; F-03 the rollback claim was false for Mock sessions with new ids) and 17 P2/P3. All 20 were answered in v1.1. The reviewer's re-check: F-01, F-02 and F-03 closed, no new P0/P1, verdict approve-with-notes. The P2/P3 fixes were not re-reviewed.
- Executor decision on F-01: rule 4b keeps its exam text in Training, so the model does not abandon the task; the reviewer agreed.
- NOT RUN: originality of the catalogue against the official sources; it is a check of plan step G-2.

## Open
Executor assumptions the owner has not seen yet, to list in the report: A-01 (Mock session created at the end of preparation), A-02 (partner's talk after the answers on the learner's own talk), A-03 (partner talks on the topic not chosen), A-04 (notes in memory for one run only), A-05 (Training timers are soft), A-06 (Examiner lines not stored), A-07 (Debriefs lists only new sessions), A-09 (strengths and improvements per Teil), A-12 (no notes in Training Teil 1), A-13 (what an older build does after a rollback).
DESIGN.md §8 asks to keep the exact ImageGen prompt; it is in the parent session, and plan step G-5b stores it.

## Owner decisions, round 2 (2026-11-09, answered "yes" to all recommendations)
| ID | Question | Decision |
|---|---|---|
| Q12 | Length of the partner's talk | About 3 min, about 400 words; a mock is then about 30 min |
| Q13 | Voices | Two: Examiner in the learner's voice, partner in a different installed German voice; the same voice with a label when only one is installed |
| Q14 | Partner's talk text | Hidden in Mock; visible with replay in Training; notes editable while listening |
| Q15 | Order in Mock | Learner presents first, then the partner; fixed |
| Q16 | Training Teil 3 | Listen to a partner's talk, give feedback and ask a question, then answer one question on the topic |
| Q17 | Training debrief | One request at the end, A-E and points for that Teil only |
| Q18 | Early finish and failures | Debrief only finished parts, marked incomplete; if letters cannot be parsed, show the text without points; existing Retry stays |
| Q19 | Mock controls and introduction | Done may end a part early, the timer moves on otherwise; no typing in Mock; introduction is scripted with no model call and is excluded from the debrief |

## Next
1. Commit the documents and `design/goethe-b1-2026/` only when the owner asks, then create the issues of plan steps G-1...G-6.
2. Start G-1 (data and contracts) on its own branch: tests, independent AI review and green CI before merge, per `plan.md`.
3. If the owner changes a decision or an assumption, update the documents and record it here before any code.

## G-1 (data and contracts), 2026-11-09
- Docs PR [#96](https://github.com/itmax04/lingo/pull/96); issues #97 (G-1), #98 (G-2), #99 (G-3), #100 (G-4), #101 (G-5a), #102 (G-5b), #103 (G-6), #104 (H-10), milestone "LINGO-10 · Goethe B1 Sprechen". G-1 is [#105](https://github.com/itmax04/lingo/pull/105), stacked on #96 (retarget to `main` after #96 merges). Nothing is merged: CX-02 covers the completion-plan steps only.
- Checks at the reviewed head: `swift test --package-path apps/mac` 361 tests passed; `npm test` 304 passed; `apps/mac/scripts/check-core-ios.sh` PASS; `check-english` PASS; `secret-scan` 0 findings. No IELTS snapshot or assertion edited (BAC-20); the only existing-test edit is the exam-events length 12 → 16 in TS.
- Independent review (`sdlc:reviewer`, pr mode): approve-with-notes, no P0/P1/P2. P3 fixed: schema `format`/`teil` constraints dropped (tolerant readers), contracts README, `[T+1]` header, BR-29 wording (points kept without headers). Open P3 for G-2: `olderBuildRollbackShape` is weak until new ids exist; add a real pinned-18-ids validator test (BAC-19) in G-2.
- CI: `hygiene` and `test` green. `swift-test`: the two ChainTests timing failures are fixed by #107 (merged into this branch); after that, run 42670299754 failed only on `TurnControllerTests.s05MergeCancelsAndCombines` (a wall-clock/timing test, 22 s on the slow runner, unrelated to G-1; passes locally, 362 tests). Earlier runs failed on other `TurnControllerTests` the same way (#107 CI, passed on rerun). Follow-up: make `TurnControllerTests` independent of runner speed.

## G-2 (catalogue content), 2026-11-09
- Worktree `~/Developer/lingo-98`, branch `feat/98-goethe-catalogue` (pushed), stacked on `feat/97-goethe-data-contracts` (`f5177c0`, PR #105 still open, as is #109). Content commit `dab35b2`. No PR yet: it is opened after the review fixes, so that the mac workflow (x10 minutes) runs once.
- Content: `apps/mac/Sources/LingoCore/Teacher/GoetheContent.swift` (titles, glosses and categories of the 12 planning tasks; 12 topics with gloss, category, `talkSummary` and a talk of five paragraphs, one per slide, joined by a line break; 10 phrases per Teil; 7 Examiner lines). `Exams.swift`: six new planning tasks and six new topics appended after the originals, `GoethePhrase`, `GoetheExaminerLine` (raw values are the `exam.part` value the line opens, plus `goethe_b1.intro.end`), `ExamCatalog.goethePhrases(teil:)`, `goethePhrasesByTeil`, `goetheExaminerLines`. Export: `exams.json` gained the top-level keys `goetheExaminerLines` and `goethePhrases`; the IELTS entries stay the tail of the file.
- Executor decisions: D-G2-1 the topic string is the title of a talk and of its discussion task; D-G2-2 phrases and Examiner lines use the formal Sie; D-G2-3 talks avoid a gendered speaker where possible, because the partner's voice may be male or female; D-G2-4 talks hold no digits, quotes, brackets or abbreviations (they are read by a speech voice), which a test enforces.
- Official sources read on 2026-11-09 for BR-06: Übungssatz Erwachsene (speaking sheets pp. 25-28 and the moderation transcript p. 46, read from the PDF with PDFKit) and the Modellsatz speaking page (read in a browser, titles from the slide images' alt text). Official titles: a trip to Cologne to plan, a wedding topic, "Ohne Auto leben", a hospital visit to plan, children and mobile phones, children and television; the exact strings are the deny-list in `GoetheCatalogTests.officialTitles`. The Durchführungsbestimmungen were NOT re-read in this session (the fetch tool refused the domain); the earlier session reported regulations only.
- Checks at `dab35b2`: `swift test --package-path apps/mac` 371 tests passed; `npm test` 304 passed; `check-core-ios.sh` PASS; `check-english` PASS; `secret-scan` 0 findings.
- BAC-01: `GoetheCatalogTests` (9 tests) pass: 12 linked tasks per part, categories at least 2 each per part (part 1: freizeit 3, alltag 2, arbeit 3, umwelt 2, gesundheit 2; parts 2 and 3: umwelt 3, alltag 3, freizeit 2, arbeit 2, gesundheit 2), talks 370-391 words, summaries at most 300 characters, the 18 original tasks pinned by a hash of `030eaa3`, no official title.
- BAC-02: `ieltsEntriesAreByteIdentical` passes (SHA-256 of the IELTS tail of `030eaa3`), and `diff` of the tail from the first IELTS entry against `030eaa3` is empty (393 lines).
- BAC-19: `olderBuildRollbackShape` now runs a validator restricted to the 18 pinned ids (the open P3 of G-1).
- Independent review (`sdlc:reviewer`, branch mode, code + originality against the Übungssatz and Modellsatz + German level): approve-with-notes, no P0/P1. Fixed: F-1 (P2) the Teil 3 Examiner line is now order-neutral so it fits Mock and Training; F-2/F-3 Teil 3 and Teil 1 wording moved away from the official instructions; F-4 deny-list extended with official task fragments; F-7 inclusive "Praktikantinnen und Praktikanten", "Hilfe finden", "Tempo für Einsteiger"; F-8 three style nits in the talks. Not changed: F-5 `olderBuildAccepts` simulates the pre-LINGO-10 validator (BAC-19 is a simulation, adequate because the 18 ids are hash-pinned); F-6 (`?? ""`, guarded by the `examinerLines` test). Originality is proven only against the Übungssatz and Modellsatz; the Durchführungsbestimmungen and other official sets were not compared.
- Second review pass (fresh `sdlc:reviewer`, no P0/P1, approve-with-notes), fixed in `5238469`: Teil 3 line reworded (order-neutral for Training and Exam), screens talk no longer pairs children with a phone, keyword guard in `noOfficialTitleAndNoPronunciation` (official-theme stems; children with Handy/Fernseher inside one sentence), club/courses/Examiner wording; `exams.json` re-recorded. Open P3: all twelve talks share one skeleton (vary openings later), no "du" phrase in Teil 1 (D-G2-2 keeps Sie). Not verifiable by the reviewer: Examiner intro/thanks against the official moderation transcript. Checks: `swift test` 371, `npm test` 304, check-core-ios, check-english, secret-scan 0 — all PASS. PR [#110](https://github.com/itmax04/lingo/pull/110).
- Checks after the fixes (`exams.json` re-recorded): `swift test` 371 passed; `npm test` 304 passed; `check-core-ios.sh` PASS; `check-english` PASS; `secret-scan` 0 findings. BAC-02 `ieltsEntriesAreByteIdentical` passes.

## Next
1. Take the reviewer's findings on `dab35b2`, fix every P0/P1 (and cheap P2/P3 wording fixes), re-record `exams.json` with `LINGO_RECORD_FIXTURES=1 swift test --package-path apps/mac --filter ExamTests`, rerun all five checks, and record the verdict above.
2. Push and open the PR against `feat/97-goethe-data-contracts` ("Closes #98" only if the base is `main`; otherwise "Part of #98"), with BAC-01 and BAC-02 output. A red `swift-test` that fails only in `TurnControllerTests` is the known flake until #109 is merged. The owner merges; agents cannot run `gh pr merge`.
3. Stop after G-2. G-3 (#99, exam engine, tier strong) starts in a new session.

## G-3 (exam engine), 2026-11-10 … 2026-11-11
- Worktree `~/Developer/lingo-99`, branch `feat/99-goethe-exam-engine`, stacked on `feat/98-goethe-catalogue` (PR #110; #105 and #96 also open; the owner merges). Commits: code `5a3a22e`, merge of `origin/fix/108-turn-tests` (PR #109, test-only) `f6559d1`, review fixes `b18d542`.
- Done: `ExamRun` (format, teil, partnerTask, phases per format, `task`, `role`, `endsAtZero`, `examinerOpening`, `restart`, `ownTalk` ids, `sentences`); `ExamController` (`start(format:teil:partnerTask:)`, `speak` closure, `voices`, `speaker`, `replyVoice`, `replayTalk`, Examiner lines via `line`/`open`, partner's talk via `talk`/`stopTalk`, Mock Teil 3 via `answer`, `goethe_b1.end` only at a natural end); `ExamVoices.pick` (BR-23); `ExamCatalog.valid` shared by settings, run and the activity decoder; prompts (`goetheTrainingRule`, `examBlock` with role/format, `examOwnTalk`, Training uses the non-exam text of rules 5, 6, 8 and the protocol); `TurnController.speakExam` and the partner's voice in `runTurn`; host wiring in `ExamServices.attachExam`, `AppModel.examSpeaker`, a speaker label in `ExamPanel` (catalog strings "Examiner", "Partner"). `goethe2` is 240 s. New snapshot `prompts/prompt-exam-goethe_b1-training.txt`. Tests: `GoetheRunTests.swift` (13 tests).
- Executor decisions: D-G3-1 in Training `goethe_b1.3` the Examiner speaks the Teil 3 line and then the catalogue question (the BR-07 table names only the question); D-G3-2 the Mock Teil 3 request finds the learner's talk by message ids kept in `ExamRun.ownTalk` (G-4's grouping by `exam.part` may replace it); D-G3-3 no host entry starts a Mock or a Training yet (G-5a/G-5b); `startExam` still starts the legacy run; D-G3-4 existing tests changed only in Goethe values (180 → 240 s in `ExamTests`, `GoetheActivityTests`, deadlines 181 → 241, audio case 240 added, monologue list gains the intro) and `FakeSink` records voice ids.
- D-G3-5 (2026-11-11): Pause does nothing while an Examiner line or the partner's talk is spoken; Esc, Space and the microphone button in continuous mode, a bubble click and turning continuous mode off leave that speech alone too (BR-10). Done, Replay of the talk, Finish and `ExamController.stop` still end it.
- Independent review (`sdlc:reviewer`, branch mode, `git diff origin/feat/98-goethe-catalogue..5a3a22e`, 2026-11-11): changes-required with 1 P1, 3 P2, 4 P3; after the fixes in `b18d542` no P0/P1 is open. The fixes were not re-reviewed by a second independent pass.
  - F-1 (P1, was C-1) fixed: `TurnController` counts running exam speech (`examSpeech`); `cancel`, the pause branch of `togglePause`, `replay` and `interrupt` return while it is set; `stopVoice(cancelTurn: true)` stops the sink itself. Test `hostControlsDoNotStopAnExaminerLineOrTheTalk` (fails without the fix).
  - F-2 (P2) fixed: `open()` clears `userWaiting`, so an answer cut off by a part's end is not answered by the first empty transcript of the next part. Test `anAnswerCutOffByThePartEndIsNotAnsweredInTheNextPart` (fails without the fix).
  - F-3 (P2) fixed in code, NOT verified on real audio: `VoiceIO.enqueue` now moves a phrase from `pendingSynth` to `pendingBuffers` under one lock (and drops it if a stop happened during the conversion), so `isSpeaking` has no false gap before a single-phrase line plays. `VoiceIO` has no unit test; check at the owner's try-out that the microphone does not open under the Examiner's voice.
  - F-4 (P2) fixed: tests `doneDuringTheGreetingOrTheThanksIsAppliedAfterTheLine`, `mockTimersWaitForAReplyACaptureAndALineAndTheTalkHasItsSafetyLimit` (zero during a reply, a capture and the Teil 3 question line; Done during that line; the 300 s safety limit; feedback ends at zero), `replayRestartsATalkThatIsStillBeingSpoken`.
  - F-5 (P3) documented in `examOwnTalk`, not changed: unused budget of short lines is not redistributed; beyond about 97 lines the tail is cut; a silent Teil 2 sends the usual window.
  - F-6 (P3, was C-2) fixed: the test asserts the content between the tags within 700 scalars (the block itself is at most 715, as before this change).
  - F-7 (P3) fixed: a replayed reply of a run with a format keeps the partner's voice (asserted in the host-controls test).
  - F-8 (P3) open, for G-5a/G-5b: `ExamPanel` disables Done while `busy`, so Done during the talk cannot be pressed; `replayTalk` has no caller; the label reads "Part 1" for the intro and "Part 2" for the partner and feedback parts.
  - Not proven in G-3 (host work of G-5): talk not shown, microphone closed in the Mock preparation, notes, the panel snapshot naming the speaker (BAC-04/05/08/09 host clauses).
- Checks at `b18d542`: `npm test` 304 passed; `check-core-ios.sh` PASS; `check-english` PASS; `secret-scan` 0 findings; `GoetheRunTests` 18 passed. Full `swift test`: PASS, 389 tests in 81 suites passed (384 at `81a687e` plus the five new ones), including the 240 s audio case (BAC-06). `check-english` and `secret-scan` were rerun after this handoff commit before the push.
- Size: about 310 source lines plus about 515 lines of `GoetheRunTests.swift`.
- Tooling note: the SDLC Bash hook rejects any command containing the word for Swift's access keyword that matches the protected path pattern; edit such files with the editor tools.

## Next
1. The PR of G-3 against `feat/98-goethe-catalogue` is open ("Part of #99"); the owner merges. Rebase onto `main` once #96, #105 and #110 are merged. Watch the `swift-test` workflow of that PR.
2. Then G-4 (#100, debrief, tier standard) in a new session.
