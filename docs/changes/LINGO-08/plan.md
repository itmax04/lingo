# LINGO-08: Plan

ID: LINGO-08-plan · Status: draft for AI review · Version: 1 · Date: 2026-10-31 · Risk: R2 · Links: [intent.md](intent.md) · [spec.md](spec.md)

One step = one PR (≤ 600 changed lines without snapshots and fixtures), each with tests, an independent AI review and green CI before merge.
The iOS app is not touched. Model calls during development: single daytime requests only; batches at night (23:00–08:00 Berlin).

| Step | Content | Requirements | Checks |
|---|---|---|---|
| V-1 | Core: item model, ★ items, events (incl. `message`, profile), merger/state (dedupe, final removal, stats before a session), list parsing, text rules, targets, matching; contracts (schema, fixtures for text, parsing, matching, selection, events; README) | VR-01…VR-07b, VR-12 | VAC-01…VAC-04, VAC-06, `swift test`, `check-core-ios.sh` |
| V-2 | Engine: `useVocabulary` and `vocabularyFocus` (optional settings fields), detection after each turn (voice and text) writes `vocab.used`, targets added to the recognition context | VR-07, VR-08, VR-09 | VAC-05, VAC-06 |
| P-1 | Prompting v2 together with the LINGO-03 prompt compaction (P-02b): profile block (frozen per session), recurring mistakes, vocabulary block after the transcript, flow / continue / opening / misrecognition rules, focus text, data tags; snapshots re-recorded; eval format + rules + cases | PR-01…PR-10, MR-02 | PAC-01, PAC-02, PAC-04, one daytime live case |
| V-3 | Mac UI: Vocabulary screen, add / paste / edit / remove / translate, new-session switch and mode, profile goals and interests in Settings; RU/EN strings | VR-03, VR-04, VR-08…VR-11, PR-01 (UI) | VAC-06, `check-design`, screenshots |
| E-1 | Night eval batch for the new categories and a sample of the existing ones (also P-02b of LINGO-03 if the quota allows) | PR-10 | PAC-03 |

Order: V-1 → V-2 → P-1 → V-3 → E-1 (V-3 can follow V-2 in parallel with P-1 only if the files do not overlap).
Risks: model quota (mitigation: night batches, small budgets); prompt growth (PR-09 budget, vocabulary in the user message keeps the cache);
false usage detection (VAC-04 negative cases); a new session mode breaks an older build reading the journal (A-06: one device today).
