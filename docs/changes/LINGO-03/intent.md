# LINGO-03: Intent — Mac stabilisation, Lingo Engine and Lingo Web

ID: LINGO-03-intent · Status: **accepted at H-0 in DG-02 on 2026-10-29** — written from three owner brainstorms of 2026-10-26 · Version: 2 · Date: 2026-10-26
Owner: itmax04 · Links: [spec.md](spec.md) · [plan.md](plan.md) · [ARCHITECTURE](../../architecture/ARCHITECTURE.md) ·
ADRs [0002](../../decisions/ADR-0002-web-stack.md), [0003](../../decisions/ADR-0003-authentication.md), [0004](../../decisions/ADR-0004-repository-layout.md), [0005](../../decisions/ADR-0005-model-routing-and-quota.md) ·
Prior change: [LINGO-01](../LINGO-01/intent.md) (Mac MVP, frozen)

## Problem
Lingo works only on one Mac. The owner practises mostly **on a phone, on the go**, and wants the same history on every device,
**4 sessions × 30 minutes a day** (2 German, 2 English), for free. The Mac app also has open issues: the free model quota is spent
inefficiently (a 962-token output reserve for a 74-token median reply), the UI is temporarily English after the repository migration,
and the history exists in a single copy.

## Desired outcome
1. **Lingo for Mac is stable and economical:** Russian UI again, ~30 % fewer tokens per turn, history exported, 30-minute session proven.
2. **The repository is a clean monorepo** ready for several agents: `apps/mac`, `apps/web`, `services/engine`, `packages/core-ts`, `packages/contracts`.
3. **Lingo Engine** on the Cloudflare free plan: sign-in with GitHub (only the owner), history sync, prompt building, model routing with a day plan for 4 × 30 min, transcription proxy, usage ledger.
4. **Lingo Web** (installable PWA) on iPhone Air, iPhone 11, iPad, Android, Windows and other computers: voice practice with push-to-talk and continuous mode, barge-in, commands, corrections, hints, vocabulary, history shared between web devices.
5. **Evidence first:** the browser voice loop is proven on the owner's phones before the full site is built; the day is proven by a full 4 × 30 test.

## Scope
In LINGO-03 (stages 0–2):
- Stage 0 — Mac stabilisation and the monorepo move (executor's first tasks).
- Stage 1 — evidence: device voice spike, model comparison on a language set, measured tempo and tokens.
- Stage 2 — engine + web with GitHub sign-in, sync between web devices, Resources screen, privacy, full-day test.

Not in LINGO-03 (next changes, see [ROADMAP](../../ROADMAP.md)):
- LINGO-04 — the Mac joins the account (shared history with the web, optional engine turns). Owner: **after the site, before the teacher**.
- LINGO-05 — teacher: memory, spaced repetition, scenarios and exam modes, progress and reports.
- LINGO-06 — native iPhone client (locked screen) and the streaming real-time pipeline.
- Public sign-up, other people's accounts, payments, pronunciation assessment, avatars and gamification.

## Constraints
- **$0, no card anywhere.** Cloudflare free plan (Workers, D1, Workers AI), Groq free tier, GitHub free (private repo: limited Actions minutes, macOS minutes count ×10).
- **Sign-in:** GitHub OAuth with an allow-list of the owner's numeric GitHub id (ADR-0003). Not Cloudflare Access (needs a card), not passkeys (owner declined).
- **Audio:** Mac — never leaves the device. Web — utterances are sent through the engine to Groq Whisper and dropped (owner decision W2); never stored or logged.
- **Keys:** Worker secrets / Mac Keychain only; entered by the owner; never in the browser, repo, logs or chat.
- **Groq accounts:** keys of additional Groq accounts may be used as separate pools **at the owner's own risk** (ADR-0005); agents never create accounts.
- **Quota protection:** bulk model calls (evals) only at night and budgeted.
- **Repository language:** English; communication with the owner: Russian.
- **Design:** DESIGN.md tokens adapted to phone widths; screenshots at acceptance.
- **Git:** `main` is the default branch; work via issues → branches → PRs; future scoped executor merges require checks, AI review and H-x; current adoption build is local only; future own docs PR/merge authority is limited to DG-03 A; no force-push or history rewrite.
- **Executors:** Claude Code (Opus 5.5) and Codex; autonomy = a whole stage, stopping at owner checkpoints and blockers.

## Owner decisions
History: W1–W5 (web, first brainstorm) and B-1…B-11 (audit brainstorm) are in git history (v1 of this file, commit `1e254e7`, and the audit reports). The consolidated set:

| # | Topic | Decision (2026-10-26) |
|---|---|---|
| O-01 | Main device | Phone on the go; Mac secondary but kept standalone |
| O-02 | Locked screen | Website first (screen kept on with Wake Lock), native iPhone later (LINGO-06) |
| O-03 | Budget | Strictly $0 |
| O-04 | Focus after the web | Teacher (all four: repetition of my mistakes and words, memory about me, progress and report, plans and scenarios) — LINGO-05 |
| O-05 | Goals | Life in Germany, German B1 (Goethe/telc) speaking, English exam speaking (IELTS-style), work, free conversation |
| O-06 | Daily load | 4 × 30 min (2 DE + 2 EN) ≈ 240 replies/day |
| O-07 | Architecture | Engine on the server for the web; Mac keeps its own logic; shared contracts |
| O-08 | Mac recognition | Stays on-device (whisper.cpp) |
| O-09 | Sign-in | GitHub OAuth, only the owner's account (no passkey, no Access) |
| O-10 | Extra Groq accounts | Allowed as separate pools at the owner's own risk |
| O-11 | Devices | iPhone Air, iPhone 11, iPad, Android phone, Windows PC, other people's computers |
| O-12 | Executors | Claude Code (Opus 5.5) and Codex |
| O-13 | Autonomy | A whole stage within accepted scope; stop dependent work at gates/blockers; future authorized executor merges after checks/AI review/H-x |
| O-14 | Branches | `main-en` merged into `main`; `main` is the default; feature branches + PRs |
| O-15 | Location | Repository moved out of iCloud to `~/Developer/lingo` (done 2026-10-26) |
| O-16 | GitHub | Issues + milestones + labels, CI + PR template |
| O-17 | Stage 0 | Done by the executor as the first tasks |
| O-18 | Layout | Monorepo (`apps/`, `services/`, `packages/`); the executor moves the Swift code |
| O-19 | Mac and account | After the site, before the teacher (LINGO-04) |
| O-20 | Web design | Adapt DESIGN.md (dark theme, same tokens), one column on phones |
| O-21 | Reporting | Short Russian summary in chat + PR descriptions; details in English in `handoff.md` |
| O-22 | Friends | Later; architecture supports several allow-listed accounts |

## Assumptions (correctable at acceptance)

Preparation clarification (2026-10-29): D01-01 retains MR-03 Russian first-run and explicit Russian/English/System. Offline remains read-only; WS-09 uses synthetic seeded queues. [D04-01](../P-00/review-policy-2026-10-29.md) replaces human review with AI-only execution/review for R2/R3. DG-02 subsequently accepted these documents at H-0; no UI implementation or runtime acceptance is inferred. DG-03 A is limited to future checked own docs PR/merge; see the [active ledger](../P-00/handoff.md).

- **C-1.** The site lives at a free `*.workers.dev` address; no custom domain.
- **C-2.** Web UI language: Russian by default, English switchable.
- **C-3.** The Mac keeps its own Groq usage until LINGO-04; the engine's day plan cannot see it, so the plan keeps headroom.
- **C-4.** iPad model and Android/Windows browser versions are recorded at the device checkpoint.
- **C-5.** Teacher event types (memory, cards) are added in LINGO-05 without breaking schema v1 (new types, unknown types preserved).

## Open questions (answered by measurements in Stage 1)
- Does barge-in work in Safari on iPhone Air and iPhone 11 with echo cancellation and speech synthesis together?
- Real tempo: replies per 30-minute session (assumed 60) and tokens per turn after the economy step.
- Which second model and which Workers AI model keep German and Russian explanations good enough?
