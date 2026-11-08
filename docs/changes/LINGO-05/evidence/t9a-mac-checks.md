# T-9a Reminder (#78, part)

Date: 2026-11-08. Base: `e3fb778` (T-8 merged).

| Check | Result |
|---|---|
| `swift test --package-path apps/mac` | PASS, 347 tests (5 new `ReminderTests`: next time with goal reached / time passed / exactly now / off / clamped, DST day, schedule → remove on goal → next day → goal change against a fake centre, off and denied or undetermined permission leave nothing pending and sync never prompts, defaults and tolerant decoding) |
| `apps/mac/scripts/check-core-ios.sh` | PASS (Reminder.swift has no UserNotifications import) |
| `python3 scripts/check-design.py` | PASS, 577 bilingual strings (10 new, two with Russian plural forms) |
| `scripts/check-english.sh`, `scripts/secret-scan.sh`, `git diff --check` | PASS, 0 findings |

Decisions
- D-13: one non-repeating pending request with a fixed identifier; it is replaced on every sync (launch, switch, time change, goal reached, new day). If the app is not opened for a day the notification fires once and none follows until the next launch (GR-08 keeps one pending).
- D-14: the text uses the last chosen study language and the goal in force: "Time for N minutes of German/English?" (RU plural catalog entries).
- D-15: `notDetermined` after the switch (prompt dismissed) is shown like a refusal; sync itself never asks for permission.

NOT RUN: a real notification on the owner's Mac and the screenshot of the setting (T-9b).
