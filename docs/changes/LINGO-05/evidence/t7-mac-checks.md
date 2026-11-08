# T-7 Progress screen and weekly report checks (#76)

Date: 2026-11-07. Base: `8110303` (T-6b delivered).

| Check | Result |
|---|---|
| `swift test --package-path apps/mac` | PASS, 323 tests (15 new: ISO week ids, last-7-days numbers, mistake groups and ordering, cards reviewed, request without transcript and input cap, data block cannot be closed by an example, last writer per week, malformed `report.weekly` = unknown, old journals unchanged, one stored report per week, Update = new request, double click = one request, failure + retry, empty week = no request, chart data) |
| `npm ci && npm test` | PASS, 303 tests (new: `report.weekly` Swift/TS fixture parity) |
| `apps/mac/scripts/check-core-ios.sh` | PASS |
| `python3 scripts/check-design.py` | PASS, 545 bilingual strings |
| `scripts/check-english.sh`, `scripts/secret-scan.sh`, `git diff --check` | PASS, 0 findings |
| Screenshots | 24 PNGs in [t7/](t7/): empty journal, synthetic busy journal, running, failed + Retry, stored advice, Teacher "Weekly report" card; RU/EN, light/dark (`--ui-progress`, 1280 × 1500) |

Decisions: an empty week (no minutes, words or reviewed cards) sends no request and disables the button; the advice text passes the pronunciation filter and is capped at 1 500 characters; mistake groups are keyed by the fix rule (empty rule = one group).

NOT RUN: live advice quality and real providers (Q-03); owner's rebuilt app.
