# LINGO-07 — handoff

## Status

**STEP 1–2 COMPLETE / WAITING FOR OWNER.** Final visual acceptance remains partial. Worktree `/Users/macbook/Developer/lingo-redesign`, branch `feat/redesign`, base `1e254e7`, issue https://github.com/itmax04/lingo/issues/32. The owner merges. LINGO-03 and issues #3–#30 remain untouched.

## Completed

- Selected A Quiet autonomously after six ImageGen direction boards; recorded comparative scores.
- Generated the full base set: 118 product screens/states, eight system sheets, six architecture sheets, six direction boards and one production icon (139 final reference assets).
- Implemented DESIGN.md v2, adaptive native tokens, vector mark, transparent icon, Russian/English catalogs, interface preferences, existing Mac screen redesign and honest future-section placeholders.
- Preserved inline and unattachable correction content, original journal transcripts, existing actions and all core model/audio/storage code.
- Captured 63 fixture-only native screens plus two voice-panel boards, and created 40 reference/implementation pairs.
- Added a per-checkout build-cache isolation fix after a shared compiler cache caused a path mismatch; never deleted the unrelated shared cache.

## Checks

PASS: 99 tests in 29 suites; design (19 direct colors, 84 contrast pairs, 380 bilingual strings); English policy; full secret scan (0 findings); release build and strict signature verification; synthetic clicks `mic=1 pause=1 end=1`; six exact native color samples. See `evidence/validation.md` for limits.

NOT PASSED: +/-4 pt geometry acceptance. NOT RUN: live microphone/provider/Keychain/iCloud use. PR: [https://github.com/itmax04/lingo/pull/33](https://github.com/itmax04/lingo/pull/33) (draft, targeting main). CI: **PASS** for the exact code/assets commit `031a15652eedb847fdaf5913bbd1ea84f082b80d`: [run 40545029185](https://github.com/itmax04/lingo/actions/runs/40545029185), both `swift` and `repository` successful.

## Blocker and next authorized work

Built-in subscription ImageGen returned HTTP 429 `usage_limit_reached`. Estimated reset: **2026-10-28 06:45 UTC / 07:45 Berlin**. No paid API fallback. No scheduled resume was created.

All base outputs are present in `/Users/macbook/Desktop/Lingo-Final-2026/` and `design/redesign-2026/`. `blocked-work.json` lists ten unfinished consistency repairs; `production-repair-tasks.json` contains 37 prepared geometry-lock prompts that were **never executed**. Resume STEP 3–5 only after the owner explicitly asks, and only generate after subscription access is available; do not loop on 429 or substitute a paid API. Keep at most three successful image attempts per target and record failed references truthfully.

One confirmed lettering defect remains in `mac-settings-keys-light-1536x1024`: the Add button text is misspelled. The native app's catalog text is correct. Normalized OCR finds no missing required labels in the other 131 targets; that does not certify letter-perfect output, style consistency or absence of extra text.

After access resets: repair the remaining targets, finish geometry-lock refinement and inspect every affected output, refresh comparisons and document actual deviations. Do not claim final visual acceptance from green unit tests.

## Source revisions

AGENTS.md and the root Swift package were read from main `1e254e7`. Missing future roadmap/architecture/process documents and the source ImageGen prompt set were inspected read-only from `origin/design/imagegen-prompts` (`521345b`) and its documentation ancestry. These unmerged LINGO-03 implementation plans were not executed or merged. The owner's latest autonomous brief supersedes prior design approval gates.

## Publication evidence

The large initial Git transfer timed out. The existing authenticated GitHub API transported the blobs and bounded tree batches instead. The resulting remote commit is **byte-identical** to local `031a15652eedb847fdaf5913bbd1ea84f082b80d`, with tree `eb06defa0157be6a6cdbd356230fca9099d8d094`; no history rewrite or replacement commit was needed. The local branch tracks `origin/feat/redesign`. Main was not updated or merged.

This follow-up commit only records publication evidence. The CI link above is pinned to the tested code/assets commit; current PR checks remain the authority for the latest documentation head. The ImageGen limit and visual acceptance gaps are unchanged.

## Prompt 1, STEP 1 — 2026-10-27

Owner authorized STEP 1–2 only, using Prompt 1 from `origin/design/imagegen-prompts` (`1abe972`); no ImageGen or STEP 3–5 until explicitly resumed.
`git fetch` succeeded. `git merge origin/main` returned `Already up to date` against `1e254e7`; no merge commit or conflict resolution was needed.
The remote still reports PR #1 and #31 open; their architecture/process changes and DESIGN.md Web adaptation are not in main.
Read those architecture/process documents from the authorized prompt-source branch without merging unrelated work.

Replaced `redesign.yml` with the documented `ci-repo.yml` and `ci-mac.yml` workflows, preserving the Mac path filters.
Repository hygiene runs the design check; the single macOS job builds/tests and compiles both String Catalogs.
Validation: workflow structure inspected; execution of the revised checks follows STEP 2. No history rewrite, force push or main update.

## Prompt 1, STEP 2 — completed 2026-10-27

All twelve findings a–l are addressed. The full change/evidence mapping is in [STEP 1–2 evidence](evidence/step1-step2.md).
System language default; persistent hints visibility; real voice blockers and live recording levels; study-language accents;
stateful microphone accessibility; nonempty hint sections; exact source-text correction ranges and a separate popover control;
correction indexes per feed change; stable streaming timestamps; settled asynchronous 2× snapshots; readable light tertiary text;
computed WCAG checks; one root DESIGN.md.

Final local checks:
- PASS: `swift build`; `swift test` — 112 tests in 30 suites (13 added regression tests).
- PASS: Python contrast suite — 3 tests; design — 19 tokens, 88 calculated contrast pairs, 380 bilingual strings (0 missing Russian translations).
- PASS: `scripts/build-app.sh`; `codesign --verify --strict dist/Lingo.app`; `--ui-click-test` — `mic=1 pause=1 end=1`.
- PASS: `--ui-snapshot --ui-all` in dark/light × RU/EN — 128 captures, all 2× (2560×1600 px; narrow 2200×1600 px).
- PASS: English policy, `git diff --check`, full secret scan — 0 findings.
- PASS: protected core/prompts/providers/contracts/package have no diff from the previous PR head.

Eight representative native captures are checked in under `evidence/step2-snapshots/`; all 128 dimensions and hashes are recorded in
`evidence/step2-snapshot-manifest.json`. The full local matrix is in this chat's `work/step2-snapshots/` folder.
This is regression evidence only; no new geometry acceptance or ImageGen reference was produced.

Next step: **WAIT for the owner's explicit instruction to continue STEP 3–5.** ImageGen was not called. Earliest generation time remains
2026-10-28 07:45 Europe/Berlin. No scheduled resume. PR #33 remains draft; do not merge or mark it ready during this partial run.
The app stays at `/Users/macbook/Developer/lingo-redesign/dist/Lingo.app`; nothing was written to the Desktop deliverable folder.
