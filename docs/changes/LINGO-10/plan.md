# LINGO-10: Plan

ID: LINGO-10-plan · Status: accepted by the owner (2026-11-09) · Version: 1.1 (AI review F-13, F-19 answered) · Date: 2026-11-09 · Risk: R2 · Links: [intent.md](intent.md) · [spec.md](spec.md) · [handoff.md](handoff.md)

**No code before the owner approves these documents (H-0 of this change).** One step = one issue and one PR (≤ 600 changed lines without snapshots, fixtures and catalogue content), each with
tests, an independent AI review and green CI before merge. Swift work is done locally on the owner's Mac (AGENTS.md §10). Batch macOS CI runs, because they count ×10 against the free minutes. Model calls during development: single daytime
requests only. Tier = model tier of the step: strong (design, hard debugging), standard (implementation from this plan), light (mechanical edits, docs).

| Step | Content | Requirements | Checks | Tier |
|---|---|---|---|---|
| G-1 | Data and contracts: `Activity.format`, `teil`, `partnerTask` with tolerant decoding; new `ExamPhase` values; new optional task fields; scoring table and parser; schema, TS payloads, event fixtures, `goethe-scoring.json`. No behaviour change | BR-01, BR-02, BR-02a, BR-04 (fields), BR-28, BR-29, BR-38, BR-39a, BR-40 | BAC-03, BAC-13, BAC-18, BAC-19, BAC-20, `swift test`, `npm test`, `check-core-ios.sh` | standard |
| G-2 | Catalogue content: six new tasks per part; titles, glosses and categories for all; 12 talks with summaries; phrases; Examiner lines; export to contracts; independent review of originality and German level against the sources | BR-03…BR-06 | BAC-01, BAC-02 | standard |
| G-3 | Exam engine: Mock and Training runs in `ExamRun` and `ExamController`, strict and soft timers, Examiner lines, the partner's talk, microphone rules, 240 s monologue, voice selection, role texts and `<exam>` changes, `goetheTrainingRule` | BR-07, BR-09…BR-15, BR-17, BR-18, BR-23…BR-25 | BAC-04…BAC-06, BAC-08…BAC-10, BAC-20 | strong |
| G-4 | Debrief: grouping by part, Goethe request and limits, finished parts, filters, stored text parsed for the card, legacy path kept | BR-26…BR-32, BR-39 | BAC-12…BAC-15, BAC-19, BAC-20 | standard |
| G-5a | Goethe screen, part 1: Teacher entry, tabs, Training tab and right panel, useful phrases, Debriefs list, debrief card, RU and EN strings. New screen: the owner's frontend rules apply (DESIGN.md first) | BR-16, BR-19, BR-30, BR-33…BR-36 | BAC-16, BAC-17, `check-design`, snapshots | standard |
| G-5b | Goethe screen, part 2: Mock tab and preparation, locking for the whole run, notes in the exam panel, Mock aids off incl. ⌥R. Commit `design/goethe-b1-2026/` with the exact ImageGen prompt (from the parent session) and the mockup-against-implementation evidence in both themes (DESIGN.md §8) | BR-08, BR-08a, BR-20…BR-22, BR-37 | BAC-07, BAC-11, BAC-16, BAC-17, snapshots | standard |
| G-6 | Live checks and documents: three daytime debrief requests through a diagnostic flag of the signed app; `MAC.md`, `CODEBASE.md`; `report.md` with evidence for every BAC | BR-41, BR-42 | BAC-20, BAC-21 | light |
| H-10 | Owner checkpoint: one Mock and one Training on the Mac; memory reading; acceptance | | BAC-22, BAC-23 | owner |

Order: G-1 → G-2 → G-3 → G-4 → G-5a → G-5b → G-6 → H-10. G-2 comes before G-3, because G-3's flow tests need talks and Examiner lines. G-5a and G-5b start after G-3, because they attach to the new run states; G-4 comes before G-5a, because they share the debrief card.

## Risks
| Risk | Mitigation |
|---|---|
| The model breaks the letter format, so no points appear | Strict format with codes, parsing per Teil, text shown without points (BR-29), Retry, BAC-21 before H-10 |
| The partner's replies drift from the pre-written talk | `talkSummary` in `<exam>` (BR-24a); the learner hears the talk once in Mock |
| Quality of about 4 800 words of original German (12 talks) | Independent review in G-2; talks kept simple at B1; the owner hears them at H-10 |
| Accidental use of official material | Test list of official titles, independent comparison in G-2 (BR-06); the mockup's topic names are not used |
| A second voice costs memory | Premium avoided for the partner (BR-23), BAC-22 |
| Quota: larger debrief | One request per run, limits under the 8 000 TPM per model (BR-27), Retry only by click |
| A 4-minute monologue exceeds the speech buffer | Retention derived from the phase (BR-07), BAC-06 |
| Regression of IELTS | No re-recording of its snapshots allowed (BR-41, BAC-20) |
| Older build or rollback reading new sessions | Additive fields, tolerant decoding, BR-39a |
