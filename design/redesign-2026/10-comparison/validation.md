# LINGO-07 — validation

Local checkout: `/Users/macbook/Developer/lingo-redesign`, branch `feat/redesign`, base `1e254e7`.

| Check | Result | Evidence |
|---|---|---|
| `swift test` | PASS | 99 tests in 29 suites; latest run completed in 3.649 seconds |
| `scripts/check-design.py` | PASS | 19 exact direct color tokens, 84 contrast pairs >= 4.5:1, 380 bilingual strings and matching format parameters |
| `scripts/check-english.sh` | PASS | No Cyrillic repository prose outside justified UI/source/evidence allow-list |
| `scripts/secret-scan.sh` | PASS | 0 findings in working tree, index and all local history |
| `git diff --check` | PASS | No whitespace errors |
| `scripts/build-app.sh` | PASS | Release .app built and signed using the existing InterviewCopilot certificate; no trust or TCC changes |
| `codesign --verify --strict dist/Lingo.app` | PASS | Exit status 0 |
| `Lingo --ui-click-test` | PASS | `mic=1 pause=1 end=1` |
| Native raster color sampling | PASS | Six window/sidebar/hints samples match exact dark/light HEX values |
| Fixture UI captures | PASS | 63 native captures, plus two composite boards of native voice panels; RU/EN and both themes |
| Reference comparisons | GENERATED, NOT ACCEPTED | 40 equal-canvas pairs; scaling and padding recorded in comparison-manifest.json |
| Image lettering | INCOMPLETE | One confirmed Add-button spelling defect remains in the light keys reference; 131/132 targets have no missing required labels in normalized OCR, which is not a proof of exact typography |
| Geometry within +/-4 pt | NOT PASSED | Generated geometry differs; the prepared geometry-lock pass was blocked by the subscription limit |
| Live voice / Keychain / iCloud / provider / 30-minute session | NOT RUN | This is a presentation change; captures use isolated synthetic stores and never start the normal service loop |
| CI | PASS | Code/assets commit `031a156`; [run 40545029185](https://github.com/itmax04/lingo/actions/runs/40545029185), both Swift and repository jobs successful |

## ImageGen blocker

The built-in subscription tool returned HTTP 429, `usage_limit_reached`, with an estimated reset at 2026-10-28 06:45 UTC (07:45 Berlin). All base assets exist. Ten visual-repair targets and 37 prepared Mac geometry refinements remain blocked. No paid API, new account or automatic future run was used.

The final product concept contains 118 screen/state images across both themes, six direction boards, eight system sheets, six architecture diagrams and one production icon: 139 final reference assets. Earlier attempts remain on the Desktop and in the original generated-image directory; only final references and comparisons are copied into the repository.

## Scope and invariants

`LingoCore`, `LingoEvalKit`, model prompts, provider routing and event schemas have no code diff. PromptBuilder uses explicit model-instruction literals rather than localized UI titles; enabling Russian UI does not translate its wrapper. Existing prompt snapshots remain covered by the passing tests.

New Mac sections are navigation-only Coming soon previews. Existing saved phrases still work in conversation hints. No server, web, mobile or monorepo implementation was introduced; issues #3–#30 were not modified.

## Evidence limits and deviations

Every pair in comparison-manifest.json is explicitly marked as not accepted for geometry. ImageGen changed column widths, wrapping, window chrome and control shapes. Actual dimensions differ from requested filename dimensions in some outputs; originals are preserved and scaling is explicit. Generated glows, gradients and inconsistent marks are replaced in native UI by exact flat tokens and a vector mark. The light icon concept and some remaining light teacher/system/architecture concepts retain inconsistent branding; the production app uses the separate transparent icon asset.

Menu/correction evidence renders the actual shared SwiftUI components over a fixture window; it is not an operating-system popover-window capture. Future mockup statistics and resources are synthetic. No screenshot demonstrates working future accounts, exams or teacher logic. The change remains blocked and must not be presented as a completed final visual match.

## Publication

Draft PR: [https://github.com/itmax04/lingo/pull/33](https://github.com/itmax04/lingo/pull/33). The exact local commit was published to `feat/redesign`; main was not updated. The current PR checks report the latest documentation head separately from the pinned code/assets run above.
