# packages/contracts — the single source of truth between Swift and TypeScript

Everything here is **language-neutral data**. Both implementations (Swift in `apps/mac`, TypeScript in `packages/core-ts`,
`services/engine`, `apps/web`) are tested against these files. A behaviour change starts here: update the contract or fixture
in the same PR as both implementations; CI fails if either side diverges.

| Path | What | Used by |
|---|---|---|
| `events/event.schema.json` | Journal event, schema v1 (JSON Schema 2020-12) | Swift journal, TS reducer, engine `/api/sync` validation |
| `fixtures/events/sample-journal.jsonl` | One event of every type, written by the real Swift code (keys sorted) | round-trip tests: parse → serialize must give identical lines (Swift `JournalTests`, TS `packages/core-ts/test/events.test.ts`) |
| `fixtures/events/merge-two-devices.input.jsonl` | Two devices, interleaved order, one duplicate | merge parity |
| `fixtures/events/merge-two-devices.expected.json` | Expected visible sessions, ordered messages (with `heard`, `interruptedAt`), starred keys | merge parity (Swift `Merger.build` produced it) |
| `fixtures/vocab/text.json` | Normalisation, duplicate key and pasted-list parsing (LINGO-08 VR-03, VR-07a) | Swift `VocabularyTextTests`, the TS port |
| `fixtures/vocab/selection.json` | Which vocabulary items the model practises next (LINGO-08 VR-06) | Swift `VocabularyContractTests`, the TS port |
| `fixtures/vocab/matching.json` | Whether an utterance uses an item (VR-07b), with negative cases and accepted misses | Swift `VocabularyContractTests`, the TS port |
| `fixtures/vocab/events.jsonl` | One event of every vocabulary/profile type, written by the real Swift code | round-trip tests |
| `api/openapi.yaml` | Engine HTTP API (sign-in, sync, lease, transcribe, turn SSE, budget, export, delete) | engine implementation, web client, later the Mac adapter |
| `prompts/` *(moved here in plan step P-01)* | System-prompt snapshots (today `Tests/LingoCoreTests/Snapshots/*.txt`) | Swift `PromptBuilderTests`, TS prompt builder tests — byte-identical |
| `evals/` *(moved here in P-01)* | `commands`, `turn`, `audio`, `dialog` eval sets (today `evals/`) | Swift `lingo-eval`, TS ports, the engine's eval runner |

Rules
- Fixtures are synthetic. No personal data, no keys, no real conversations.
- Never edit a golden fixture by hand to make a test pass; regenerate it from the reference implementation and explain why in the PR.
- The `ReplySegment` encoding (`{"say":{"_0":"de","_1":"…"}}`) is Swift's synthesized Codable format and is part of the contract.
- Golden fixtures were generated on 2026-10-26 from commit `1e254e7` with a temporary Swift test that used `JournalStore` and `Merger`.
