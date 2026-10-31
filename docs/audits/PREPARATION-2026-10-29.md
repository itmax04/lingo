# Lingo preparation baseline — 2026-10-29

Status: historical factual preparation report. Later DG-01/DG-02 accepted H-U/H-0, and DG-03 A accepted conditional own docs PR/merge authority; see the [active ledger](../changes/P-00/handoff.md). The original observations below are not new runtime checks or product implementation acceptance.

## Inspected versions

| Scope | Branch | Commit |
|---|---|---|
| Architecture and proposed upgrade plan | docs/upgrade-plan | 22ec44de924f79eaa867c816c08276bb5c88484f |
| Mac redesign implementation | feat/redesign | 4eab7cfb610aa7f99a71258b1f1aba0ba6483829 |
| Primary checkout | design/imagegen-prompts | 48c19822f976f260d8f3f6042c71e0bf8e787154 |
| Remote main | main | 1e254e7a631d28200716821810e5c3fe05bfd0d1 |

Local worktrees were clean. GitHub read-only queries confirmed PRs #1, #31, #33 and #34 open and unmerged; #33 remains draft. Issue #2 remains open. The source packet manifest matches 198 documentation-tree and 675 redesign-tree Git blobs. Availability of admin/push access does not authorize publication.

## Implementation boundary

The root Swift package implements the standalone Mac app. The redesign branch adds presentation, light/dark appearance and bilingual catalogs. Event schemas, fixtures and OpenAPI exist on the documentation branch. Neither inspected tree contains the root npm workspace, apps/web, services/engine, packages/core-ts or apps/mac/Package.swift. The iOS core target is not a native iPhone app. Teacher/account screens are visual concepts, not working services.

The following discrepancies were verified without accessing personal runtime data:

| Finding | Pinned source path and line | Required next evidence |
|---|---|---|
| Manual ZIP exports devices but not cache | SyncServices.swift:63 and JournalStore.swift:94, under Sources/LingoMac and Sources/LingoCore/Journal respectively | Synthetic complete-history restore rehearsal, MR-04 |
| Provider error text can reach public logs | Sources/LingoCore/LLM/SSEClient.swift:162; LLMTypes.swift:126; ProviderChain.swift:191 | Safe error-code boundary before live evals |
| Eval launch uses host clock, daytime override and per-model budgets | Sources/LingoMac/Headless.swift:69-121 | Berlin/DST/per-attempt/global-budget guard tests |
| Output cap and admission estimate disagree | Sources/LingoCore/Dialogue/PromptBuilder.swift:202; LLM provider adds 512; ProviderChain.swift:159 | Consistent reservations and uncertain usage |
| Missing token usage sums to zero | Sources/LingoCore/LLM/RateLimits.swift:190 | Explicit unknown usage in totals |
| Russian default conflicts with System default | docs/changes/LINGO-03/spec.md:29; redesign Sources/LingoMac/Design/InterfacePreferences.swift:9 | Q1 decision at H-U |
| Stability harness measures 20 seconds | Sources/LingoMac/AudioDiag.swift:31 | Duration support, then owner H-1 |
| Future TS CI can succeed without TS runtime | .github/workflows/ci-ts.yml:29-42 | Actual workspace checks after its creating step |

These are source-level observations, not claims that a real privacy incident or history loss occurred. Full details and safe evidence are in the accompanying phase packet. At this preparation inspection, the upgrade plan was proposed; later acceptance is recorded separately in DG-01. This audit itself accepts no new requirements.

## Checks performed locally

- docs/upgrade-plan: swift test --skip-update --disable-automatic-resolution passed, 96 tests in 28 suites.
- feat/redesign: the same command passed, 112 tests in 30 suites.
- Redesign design validation passed: 19 tokens, 88 computed contrast pairs, 380 bilingual strings; 3 Python contrast tests passed.
- Documentation branch English policy passed; tree/index secret scan returned zero findings. Full history scan was not repeated.
- Four existing worktrees passed git diff --check and remained clean.
- GitHub Actions reports successful applicable workflows at the exact four PR heads. These are observed remote results, not new CI runs.

Not run: live providers, Keychain, microphone, signing/release builds, iOS core build, device tests, 30-minute stability, ImageGen, deployment, migrations and full-day capacity acceptance. Green unit tests do not certify visual geometry or devices.

## Next step and authority

Product cursor stays P-00 (SDLC preparation). The owner explicitly agreed to survey, local files/patch and a prepared phase-01 packet without application changes or GitHub publication. No new external-session materials were reported. Next: a separate phase-01 brainstorm to agree intent, source precedence, risk and autonomy; prepare concrete H-U/H-0 decisions, including Q1. Existing read-only offline behavior uses seeded queue fixtures; production and remote migrations remain owner-run. Preserve the roadmap order and all pending gates.
