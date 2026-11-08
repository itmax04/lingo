# T-9b Documentation and screenshots (#78, rest)

Date: 2026-11-08. Stacked on T-9a ([PR #90](https://github.com/itmax04/lingo/pull/90), head `9f28e1b`), which is not merged yet.

| Check | Result |
|---|---|
| `swift test --package-path apps/mac` | PASS, 347 tests (`doubleClickSendsOneRequest` now holds call A inside the provider; B and C return `.skipped`, one request in total) |
| `apps/mac/scripts/check-core-ios.sh` | PASS |
| `python3 scripts/check-design.py` | PASS (19 exact color tokens, 88 contrast pairs, 577 bilingual strings) |
| `scripts/check-english.sh`, `scripts/secret-scan.sh` (0 findings), `git diff --check` | PASS |
| Screenshots | 32 PNGs in [t9/](t9/): Reminder setting (off, scheduled, blocked), Today, Teacher, end of a warm-up, scenario session and picker; RU/EN, light/dark. Rendered by the signed worktree bundle (`dist/Lingo.app`, build 210) from synthetic fixtures (`--ui-reminder`, `--ui-all`) |
| Other teacher screens | Exams and debrief: [t6a2b](t6a2b/), [t6b](t6b/); Progress and weekly report: [t7](t7/); Memory: [t8](t8/) (all RU/EN, light/dark) |

Docs updated: ARCHITECTURE (feature table, event list), MAC (Teacher module, screens, events, purposes, reminder), CODEBASE, ROADMAP, AGENTS §1–3, contracts README (`scenarios.json`), completion plan (state).

NOT RUN: a real notification on the owner's Mac; live providers (Q-03). T-7 review notes F2 (fixture advice vs chart trend) and F3 (neutral chart colours) are not done: both change the T-7 screenshots and stay open.
