# T-6b exam debrief checks (#75)

Date: 2026-11-07. Base: `3b3a71e` (PR #84 merged).

| Check | Result |
|---|---|
| `swift test --package-path apps/mac` | PASS, 308 tests (10 new in `ExamDebriefTests`: filter DE/EN/RU, idioms kept, shared marker list, XR-03/PX-04 request, input cap, no request without learner turns, one stored summary, failure + Retry = exactly one request, pronunciation-only reply = failure, no concurrent request) |
| `apps/mac/scripts/check-core-ios.sh` | PASS, 65 objects, platform=2 |
| `python3 scripts/check-design.py` | PASS, 512 bilingual strings |
| `scripts/check-english.sh`, `scripts/secret-scan.sh` | PASS, 0 findings |
| Screenshots | 8 PNGs in [t6b/](t6b/): debrief card and "Debrief not available" + Retry, RU/EN, light/dark (fixture renders) |

NOT RUN: live debrief quality, live `no_pronunciation` eval, real providers (Q-03; for H-05); npm (no TS change); signed-app live exam.
