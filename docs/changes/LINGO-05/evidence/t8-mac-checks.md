# T-8 Memory: What Lingo knows about me (#77)

Date: 2026-11-08. Base: `56a762d` (T-7 delivered, owner build 207).

| Check | Result |
|---|---|
| `swift test --package-path apps/mac` | PASS, 342 tests (19 new `MemoryTests`: keys, update last-writer, final removal, duplicates and cleaning, switch, malformed = unknown + shared fixture, old journals unchanged, PX-04 request caps and exclusions, proposal filter, frozen `<profile>` facts within 200 tokens, memory off, extraction once per session, removed/duplicate dropped, skip rules (<4 messages, memory off, warm-up, exam, resumed), failure without retry, Finish hook, edit/dedupe/switch, no logging sinks in the touched files) |
| `npm ci && npm test` | PASS, 304 tests (new: `memory.*` Swift/TS fixture parity, 4 unknown) |
| `apps/mac/scripts/check-core-ios.sh` | PASS (68 objects) |
| `python3 scripts/check-design.py` | PASS, 567 bilingual strings |
| `scripts/check-english.sh`, `scripts/secret-scan.sh`, `git diff --check` | PASS, 0 findings |
| Screenshots | 40 PNGs in [t8/](t8/): empty journal, synthetic facts, memory off, Teacher card (on / off); RU/EN, light/dark (`--ui-memory`) |

Decisions
- D-09: the screen is a sheet opened from the Teacher card (no new sidebar section). Facts, profile (read-only; edited in Settings) and recurring mistakes (shared `recurringMistakes(lang:before:)`, also used by `<profile>`).
- D-10: "first Finish" = the session was never resumed (`resumedAt == nil`); plus an in-memory once-guard. A session that produced no facts is not retried (PX-04: none, next session).
- D-11: `memory.noted` whose text is blank is unknown (portable rule, also in TS); text that is only data tags is dropped silently. Facts are cut to 120 scalars; edits that duplicate another live fact are refused.
- D-12: `<profile>` facts are those live before the session's creation time (a restart gives the same block); the block stays frozen, but a deleted or edited fact, or the switch, is applied at the next request of an open session (`keepingLiveFacts`, review F1).
- Privacy: no fact text or learner line is logged (a test greps the touched files for print/NSLog/os_log/Logger and any `Log.` call other than count-only `Log.metrics`); the request holds the last 30 learner lines (≤ 3 000 characters) and the 50 latest facts only.

NOT RUN: live extraction quality and real providers (Q-03, H-05); owner's rebuilt app.

Independent review at `0cdd7f5`: approve-with-notes, no P0/P1. Fixed: F1 (open session), F2 (`known_facts`/`learner_lines` in `stripTags`), F3 (log test), F4 (cap edge case), F6 (wording). Accepted F5: a removed fact blocks the key of its final text only; an edited-then-deleted fact's original text may be proposed again (it is the learner's own, deletable again).
