# LINGO-08: Plan

ID: LINGO-08-plan · Status: draft for AI review · Version: 1 · Date: 2026-10-31 · Risk: R2 · Links: [intent.md](intent.md) · [spec.md](spec.md)

One step = one PR (≤ 600 changed lines without snapshots and fixtures), each with tests, an independent AI review and green CI before merge.
The iOS app is not touched. Model calls during development: single daytime requests only; batches at night (23:00–08:00 Berlin).

| Step | Content | Requirements | Checks |
|---|---|---|---|
| V-1 | Core: item model, events, merger/state, statistics, list parsing and duplicates, selection, usage detection; contracts (schema, payloads, fixtures, README) | VR-01…VR-07, VR-12 | VAC-01…VAC-04, `swift test`, `check-core-ios.sh` |
| V-2 | Engine: per-session switch, mode `words`, detection after each turn (voice and text) writes `vocab.used`; profile event | VR-08, VR-09, PR-01 (data) | VAC-05 |
| P-1 | Prompting v2: profile block, recurring mistakes, vocabulary block in the user message, flow / opening / misrecognition rules, mode "My words" text, task line for empty turns; snapshots re-recorded; new eval cases | PR-01…PR-10 | PAC-01, PAC-02, PAC-04, one daytime live case |
| V-3 | Mac UI: Vocabulary screen, add / paste / edit / remove / translate, new-session switch and mode, profile goals and interests in Settings; RU/EN strings | VR-03, VR-04, VR-08…VR-11, PR-01 (UI) | VAC-06, `check-design`, screenshots |
| E-1 | Night eval batch for the new categories and a sample of the existing ones (also P-02b of LINGO-03 if the quota allows) | PR-10 | PAC-03 |

Order: V-1 → V-2 → P-1 → V-3 → E-1 (V-3 can follow V-2 in parallel with P-1 only if the files do not overlap).
Risks: model quota (mitigation: night batches, small budgets); prompt growth (PR-09 budget, vocabulary in the user message keeps the cache);
false usage detection (VAC-04 negative cases); a new session mode breaks an older build reading the journal (A-06: one device today).
