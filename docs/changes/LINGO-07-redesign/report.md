# LINGO-07 — report

Status: **BLOCKED / PARTIAL**, issue #32. The Mac redesign and complete base reference set are implemented; final image repair and visual acceptance are not complete.

See [validation](evidence/validation.md), [handoff](handoff.md), [design assets](../../../design/redesign-2026/README.md) and [DESIGN.md v2](../../../DESIGN.md).

The only external blocker is the ImageGen subscription usage limit. No paid fallback was used. Strict +/-4 pt matching is not passed; the reference set includes one confirmed lettering defect and unfinished consistency corrections. A draft PR is appropriate for reviewing the concrete work without implying final design acceptance.

Publication: [draft PR #33](https://github.com/itmax04/lingo/pull/33). Code/assets CI: [PASS, run 40545029185](https://github.com/itmax04/lingo/actions/runs/40545029185). The exact code commit is `031a156`; this does not waive the recorded visual acceptance gaps.

## Prompt 1 partial continuation — 2026-10-27

The owner authorized STEP 1–2 only and selected the prompt from `design/imagegen-prompts`. Both steps are complete.
`origin/main` was already an ancestor (`1e254e7`), so the merge was a no-op; documented CI workflows now replace the redesign-only workflow.
All twelve code review findings are fixed, with regression evidence in [STEP 1–2](evidence/step1-step2.md).

PASS: 112 Swift tests, 3 Python contrast tests, signed release build, strict codesign, voice-button clicks,
128 native 2× snapshots across dark/light × RU/EN, 19 exact tokens, 88 computed contrast pairs,
380 bilingual strings, English policy and secret scan (0 findings). No live provider or microphone tests were run.

[Representative snapshots](evidence/step2-snapshots/) and [capture hashes/dimensions](evidence/step2-snapshot-manifest.json)
record the new UI regression evidence. Exact ±4 pt acceptance is still NOT PASSED.

ImageGen, remaining reference repairs, geometry matching, WebP/size-budget delivery and ready-for-review are deferred STEP 3–5.
PR #33 stays draft. Resume only on the owner's next explicit instruction, after the generation limit resets where applicable.
