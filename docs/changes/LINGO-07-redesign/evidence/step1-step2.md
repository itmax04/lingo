# Prompt 1 — STEP 1–2 evidence (2026-10-27)

Scope authorized by the owner: use Prompt 1 from `origin/design/imagegen-prompts`, execute STEP 1 and STEP 2 only, push and wait. No ImageGen, STEP 3–5, PR-ready transition or merge.

## STEP 1

- `git fetch`: PASS. Main was `1e254e7`; `git merge origin/main` returned `Already up to date`.
- No conflicts occurred. The architecture/process documentation and Web adaptation are still on the source documentation branch; no unrelated documentation branch was merged.
- Commit `11c284e`: removed `redesign.yml`; introduced the documented `ci-repo.yml` and `ci-mac.yml`, retaining Mac path filters. Exactly one macOS job builds/tests and compiles every String Catalog.

## STEP 2 acceptance evidence

Swift evidence lives in `Tests/LingoMacTests/PresentationRegressionTests.swift`; existing presentation tests remain in `PresentationTests.swift`.

| Finding | Change | Regression evidence |
|---|---|---|
| a | System is the shared default for preparation, locale, appearance and settings; stored explicit choices remain effective | `freshInstallUsesSystemLanguageWithoutPersistingAnOverride` |
| b | Window width only selects an overlay or a column; it never writes `hintsVisible` | `resizingKeepsTheOwnersHintsChoice` renders narrow/wide/narrow with both visibility choices |
| c | Only offline, missing key and every usable route's actual 429 pause produce panel unavailability; notices stay separate; captured levels remain visible during recording | `noticesDoNotReplaceVoiceStateOrCapturedLevels`; `quotaNeedsEveryUsableRouteToHaveAnActual429AndExpires` |
| d | View-scoped study-language environment drives tint, focus rings, primary buttons, selected navigation and marks; settings and new-session windows receive their language context | `accentFollowsSessionLanguageAndFilterFallback`; native fixture captures |
| e | Idle microphone says Speak; every other state includes its localized state title | `microphoneLabelIncludesEveryActiveState` |
| f | Empty phrase sections are removed; deduplication and the empty-panel message remain | `emptyHintSectionsDisappearWhileOtherSectionsRemain` |
| g | Diff ranges refer to the actual transcript, preserving casing, tabs, spaces and newlines; a separate Correction button owns the popover; tapping the transcript still edits it | `diffPreservesExactSourceCasingWhitespaceAndSurroundings`; `insertionKeepsSourceSpacingAndAddsOnlyMissingSeparators`; real synthetic mouse events in `correctedUserBubbleStillOpensEditor` |
| h | One pass builds `[messageID: Fix]` and fallback maps when messages/correction mode change; bubbles use dictionary lookups | `correctionIndexKeepsExtraUnattachableAndDisabledFixesVisible`; `waveformUpdatesDoNotInvalidateTheStreamingCorrectionInput` |
| i | Native captures use 2 pixels per point and yield the main actor until pixels settle, up to eight passes | `snapshotUsesTwoPixelsPerPointAndWaitsForDeferredLayout` checks dimensions and deferred content |
| j | Light tertiary text is #5D676F: luminance is over 20% greater than secondary; all required pairs remain at least 4.5:1 | Python `test_light_hierarchy_and_all_surfaces_remain_readable`; minimum light tertiary/selected surface is 4.526:1 |
| k | WCAG sRGB luminance and mandatory pairs are computed from `tokens.json`; stored ratios cannot waive checks | Python `test_wcag_reference_values`; `test_forged_evidence_cannot_hide_bad_tokens`; design check |
| l | Root DESIGN.md is the only copy; no copies-identical check remains | Design check asserts the single canonical document |

Streaming timestamps are stable during waveform-only changes, so synthetic message metadata cannot invalidate the correction cache on every audio-level update. No LingoCore, prompts, providers, event schemas or dialogue logic were changed.

## Validation

- PASS: `swift build` and `swift test`: 112 tests in 30 suites, including 13 new presentation regression tests.
- PASS: Python contrast regression suite: 3 tests.
- PASS: design check: 19 exact colors, 88 computed contrast pairs, 380 bilingual catalog strings with matching placeholders.
- PASS: signed release build and strict signature verification with the existing certificate.
- PASS: native click test: `mic=1 pause=1 end=1`.
- PASS: native snapshot matrix: 128 captures (32 screens × dark/light × RU/EN), all at 2×. Dimensions and SHA256 are in [the manifest](step2-snapshot-manifest.json).
- PASS: English policy; full secret scan: 0 findings; `git diff --check`.

Representative reviewed native captures: [Russian dark](step2-snapshots/ru-dark-conversation.png), [English light](step2-snapshots/en-light-conversation.png), [recording during a notice](step2-snapshots/ru-light-voice-recording-notice.png).
The remaining full-size local captures are intermediate test output in this chat's `work/step2-snapshots/`, not newly generated design references.

Live microphone, real provider requests, Keychain credentials and iCloud sessions: NOT RUN. The fixture renderer uses an isolated temporary journal, in-memory secrets and synthetic provider health only.

## Deferred by the owner

STEP 3: ImageGen repairs after the quota reset, including the ten blocked targets and architecture/navigation/mark consistency. STEP 4: geometry alignment and measured ±4 pt acceptance. STEP 5: reference conversion, size budget and final delivery/ready-for-review. The PR remains draft. Resume only after the owner's explicit instruction.
