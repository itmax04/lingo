# packages/contracts — the single source of truth between Swift and TypeScript

Status: current · Updated: 2026-11-03.

Everything here is **language-neutral data**. Both implementations (Swift in `apps/mac`, TypeScript in `packages/core-ts`,
`services/engine`, `apps/web`) are tested against these files. A behaviour change starts here: update the contract or fixture
in the same PR as both implementations; CI fails if either side diverges.

| Path | What | Used by |
|---|---|---|
| `events/event.schema.json` | Journal event, schema v1 (JSON Schema 2020-12) | Swift journal, TS reducer, engine `/api/sync` validation |
| `fixtures/events/sample-journal.jsonl` | One event of every type, written by the real Swift code (keys sorted) | round-trip tests: parse → serialize must give identical lines (Swift `JournalTests`, TS `packages/core-ts/test/events.test.ts`) |
| `fixtures/events/timestamps.jsonl` | Synthetic lines with odd milliseconds (`.001`, `.007`, `.999`, …) | round-trip tests in Swift (`TimestampContractTests`) and TS |
| `fixtures/events/merge-two-devices.input.jsonl` | Two devices, interleaved order, one duplicate | merge parity |
| `fixtures/events/merge-two-devices.expected.json` | Expected visible sessions, ordered messages (with `heard`, `interruptedAt`), starred keys | merge parity (Swift `Merger.build` produced it) |
| `fixtures/events/edge.jsonl` | Synthetic edge cases for the reducer (ties, replyTo, dedupe, ★ toggles, profile, undecodable payloads, unknown type) | Swift `MergerContractTests`, TS merge tests |
| `fixtures/events/sample-journal.state.json`, `merge-two-devices.state.json`, `edge.state.json` | Full reducer state (sessions, messages with segments and `heard`, fixes, hints, ★, profile, counters) without the vocabulary, written by Swift `MergerContractTests` (`LINGO_RECORD_FIXTURES=1`) | Swift `MergerContractTests`, TS `packages/core-ts/test/merge.test.ts` |
| `fixtures/protocol/replies.json` | Reply protocol (R-24) cases: synthetic replies with the Swift-written segments, violations, streamed speech items (R-13), spoken text and interruption prefixes (R-12) | Swift `ReplyProtocolContractTests`, TS `packages/core-ts/test/reply.test.ts` (both also check every chunk boundary) |
| `fixtures/commands/vocabulary.json`, `fixtures/commands/detect.json` | The command detector vocabulary and the detections (kind, argument) of every `evals/commands` phrase plus edge cases, written by Swift `CommandContractTests` | TS `packages/core-ts/test/commands.test.ts` (no drift, same detections) |
| `fixtures/voice/turns.json` | Utterances of every `evals/turn` timeline, segmenter event traces and VAD transitions on constant-level frames, written by Swift `VoiceContractTests` | TS `packages/core-ts/test/voice.test.ts` |
| `fixtures/vocab/text.json` | Normalisation, duplicate key and pasted-list parsing (LINGO-08 VR-03, VR-07a) | Swift `VocabularyTextTests`, the TS port |
| `fixtures/vocab/selection.json` | Which vocabulary items the model practises next (LINGO-08 VR-06) | Swift `VocabularyContractTests`, the TS port |
| `fixtures/vocab/matching.json` | Whether an utterance uses an item (VR-07b), with negative cases and accepted misses | Swift `VocabularyContractTests`, the TS port |
| `fixtures/vocab/events.jsonl` | One event of every vocabulary/profile type, written by the real Swift code | round-trip tests |
| `teacher/exams.json` | Original B1 and IELTS tasks; for the B1 exam also titles, Russian glosses, categories, the partner's talks with summaries, `goethePhrases` (keys `1`…`3`) and `goetheExaminerLines` (LINGO-10). Written by Swift `ExamTests` with `LINGO_RECORD_FIXTURES=1` | Swift catalogue validation; future TS teacher under D-01 |
| `teacher/scenarios.json` | Scenario catalogue (9 DE, 6 EN, tasks and titles), written by Swift `ScenarioTests` | Swift catalogue validation; future TS teacher under D-01 |
| `teacher/tone-lines.json` | LINGO-09 MR-21: local lines of a tone session (kinds × de/en × bands 1–5, profane variants for band 5), written by Swift `ToneLinesTests` | Swift catalogue validation; future TS teacher under D-01 |
| `fixtures/teacher/blame-markers.json` | LINGO-09 MR-15: blame marker words per study language (trailing `*` = prefix match, leading `*` = suffix match, e.g. `*fehler`), written by Swift `BlameFilterTests` from `BlameFilter.markers` | Swift filter; future TS port under D-01 |
| `fixtures/teacher/blame-filter.json` | LINGO-09 MR-15, MAC-07: golden cases of the blame filter (tone, language, raw reply, filtered text, removed count); hand-written | Swift `BlameFilterTests` |
| `fixtures/events/tone-filtered.jsonl` | LINGO-09 MR-15, MR-45: `tone.filtered` events, two valid and three malformed | Swift and TypeScript journal tests |
| `fixtures/teacher/tone-deny-list.json` | LINGO-09 MR-06/MR-47: words no local line may contain (whole words, `*` = stem); hand-written | Swift `ToneLinesTests` deny-list test |
| `fixtures/teacher/exam-events.jsonl` | All twelve exam phases (LINGO-10 adds four) and four malformed payloads, written by Swift `ExamTests` | Swift/TS round-trip and unknown-event count parity |
| `fixtures/teacher/goethe-scoring.json` | Goethe B1 letter-to-points table, zero rule and debrief parser golden cases (LINGO-10 BR-28, BR-29, BR-40), written by Swift `GoetheScoringTests` | Swift tests; TS shape test; a later web port |
| `fixtures/teacher/weekly-events.jsonl` | Two `report.weekly` events for one week and two malformed ones, written by Swift `WeeklyReportTests` | Swift/TS round-trip and unknown-event count parity |
| `fixtures/teacher/memory-events.jsonl` | Five valid `memory.*` events (two facts, an update, a removal, a switch) and four malformed ones, written by Swift `MemoryTests` | Swift/TS round-trip and unknown-event count parity |
| `prompts/prompt-exam-*.txt` | Examiner system rules and a maximal bounded `<exam>` block | Swift `ExamTests`; no live model calls (Q-03) |
| `api/openapi.yaml` | Engine HTTP API (sign-in, sync, lease, transcribe, turn SSE, budget, export, delete) | engine implementation, web client, later the Mac adapter |
| `prompts/` *(moved here in plan step P-01)* | System-prompt snapshots (today `Tests/LingoCoreTests/Snapshots/*.txt`) | Swift `PromptBuilderTests`, TS prompt builder tests — byte-identical |
| `evals/` *(moved here in P-01)* | `commands`, `turn`, `audio`, `dialog` eval sets (today `evals/`) | Swift `lingo-eval`, TS ports, the engine's eval runner |

Rules
- Fixtures are synthetic. No personal data, no keys, no real conversations.
- Never edit a golden fixture by hand to make a test pass; regenerate it from the reference implementation and explain why in the PR.
- The `ReplySegment` encoding (`{"say":{"_0":"de","_1":"…"}}`) is Swift's synthesized Codable format and is part of the contract.
- Swift and TS use their platform's Unicode data (Foundation vs Node/ICU); code points added in recent Unicode versions and a few
  lower-case mappings may differ. The fixtures use ru/de/en text where both agree.
- Golden fixtures were generated on 2026-10-26 from commit `1e254e7` with a temporary Swift test that used `JournalStore` and `Merger`.
