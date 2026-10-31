# Lingo — roadmap

Owner decisions of 2026-10-26 (see [LINGO-03 intent](changes/LINGO-03/intent.md)). Each change follows the [SDLC](process/SDLC.md):
brainstorm → intent/spec/plan → owner acceptance → issues → PRs → report → acceptance.

| Change | Status | Goal | Main contents |
|---|---|---|---|
| [LINGO-01](changes/LINGO-01/intent.md) | frozen | Mac MVP | Voice practice on the Mac: on-device whisper, Groq chain, journal, hints, corrections. Open: AC-17 (30-min session) moves to LINGO-03 H-1; formal H-5 acceptance not done |
| LINGO-02 | dropped | native iPhone via SideStore (first plan) | replaced by LINGO-03 (web) + LINGO-06 (native thin client) |
| **[LINGO-03](changes/LINGO-03/intent.md)** | **next** | Lingo on every device | Stage 0 Mac stabilisation + monorepo · Stage 1 evidence (device voice spike, model comparison, tempo) · Stage 2 engine + PWA with GitHub sign-in, sync between web devices, full-day test 4 × 30 |
| LINGO-07 | in review (PR #33) | Redesign | DESIGN.md v2 (light + dark, DE/EN accents, new mark), Mac UI redesign, reference images for all platforms in `design/redesign-2026` — the visual spec for the web (LINGO-03 Stage 2) and the teacher (LINGO-05) |
| LINGO-04 | planned | Mac joins the account | sync adapter in Swift, device token, optional "turns via engine", one history on Mac + web |
| LINGO-05 | planned | Teacher | memory about the learner (per language, viewable and deletable), spaced repetition of own mistakes and words (FSRS) with a warm-up, scenarios (life in Germany, work), exam modes (German B1 Goethe/telc speaking, English IELTS-style speaking) — feedback without pronunciation, progress screen and weekly report, role split (partner / analyst / planner) within quota |
| LINGO-06 | later | Freedom and speed | native iPhone thin client for the locked screen (SideStore check first), streaming real-time pipeline (partial recognition, speculative replies), adaptive end-of-utterance |
| — | watch | — | macOS 26 SpeechAnalyzer and Apple's on-device model (owner rejected a local model on the Mac in Q29), speech-to-speech models when a free option exists |

## Success metrics (targets)
| Metric | Now | After LINGO-03 | After LINGO-05/06 |
|---|---|---|---|
| Minutes of practice per day without a quota refusal | ≈ 45 on one model (Mac) | 120 (4 × 30) | 120 |
| Devices sharing one history | Mac only | all web devices | all incl. Mac and native iPhone |
| `speech_end → audible_start` median | 3.5 s (Mac) | ≤ 4 s (phone) | ≤ 2 s |
| Repeated cards per week | — | — | ≥ 70 |
| Blind review "acceptable" | not measured | ≥ 80 % | ≥ 85 % |
| History losses in sync | 0 (tests) | 0 (two-device test) | 0 |
