# Stage start prompts

Status: current · Date: 2026-10-27 · Links: [SDLC](SDLC.md), [ROADMAP](../ROADMAP.md), [LINGO-03 plan](../changes/LINGO-03/plan.md)

One prompt per stage, in the order the owner runs them. Each prompt is self-contained: paste the fenced block into a new session.

## How to use
- **One new session per stage.** Inside a stage, stay in the same session until its context starts compacting; then start a new one
  with the same prompt — the state lives in `handoff.md`, issues and PRs.
- **Prompt 1 needs Codex** (ImageGen). All other prompts work in Codex and in Claude Code.
- **Owner actions** before each prompt are listed above it. Replace `<…>` with the owner's notes from the checkpoints (H-1, H-3, H-4).
- The audit (prompt 8) always runs in a fresh session that did not write the code.

Order: 1 → owner merges → 2 → H-1 → 3 → H-3 → 4 → H-4/H-5 → 5 → 6 → 7 → 8 (8 may also run after any large stage).

---

## Prompt 1 — Finish the redesign (LINGO-07, PR #33)

Owner first: merge PR #1, then PR #31 (documents only). Start after the ImageGen limit resets (2026-10-28 07:45 Europe/Berlin).
Run Codex locally in `~/Developer/lingo`.

```text
You are the executor of LINGO-07 — the redesign of the standalone Mac app and the reference image set.
Repository itmax04/lingo, local path ~/Developer/lingo (your previous worktree ~/Developer/lingo-redesign may be reused).
Issue #32, draft PR #33, branch feat/redesign.
Read first: AGENTS.md, DESIGN.md, docs/architecture/ARCHITECTURE.md, design/redesign-2026/README.md,
design/redesign-2026/prompts/IMAGEGEN-PROMPTS.md (decisions R-01…R-12), docs/changes/LINGO-07-redesign/{handoff,report}.md,
design/redesign-2026/blocked-work.json, production-repair-tasks.json.

Goal: PR #33 leaves draft with a consistent reference set and a Mac app that matches it.
Work autonomously: generate, judge and choose images yourself, never ask the owner to approve pictures.
If ImageGen returns 429 again: stop generating, finish everything else, record what is left. Never use a paid API.

STEP 1 — Bring the branch up to date (no rebase, no force-push)
- git fetch; git merge origin/main into feat/redesign.
- Conflicts: AGENTS.md, .github/pull_request_template.md, scripts/english-allowlist.txt → take main and re-add only your additions.
  DESIGN.md → apply your v2 tokens on top of main's version and keep main's §9 "Web adaptation".
- Delete .github/workflows/redesign.yml. Move `python3 scripts/check-design.py` into ci-repo.yml and the xcstringstool compile
  step into ci-mac.yml (keep its path filters). Exactly one macOS job per PR.

STEP 2 — Fix the code review findings (each with a unit test or a snapshot as evidence)
a. Interface language defaults to "system" (InterfacePreferences.prepare, InterfaceAppearance, InterfaceSettingsView), never "ru".
b. MainView never overwrites model.hintsVisible when the window narrows; narrow vs wide only decides overlay vs column.
c. VoicePanel `unavailable` gets only real voice blockers (offline, no key, quota exhausted), never transient banners;
   the waveform stays live while recording.
d. Theme.accentPrimary follows the current study language (Theme.accent(lang)) for tint, focus ring, primary buttons, selected tabs.
e. Mic accessibility label: "Speak" when idle, "Microphone: <state>" otherwise.
f. HintsPanel hides sections with zero phrases.
g. InlineCorrection builds before/after from the user's actual text slice (exact casing and spacing). A tap on a corrected
   user bubble still opens the edit sheet; the correction popover gets its own control.
h. MessageList computes corrections once per messages change ([messageID: Fix]), not per bubble per render.
i. UISnapshot.render captures at 2× backing scale and waits until layout settles (up to 8 passes).
j. Light theme: textTertiary visibly lighter than textSecondary, WCAG AA kept for its uses.
k. scripts/check-design.py computes WCAG contrast from tokens.json itself (no trusted numbers in contrast.json).
l. Keep one DESIGN.md (repo root). Delete the copies in design/redesign-2026 and the "copies identical" check.

STEP 3 — Fix the image set (regenerate with ImageGen; max 3 successful attempts per target)
- First the 10 targets in blocked-work.json and the "Add" lettering defect in mac-settings-keys-light.
- 09-architecture: redraw all six to match ARCHITECTURE.md. Web + engine are the next stage (not "paused"),
  phone speech recognition = Groq Whisper via the engine, only the Mac recognises on device. Label every diagram "planned".
- One voice-control model for every state and platform: same button positions; "Stop recording" and "Finish session"
  never share a label or an icon.
- Destructive actions are always statusDanger red in both themes. Teal = English accent only, never a generic button colour.
- One Lingo mark everywhere (the two-loop vector mark): fix the light icon and every blob-shaped or two-coloured mark.
- Navigation: four bottom tabs (Today / Conversations / Vocabulary / Progress) on every iPhone root screen;
  Mac settings always use the sidebar; the "Teacher — soon" screen has the right title.
- Light design-system sheets (typography, components) show the real scale and tokens.

STEP 4 — Match the Mac app to the references
- Normalise canvases before comparing: Mac references and snapshots both 1280×800 pt at 2×.
- Run the 37 prepared geometry tasks (production-repair-tasks.json) where they still apply.
- Target ±4 pt for positions and sizes, identical tokens. Change the app, not the reference, unless the reference breaks
  DESIGN.md or R-01…R-12. New values go into DESIGN.md first, each with a one-line reason.
- Today, Vocabulary, Progress and Teacher stay honest "Coming soon" previews (their logic is LINGO-05), but follow the layout
  of the references.

STEP 5 — Assets and delivery
- Convert the reference images in design/redesign-2026 to WebP (or JPEG for photos), ≤ 30 MB in total in the repo.
  Keep the full-size PNGs only in ~/Desktop/Lingo-Final-2026/ (overwrite only files you created; update its README in Russian).
- Do not put Lingo.app into the Desktop folder (iCloud breaks strict signature checks): leave it in dist/ and write its path in the README.
- Checks: swift build && swift test, scripts/build-app.sh, codesign --verify --strict dist/Lingo.app, --ui-click-test,
  --ui-snapshot --ui-all (dark/light × RU/EN), check-design.py, check-english.sh, secret-scan.sh, 0 missing Russian strings.
- PR description: a table per screen (reference · snapshot · max deviation in pt · status), fixed findings, NOT DONE list.
  Update handoff.md and report.md. Mark the PR ready for review. Recommend "Squash and merge" to the owner
  (so the 211 MB of original PNGs never reach main). Do not merge.

Rules (AGENTS.md §6): $0; no secrets, accounts or keys; no force-push, history rewrite or branch deletion; no system or console
settings; no pronunciation feedback anywhere; no changes to LingoCore, prompts, providers, the event schema or dialogue logic.
Final report to the owner in Russian: what changed, PR link, what is left.
```

After: the owner reviews PR #33 and merges it with **Squash and merge**.

---

## Prompt 2 — Stage 0: stabilise the Mac (P-01…P-06)

Owner first: PR #1, #31 and #33 are merged.

```text
You are the executor of LINGO-03, Stage 0 "Stabilise" (milestone "LINGO-03 · Stage 0 — Stabilise"),
repository itmax04/lingo, local path ~/Developer/lingo.
Read: AGENTS.md, docs/architecture/ARCHITECTURE.md, docs/process/SDLC.md, docs/changes/LINGO-03/{intent,spec,plan,handoff}.md,
ADR-0002…0005, docs/changes/LINGO-07-redesign/report.md (what the redesign already changed).

H-0 is done (the owner merged PR #1): close issue #2 with a short comment.
Work through issues #3–#8 (P-01…P-06) in plan order. Per issue: own worktree (git worktree add ../lingo-<issue> -b <branch> origin/main),
branch `<type>/<issue>-<slug>`, implement, test, update handoff.md, push, PR from the template, wait for green CI.
Do not merge; stack the next branch while waiting. P-02…P-06 are independent after P-01.

Notes:
- P-01 (monorepo): Swift package → apps/mac. Keep the redesign working: snapshots, scripts/check-design.py,
  scripts/redesign-snapshots.sh, the String Catalog, CI path filters. design/ stays at the repo root.
- P-02 (tokens): measure the reply-length distribution from the usage log first, then set per-purpose output reserves
  and compact instructions; re-record snapshots. One night dialog batch, ≤ 15 requests, 23:00–08:00 Europe/Berlin only.
- P-03 (Russian UI): the redesign already added the String Catalog and the interface-language setting (default "system").
  Check them against MR-03, add only what is missing (missing-translation check in CI, RU/EN screenshots); no duplicates.
- P-05 (stability): prepare `--audio-stability <file> --duration <min>`. If the 30-minute run needs a real microphone,
  give the owner the exact command and leave the run for H-1.
- Definition of Done: SDLC §6.

Stop at H-1 (issue #9): give the owner a short Russian checklist for the 30-minute Mac session (AC-17 protocol):
what to do, what to watch, what to report back.
Rules: AGENTS.md §6. Final report in Russian in the SDLC §10 format with PR links.
```

After: the owner runs the 30-minute Mac session (H-1) and writes down notes.

---

## Prompt 3 — Stage 1: engine and device evidence (P-07…P-11)

Owner first (H-2, issue #11), outside chat: `wrangler login`; create two GitHub OAuth Apps (prod and dev);
enter secrets with `wrangler secret put`. Give the executor only the two client ids.

```text
You are the executor of LINGO-03, Stage 1 "Evidence" (milestone "LINGO-03 · Stage 1 — Evidence"), repository itmax04/lingo.
Read: AGENTS.md, ARCHITECTURE.md, SDLC.md, LINGO-03 spec/plan/handoff, ADR-0002…0005, packages/contracts/README.md,
docs/process/TESTING.md, docs/process/RELEASE.md.
H-1 notes from the owner: <paste>.
H-2 is done. OAuth client ids: prod <id>, dev <id>. Secrets are already in Cloudflare; never ask for them, print them or put them in env files.

Work through P-07, P-08, P-09, P-10, P-11 (issues #10, #12, #13, #15, #16) in plan order; worktree, branch and PR per issue; do not merge.
- P-07: npm workspaces + packages/core-ts (event types, ULID, reducer/merge, reply parser, command detector, VAD + segmenter),
  parity tests against packages/contracts: golden merge, commands ≥ 95 %, turn thresholds, protocol tests.
- P-08: Worker + static assets + D1 migration 0001 + GitHub OAuth with an allow-list by numeric GitHub id
  (read itmax04's id from the public API) + sessions + origin checks + /api/me.
  Tests: forged cookie, foreign id, wrong origin. Local D1 only.
- P-09: voice spike page behind sign-in (mic, level meter, VAD, MediaRecorder → /api/transcribe → fixed reply → speechSynthesis,
  barge-in timer, Wake Lock, metrics export). Give the owner exact commands for the remote migration and the *.workers.dev deploy.
- P-10: model comparison on the language set — night only, budgeted batches; results in evidence/, no raw utterances in logs.
- P-11: capacity table for 4 × 30 min/day (≈ 240 replies) in handoff.md from real H-1 and P-10 numbers.

Stop at H-3 (issue #14): give the owner a Russian device checklist for iPhone Air, iPhone 11, iPad, Android, Windows
(10 barge-in attempts + 10 voice turns each; what to write down). Do not start Stage 2.
Rules: AGENTS.md §6. Report in Russian, SDLC §10, PR links.
```

After: the owner runs the device voice tests (H-3) and writes down the results.

---

## Prompt 4 — Stage 2: Lingo Web (P-12…P-20)

```text
You are the executor of LINGO-03, Stage 2 "Lingo Web" (milestone "LINGO-03 · Stage 2 — Lingo Web"), repository itmax04/lingo.
Read: AGENTS.md, ARCHITECTURE.md, SDLC.md, LINGO-03 spec/plan/handoff, ADRs, packages/contracts, TESTING.md, RELEASE.md,
DESIGN.md (incl. §9 Web adaptation), design/redesign-2026/README.md.
H-3 device results: <paste>. Choose the voice design from them as plan.md says (continuous vs push-to-talk + tap to stop)
and record it as D-xx in handoff.md.

Work through P-12…P-19 (issues #17–#24) in plan order; parallel only where plan.md allows, each in its own worktree. Do not merge.

Design: the web app is built from scratch, but its look is already decided. Use the reference images as the visual spec:
design/redesign-2026/02-iphone (phone), 03-ipad, 05-web-desktop, 06-android-windows, 07-teacher only for later placeholders.
Rules: tokens only from DESIGN.md (no colours picked from images); four bottom tabs Today / Conversations / Vocabulary / Progress
on phone widths, sidebar on wide; DE/EN accents; inline corrections as in the Mac app; one voice-control model; system font stack.
Screenshots 390×844, 820×1180, 1280×800 in light/dark × RU/EN, compared with the references.

Logic: behaviour shared with the Mac (event schema, commands, reply protocol, corrections, hints, recap) comes from
packages/contracts and packages/core-ts — never re-implemented ad hoc. Contract changes update Swift and TypeScript in one PR.
Real provider calls: single daytime requests; evals at night. P-19: prepare the production deploy per RELEASE.md;
the owner runs remote migrations, secrets and deploy.

Stop at H-4 (issue #25): Russian checklist for two full days of 4 × 30 (phone + Mac), sign-in and sign-out on a foreign computer,
PWA install. After the owner's H-4 notes, do P-20 (report.md with evidence for WAC-01…WAC-14, README/AGENTS/ARCHITECTURE updated)
and stop at H-5.
Rules: AGENTS.md §6. Report in Russian, SDLC §10, PR links.
```

After: two full days on phone and Mac (H-4), then the owner accepts LINGO-03 (H-5).

---

## Prompt 5 — LINGO-04: the Mac joins the account

```text
You are the executor of LINGO-04 "Mac joins the account" (epic issue #28), repository itmax04/lingo. LINGO-03 is accepted.
Read: AGENTS.md, ARCHITECTURE.md, SDLC.md, docs/ROADMAP.md, LINGO-03 report.md, ADR-0003, ADR-0004, packages/contracts,
references design/redesign-2026/02-iphone/iphone-account-*.

Phase A — documents. Create docs/changes/LINGO-04/{intent,spec,plan,handoff,executor-prompt}.md per SDLC.
Scope: the Mac signs in with GitHub (device flow or loopback; no client secret in the app; token in the Keychain),
uploads its local journal (schema v1, idempotent, cursor), merges history from web devices, keeps working offline,
keeps on-device speech recognition, shows the "Devices and sync" screen like the reference.
Ask the owner at most 5 Russian multiple-choice questions with a recommended option (e.g. what happens to the iCloud sync folder,
whether to migrate old history), record the answers, create the milestone and issues, open a docs PR and stop at H-0.

Phase B — after acceptance: implement the whole stage; issue → branch → PR; do not merge;
stop at your owner checkpoints (real two-device test: Mac + phone, offline and back).
Rules: AGENTS.md §6. Report in Russian, SDLC §10.
```

---

## Prompt 6 — LINGO-05: teacher

```text
You are the executor of LINGO-05 "Teacher" (epic issue #29), repository itmax04/lingo. LINGO-04 is accepted.
Read: AGENTS.md, ARCHITECTURE.md, SDLC.md, ROADMAP.md, LINGO-03 intent.md (strategy decisions of 2026-10-26),
references design/redesign-2026/07-teacher (F1–F10), 02-iphone/iphone-today-overview-*, 04-mac/mac-today-*, mac-progress-*, mac-teacher-*.

Phase A — documents: docs/changes/LINGO-05/{intent,spec,plan,handoff,executor-prompt}.md. Scope, all four parts:
1) spaced repetition of the owner's mistakes and words (FSRS) with a warm-up before sessions;
2) learner memory ("What Lingo knows about me"), visible, editable and deletable by the owner;
3) progress and a weekly report;
4) a daily plan of 4 × 30 min and scenarios: German B1 Goethe/telc speaking, IELTS-style English speaking,
   life in Germany, work.
Replace the "Coming soon" sections (Today, Vocabulary, Progress, Teacher) on web and Mac with real features matching the references.
Constraints: $0 quota (background requests budgeted per day), Russian explanations only on request,
never any pronunciation assessment, memory stored in the engine.
Ask ≤ 5 Russian multiple-choice questions, open a docs PR, stop at H-0.

Phase B — after acceptance: implement; evals for new prompts at night; do not merge; stop at your owner checkpoints.
Rules: AGENTS.md §6. Report in Russian, SDLC §10.
```

---

## Prompt 7 — LINGO-06: native iPhone and real-time voice

```text
You are the executor of LINGO-06 "Native iPhone and real-time" (epic issue #30), repository itmax04/lingo. LINGO-05 is accepted.
Read: AGENTS.md, ARCHITECTURE.md, SDLC.md, ROADMAP.md, ADR-0001, LINGO-01 spec §4 (draft iPhone checks),
references design/redesign-2026/02-iphone incl. iphone-native-locked-screen-* and iphone-native-dynamic-island-*.

Phase A — documents: docs/changes/LINGO-06/{intent,spec,plan,handoff,executor-prompt}.md.
Scope: a SwiftUI iPhone app on LingoCore (it already compiles for iOS) for iPhone Air and iPhone 11, signed in to the same account;
voice with a locked screen and headphones (Live Activity like the references); real-time voice where free tiers allow it,
with an honest fallback to the turn-based loop.
Constraints: $0 — no paid Apple Developer account: installation via SideStore or free provisioning with 7-day re-signing;
measure what survives re-signing and updates; memory budget for iPhone 11 (4 GB).
Ask ≤ 5 Russian multiple-choice questions, open a docs PR, stop at H-0.

Phase B — after acceptance: implement; the owner installs on the devices (you give exact steps); do not merge;
stop at your owner checkpoints.
Rules: AGENTS.md §6. Report in Russian, SDLC §10.
```

---

## Prompt 8 — Audit, review and fix

Run at the end, and optionally after any large stage — always in a fresh session that did not write the code.

```text
You are the auditor and fixer for the whole Lingo repository (itmax04/lingo, ~/Developer/lingo, branch main).
You did not write this code; judge it only by the code, the documents and real check output.
Read: AGENTS.md, ARCHITECTURE.md, SDLC.md, TESTING.md, RELEASE.md, DESIGN.md, all ADRs, the latest report.md and handoff.md
of every change, docs/audits/ (earlier audits, if any).

PART 1 — Audit (read-only). Cover every area: apps/mac, apps/web, services/engine, packages/core-ts, packages/contracts,
scripts, CI, design/. For each finding: file:line, a concrete failure scenario, severity
(P0 crash / data loss / security, P1 wrong behaviour, P2 quality or cost, P3 cleanup). Angles:
1. Correctness — line by line in non-trivial functions: conditions, off-by-one, optionals/undefined, async/await, races, error paths.
2. Removed behaviour — guards, checks or tests lost in recent PRs (git log -p since the last audit).
3. Contracts — Swift ↔ TypeScript parity against packages/contracts; API ↔ openapi.yaml; event schema v1 compatibility.
4. Security and privacy — OAuth, cookies, origin checks, allow-list, D1 isolation between accounts; no secrets or utterance text
   in logs; audio never stored; export and "delete my data" really complete; dependencies only from the ADR allow-lists.
5. Quota and cost — tokens per turn, retries, background requests, Workers CPU, D1 size, CI minutes (macOS ×10);
   does the 4 × 30 min/day plan still fit the free tiers?
6. UX and accessibility — DESIGN.md tokens only, light/dark, RU/EN complete, VoiceOver/ARIA labels, keyboard focus,
   reduce motion, phone widths, the implementation vs the reference images in design/redesign-2026.
7. Performance — hot paths during voice (re-renders per level update, O(n²) lists), memory budgets (Mac 1.2 GB, iPhone 11 4 GB).
8. Tests and docs drift — spec IDs without a test, flaky tests, documents that no longer match the code.
Product rule: no pronunciation assessment anywhere — check code, prompts and evals (no_pronunciation = 100 %).
Write docs/audits/AUDIT-<date>.md (English) with the findings table. Send the owner a short Russian summary:
counts per severity and the top 10.

PART 2 — Fix. Without asking, fix P0 and P1, plus P2/P3 that are local and low-risk.
One branch fix/audit-<date>-<area> per area from origin/main, one PR each; every fix with a regression test or evidence.
Anything that changes a recorded decision (intent, ADR, DESIGN.md) or product behaviour: do not change it — list it with
a recommendation and ask the owner in Russian (multiple choice, recommended option first).
Run everything: swift test (apps/mac), npm ci && npm test, Playwright, check-english.sh, secret-scan.sh, check-design.py,
missing-translation check. Evals only at night, budgeted; real provider calls only as single daytime requests.

PART 3 — Re-review. Review your own PR diffs once more with the same angles, fix what you find, and update AUDIT-<date>.md
with fixed / skipped (why) / needs the owner. Do not merge.
Rules (AGENTS.md §6): $0; no secrets, accounts or keys; no force-push, history rewrite or branch deletion; no system or console settings.
Final report in Russian: what was found, what was fixed (PR links), what waits for the owner.
```
