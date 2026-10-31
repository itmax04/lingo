# Lingo upgrade plan — evidence-based amendment

Status: accepted at H-U in DG-01 on 2026-10-29; documentary execution remains separately scoped · Version 1 · Source date: 2026-10-28 (Europe/Berlin)

DG-02 accepts LINGO-03 documents at H-0. DG-03 A permits only a future checked own docs PR/merge; the current adoption build is local only. See the [active P-00 ledger](../changes/P-00/handoff.md). The original 80 implementation rows, dependencies and future product gates below are unchanged; no code completion is inferred.
Scope: planning only; no application code, contracts, ADR decisions or issue states changed by this PR.

This amends [LINGO-03 plan](../changes/LINGO-03/plan.md), preserving P-01…P-20, H-0…H-5 and the [ROADMAP](../ROADMAP.md). Letter suffixes split existing steps into one-session PRs; they do not introduce product goals. [Start prompts](../process/STAGE-PROMPTS.md) use this amendment after H-U. Requirements remain in [LINGO-03 spec][S03], [LINGO-01 spec][S01] and accepted ADRs. LINGO-04/05/06 implementation outlines are conditional on their own future specs and H-0 gates, not authorization to implement unaccepted requirements.

## 1. Audit boundary and evidence

Read in the requested order: AGENTS → docs index → ARCHITECTURE/MAC/WEB/CODEBASE → EVOLVING/SDLC/TESTING/RELEASE/STAGE-PROMPTS → ADRs → ROADMAP → LINGO-03 intent/spec/plan/handoff → open issues and PRs. Then inspect code and PR #33 separately. Source references below are immutable GitHub file:line links; paths in implementation tables are future working paths after P-01.

| Snapshot | Observed state, 2026-10-28 |
|---|---|
| Documentation base | `origin/design/imagegen-prompts` = `48c19822f976f260d8f3f6042c71e0bf8e787154`; own worktree `~/Developer/lingo-upgrade-plan`, branch `docs/upgrade-plan` |
| Main | `origin/main` = `1e254e7a631d28200716821810e5c3fe05bfd0d1`; documents have not landed |
| Redesign | `origin/feat/redesign` = `4eab7cfb610aa7f99a71258b1f1aba0ba6483829`; inspected read-only |
| Open PRs | [#1](https://github.com/itmax04/lingo/pull/1) → main; [#31](https://github.com/itmax04/lingo/pull/31) → docs/handover; [#33](https://github.com/itmax04/lingo/pull/33) → main, **draft**, both current CI checks SUCCESS |
| Open issues | `gh issue list --state open --limit 100` returned #2…#30 and #32. #2 is pending H-0; #3…#26 implementation/checkpoints; #27 acceptance; #28/#29/#30 future epics; #32 redesign. No completed LINGO-03 step is inferred from an open issue |
| Reproduced | `swift test` on the documentation-base code: **PASS, 96 tests / 28 suites**, 2026-10-28. No live provider, microphone, Keychain, account, deployment or ImageGen action performed |
| Prior evidence only | PR #33 reports 112 tests, 380 bilingual strings, 128 fixture captures; current CI confirms its build/tests, **not** live audio or geometry acceptance. Its handoff explicitly leaves STEP 3–5 unfinished [E07] |

### What exists and what does not

| Area | Proven implementation / remaining limitation | Evidence |
|---|---|---|
| Standalone Mac | Swift package, macOS 15+/iOS 17 core targets, pinned whisper binary, Yams eval kit. This is not a native iPhone app | [Package.swift:6][E01]; [iOS check:2][E02] |
| Voice/dialogue | On-device recognition/voice pipeline, command routing, streamed replies, correction/hint/recap journal writes are implemented. The 30-minute acceptance is still open; no fresh latency or memory measurement in this audit | [TurnController:1][E03], [VoiceServices:1][E04], [DialogEngine:120][E05], [issue #9](https://github.com/itmax04/lingo/issues/9) |
| History | Append-only local events, fsync, unknown fields, deterministic merge, folder sync exist. This is not account sync | [Event:74][E08], [JournalIO:82][E09], [JournalStore:94][E10], [Merger:1][E11] |
| Export | Manual ZIP exists, but includes `devices` only; its comment promises cache too. Daily automatic backup/restore verification still outstanding | [SyncServices:63][E12], [issue #6](https://github.com/itmax04/lingo/issues/6) |
| Models | Provider fallback, retry-after, per-attempt usage records exist; no organization pool accounting or engine day plan yet | [ProviderChain:49][E13], [RateLimits:106][E14], [LLMSettings:4][E15] |
| Redesign | Implemented on a separate draft branch: native presentation, light/dark, RU/EN catalogs. Teacher/Today/Progress previews are not working teacher features; visual completion remains blocked/pending | [PR #33](https://github.com/itmax04/lingo/pull/33), [R07 spec][S07], [E07] |
| Web/engine/contracts | Event schema, golden event fixtures and OpenAPI exist; `apps/web`, `services/engine`, `packages/core-ts`, root npm workspace do not exist in the inspected trees. TS CI explicitly skips without package.json; schemas are design artefacts, not running endpoints | [CODEBASE:23][E16], [API:5][E17], [ci-ts:29][E18], [issue #10](https://github.com/itmax04/lingo/issues/10), `git ls-tree -r --name-only` on both inspected refs |
| Future roadmap | No Mac account adapter, teacher runtime or native iPhone app in these trees. Their open epics require a brainstorm/spec first | [#28](https://github.com/itmax04/lingo/issues/28), [#29](https://github.com/itmax04/lingo/issues/29), [#30](https://github.com/itmax04/lingo/issues/30) |

### Findings, ordered by severity

P0 = demonstrated critical loss/security incident; P1 = blocks correctness, privacy or acceptance; P2 = quality/capacity/process risk; P3 = documentation cleanup. **No confirmed P0 incident in this bounded review.** Prospective engine risks below are missing design/test coverage, not claims about deployed vulnerabilities.

| ID | Priority | Finding and failure scenario | Evidence | Planned treatment |
|---|---|---|---|---|
| F01 | P1 | Backup omits cached devices; restoring ZIP into a fresh base can omit visible history. Daily scheduling is absent from the existing export path | [E12], [E10], MR-04 | P-04a/b |
| F02 | P1 | Error redaction removes only key/organization patterns. An upstream error echoing an utterance flows through `LLMError.description` into public logs; leak path exists, actual exposure not observed | [SSEClient:162][E19], [LLMTypes:126][E20], [ProviderChain:191][E21] | P-02a; engine uses safe codes too |
| F03 | P1 | Eval uses host timezone, allows `--allow-daytime`, checks time only at launch, and applies budget **per model** concurrently. A batch crossing 08:00 or five models can violate the hard rule/budget | [Headless:69][E22] | P-02b before any model batch |
| F04 | P1 | 450 output tokens + 512 reasoning reserve = 962; chain estimates input + half of 450 instead. `finish_reason` is parsed then discarded; transcript-only cap excludes system/summary | [PromptBuilder:183][E23], [provider:34][E24], [chain:159][E25], [chain:278][E26], [ContextPolicy:13][E27] | P-02c/d |
| F05 | P1 | Health is keyed by key+model, not organization+model; settings have no organization/ownerRisk fields. Same-org keys can hit the same ceiling repeatedly | [E13], [E15], [ADR-0005][A05] | P-05c/d |
| F06 | P1 | Usage rows keep nil, but daily sums use `?? 0`; unknown usage looks free in totals. Service requests use the same chain; background TPM check is not a daily reservation | [RateLimits:183][E28], [DialogEngine:222][E29] | P-02c, P-05d, P-13b/c |
| F07 | P1 | Russian default in MR-03/#5 conflicts with `system` in PR #33 and old Prompt 1. Do not silently declare MR-03 satisfied | [S03], [InterfacePreferences:9][E30], [old prompt:43][E31], [#5](https://github.com/itmax04/lingo/issues/5) | H-U records precedence; P-03 verifies accepted default |
| F08 | P1 | Old LINGO-04 prompt invents device-flow/loopback auth; ADR-0003 §5 and OpenAPI instead prescribe revocable Settings-created device tokens | [old prompt:203][E32], [A03], [API:197][E33] | Restore device-token plan; alternative only Q2 |
| F09 | P1 | WS-05 disables offline input while WS-09 asks browsers to add offline messages. A reducer fixture is possible, but a user-facing offline composer is not implicitly authorized | [S03] scenarios WS-05/09 | P-00 records fixture-based sync test; Q3 only if owner wants composer |
| F10 | P1 | API lacks logout-everywhere/device-list operations; `Event`/SSE are generic objects. Delete response has no stale-client reset protocol, so old offline queues could repopulate deleted history | [API:45][E34], [API:189][E35], [API:223][E36], [API:274][E37], WR-02/24/25 | P-08b contract closure; P-12/P-18 tests |
| F11 | P1 | H-2 is prerequisite to P-08 in its row but setup needs the prepared Worker/D1 binding. P-18 depends only on shell although it needs server data/auth/budget APIs; P-19 can deploy before voice/behaviour/privacy | [old plan:33][E38], [old plan:48][E39], [#11](https://github.com/itmax04/lingo/issues/11), [#24](https://github.com/itmax04/lingo/issues/24) | H-2a setup after local skeleton; H-2b deploy after spike; full release gate |
| F12 | P1 | Phone fixed-reply spike measures capture/transcription/playback, not LLM latency or WAC-08. Push-to-talk fallback in plan does not waive WAC-05's continuous requirement | [#13](https://github.com/itmax04/lingo/issues/13), [S03], [old plan:37][E40] | H-3 documents capability; H-4 full pipeline; scope change requires owner |
| F13 | P2 | Existing stability command samples 20 seconds after settling and forces restart at second 11; no duration argument. This cannot certify 30 minutes | [AudioDiag:10][E41], MR-05 | P-05a + H-1 |
| F14 | P2 | Custom model-list 404/405 is simply failed; no bounded test-completion fallback | [KeyVerifier:28][E42], MR-06 | P-05b |
| F15 | P2 | ADR-0005's whole-day Workers AI estimate is not reproducible from its displayed inputs. 240 × (1965 input + 74 output) gives about **9059 neurons on 20b**, **16216 on 120b**, before service calls/STT, not 6600/11100 | [A05], [Workers AI pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/) | P-11 publishes formula, baseline/post-economy separately |
| F16 | P2 | Mac and engine share provider ceilings before LINGO-04, but engine cannot see standalone Mac calls. Per-model Workers AI pools also share one account-wide neuron allowance | [A05] consequences, [pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/) | Conservative Mac allowance; aggregate parent budget across models/STT; H-4 reconciles both ledgers |
| F17 | P2 | Several old steps exceed a reasonable session/600-line PR (P-05,07,08,13,15,16,18). P-02/P-05 overlap provider code; P-03/P-04/P-05 overlap settings/catalogs; blanket independence is false | [old plan:22][E43], [old plan:53][E44], [OtherSettingsViews:99][E45] | Split steps and explicit file ownership below |
| F18 | P2 | Redesign STEP 1–2 already fixed; retry date is only an estimate, not proof of ImageGen capacity. 37 geometry tasks/10 image repairs remain; green CI is not ±4 pt acceptance | [E07], [PR #33](https://github.com/itmax04/lingo/pull/33) | Resume residual work only; no timed retry loop |
| F19 | P2 | CI skips TS without package.json; build is `--if-present`; bundle scan prints matched lines and covers few key forms. Mac scripts are missing from the old Mac path filter | [E18], [ci-mac:5][E46], [secret-scan:15][E47] | P-01/P-07a/P-19a: fail-closed scripts, masked scanner fixtures |
| F20 | P2 | API says context window built on client while architecture assigns prompt/context budgets to engine; takeover/cancel/retry/Unicode character offsets need exact interoperable semantics before parallel implementation | [API:263][E48], [API:278][E49], [event schema:535][E50], [ARCHITECTURE:136][E51] | P-08b/c; enforce engine clipping, fixture supplementary characters, attempt IDs |
| F21 | P2 | FSRS package is not in ADR-0002 allow-list. Native signing/locked-screen/Live Activity feasibility is not proved by an iOS core compile | [A02], [E02], [old prompt:225][E52], [#30](https://github.com/itmax04/lingo/issues/30) | 05-a ADR gate; 06-a/b device feasibility before native build-out |
| F22 | P3 | Handoff still says nothing implemented/96 tests/English UI without branch qualification; AGENTS calls future directories “created in P-xx”; MAC import list omits AVFoundation actually used; SDLC mentions rebase despite no rewrite rule | [handoff:3][E53], [AGENTS:23][E54], [MAC:51][E55], [VoiceIO:1][E56], [SDLC:54][E57] | P-00 truthful status; P-01 command/map updates; append-only branch integration |

### Current external constraints (verified, not account-specific measurements)

- Workers Free: 100,000 requests/day, 10 ms CPU, 128 MB memory. Network wait does not count as CPU, but JSON/schema work does: measure at maximum supported batch/body sizes. [Official limits](https://developers.cloudflare.com/workers/platform/limits/).
- D1 Free: 500 MB/database, 5 GB/account, 5 M reads and 100 k writes/day. Index writes count; use indexed cursors, bounded batches and test export/compaction with stale clients. A `db.batch()` counts once toward invocation query count; individual statement limits still apply. [Limits](https://developers.cloudflare.com/d1/platform/limits/), [pricing](https://developers.cloudflare.com/d1/platform/pricing/).
- Groq public free table still lists GPT-OSS 120b/20b at 30 RPM / 1000 RPD / 8000 TPM / 200000 TPD, Whisper turbo at 20 RPM / 2000 RPD / 7200 ASH / 28800 ASD. Organization-specific exceptions and input/output TPM caps exist. Obtain only non-secret limits from owner at H-2; reverify before P-10. [Official limits](https://console.groq.com/docs/rate-limits).
- Workers AI has **one 10,000-neuron daily free allocation**. Reserve chat, fallback STT and service traffic together; a model being listed is not enough to assume it is available without billing. [Official pricing](https://developers.cloudflare.com/workers-ai/platform/pricing/).
- Lingo must never retain audio. Groq documents reliability/abuse retention exceptions unless Zero Data Retention is enabled. H-2 requires owner verification of ZDR for transcription; check fallback retention too before enabling real audio. Do not promise provider-side zero retention merely because Lingo drops the buffer. [Groq data controls](https://console.groq.com/docs/your-data).
- Native provisioning/entitlements remain a device gate, not a planning promise; consult the current [Apple account documentation](https://developer.apple.com/help/account/basics/about-your-developer-account) at 06-a and test both phones. No paid enrollment.

## 2. Explicit delta from the existing plan

| Existing plan/prompt | Added / changed / removed | Why |
|---|---|---|
| H-0 and old handoff | **Add P-00 + H-U** to approve this amendment, record conflicts and refresh issue checklists. Do not auto-close #2 merely because a prompt says H-0 is done | #1/#31 remain open; acceptance must be evidenced |
| LINGO-07 Prompt 1 | **Remove redoing completed STEP 1–2**; retain checks after merging docs; split remaining asset/geometry batches into bounded PRs stacked on #33 | Preserve completed work and truthful draft status |
| P-01 | Keep atomic rename-only move per ADR-0004; add cache isolation, redesign paths, contract fixture parity paths and scanner exclusions | Relocation must not change behaviour or silently bypass checks |
| P-02 | Split privacy/error boundary, night guard, accounting/reserve, then prompt economy; add input cap and uncertain totals | F02–F06; measured headroom rather than blindly hardcoding 300 |
| P-03/P-04 | Reuse catalogs from redesign; verify Russian default unless owner accepts Q1. Fix existing export, add scheduler separately | Avoid duplicate implementation; preserve MR-03/MR-04 |
| P-05/P-06 | Split stability/key probe/pool model/pool UI; translate by document batches | Reviewable sessions; no blanket parallel claim |
| P-07/P-08 | Split ports and skeleton/auth/contracts. Add missing endpoint schemas and race/recovery fixtures before consumers | Contracts are incomplete; local work requires no real secrets |
| H-2/P-09 | **Change H-2 into H-2a setup + H-2b owner deploy**; bring minimum STT limits/reservations into spike | No public unbudgeted proxy; no setup cycle |
| P-10/P-11 | Add resumed ≤15-attempt batches, explicit total ceilings, all providers sharing global allowance, cache-cold and failed-attempt costs | 60 cases × 5 candidates is at least 300 calls, not a 15-request task |
| P-12…P-18 | Split server and UI surfaces; add deletion reset/stale queue tests, compaction recovery, lease/cancel fencing, server-side input enforcement | Cover promised behaviour before production |
| P-19/P-20 | CI work may start early; **release waits for all P-12…P-18 and WAC evidence**. Add H-4a release and H-4b two-day trial, retain H-5 | Fix premature deployment dependency |
| LINGO-04 | Use ADR-0003 device tokens; optional engine turns only after account sync; local fallback remains explicit | Remove unaccepted auth substitution |
| LINGO-05/06 | Add bounded conditional implementation slices, dependency/entitlement checks and separate acceptance gates | Epics currently only specify document acceptance |
| Session policy | **One step = one session = one PR**; use same stage prompt again to resume smallest ready step; no per-step approval request | Owner's requested execution unit, stage autonomy retained |

No product goal is removed. LINGO-07 stays before Stage 0 as in the current start sequence. O-20's original dark-only description has later owner redesign decisions R-01/R-06/R-08; apply approved light/dark and navigation without moving teacher logic forward. Alternatives appear only in §8.

## 3. Execution contract for every row

All rows inherit this section, their stage entry/exit gates and the verification profiles. **No row authorizes accounts, keys, secrets, console/system settings, force-push or branch deletion. Current P-00 preparation is local files/patches only, without publication, live canonical edits or application changes.** Future separately scoped build work may push/open/merge ready PRs only after current checks, independent review and applicable H-x; no main push, force, history rewrite or bypass. Production and remote migrations remain owner-run. `L` = owner's Mac only; `C` = cloud or local, mocks only; `L/O` = local preparation, owner performs live gate. Mixed Swift/TS changes are **L**. Image generation uses existing subscription only, within available allowance; 429 ends generation work, never paid fallback.

- Every step: one issue/sub-issue, isolated worktree, one session, one PR, handoff with tested SHA and PASS/FAIL/NOT RUN. No auto-spawned agents. Parallel rows mean eligibility for separately authorized sessions.
- Size is **changed text lines including tests/docs**, target 150–450, ceiling about 600; pure renames measured with `git diff --numstat -M`. Binary assets get byte budgets separately. If the proposed patch exceeds 600, split the named row into suffixes with the same requirements and explicit predecessor; do not hide a second feature in a “test” follow-up.
- Shared behaviour: fixtures/contracts first; update every **existing** Swift and TS implementation in the same PR. Stage 0 has no TS runtime yet: Swift + neutral fixtures are the reference consumed by P-07. Do not invent a second implementation just for the move.
- No raw owner utterances/audio/keys in evidence. Synthetic fixture text is language data; operational logs contain safe metadata only. Live owner practice is distinct from automated evals.
- Model evals/bulk calls: Berlin 23:00–08:00, recheck before **every** attempt/retry, stop at 08:00 or first exhausted cap. ≤15 provider attempts per batch, retries included; one model at a time; explicit request/token/audio/neuron caps and remaining reserve recorded. No `--allow-daytime`, no paid route, no “zero” unknown usage. Mock/offline tests can run anytime.
- D04-01 supersedes D01-02: R2/R3 implementation and review are AI-only, without a mandatory human reviewer. Actual AI session/role, reviewed SHA, checks and findings are required before dependent release. R1 local preparation uses author self-review.
- Required acceptance remains the owner's decision; conditional future executor merges follow dependency order after checks/review/gates. Historical owner-merge wording names required merged predecessors, not current P-00 publication authority. While waiting, stack on the tested predecessor SHA and target that predecessor branch. After a squash merge, integrate main with a normal merge commit and verify the diff/base; never rebase/force-push. Shared handoff/catalog/manifest edits are integrated sequentially by the row owner.
- ADR allow-lists only. Pin versions. FSRS/new code generator/new real-time infrastructure requires an accepted ADR before adding dependencies. No third-party framework is implied by a table path.

### Verification profiles (commands run from repository root)

These are command definitions used by each row, not claims they already ran. Planned commands/tests must be created by the identified prerequisite row and must fail if their suite is absent; “0 tests” is not a pass. All code rows also run **D**.

| Profile | Exact commands / required output | Availability |
|---|---|---|
| D | `git diff --check`; `scripts/check-english.sh`; `scripts/secret-scan.sh`; `git diff --numstat -M` | Existing; 0 secret findings required before push; do not print raw scanner matches |
| M | `swift build --package-path apps/mac`; `swift test --package-path apps/mac`; `apps/mac/scripts/check-core-ios.sh` when core changes | P-01 creates paths; before move use root commands; local only |
| B | `apps/mac/scripts/build-app.sh`; `codesign --verify --strict dist/Lingo.app` | P-01 preserves root dist contract; before move `scripts/build-app.sh` |
| V | `python3 scripts/check-design.py`; `dist/Lingo.app/Contents/MacOS/Lingo --ui-click-test`; `scripts/redesign-snapshots.sh` | From #33; P-01 repairs paths; synthetic screenshots only |
| T | `npm ci`; `npm test`; `npm run build` | P-07a establishes mandatory scripts, extends as workspaces land |
| E | `npm run test -w services/engine -- --run` | P-08a creates script; local D1/mocked network; named acceptance cases in each PR |
| W | `npm run test -w apps/web -- --run`; `npm exec -w apps/web -- playwright test` | P-09b establishes spike harness; P-15a expands Chromium/WebKit flows |
| C | `swift test --package-path apps/mac`; `npm run test -w packages/core-ts -- --run` | P-07a onward; same contracts; run locally when Swift changes |
| N | `TZ=Europe/Berlin date '+%F %T %Z'`; signed app `--eval-dialog packages/contracts/evals/dialog work/evals --max-cases 10 --budget 15 --models <one-model>` | L only, after P-02b guard; substitute a verified model, sanitized outputs only. P-10a publishes exact engine runner command in handoff |
| I | `apps/mac/scripts/check-core-ios.sh`; `xcodebuild -project apps/ios/Lingo.xcodeproj -scheme Lingo -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build` | 06-b creates project/generation command with allowed XcodeGen; local only; unsigned build is not install evidence |

For future LINGO-04/05/06 document rows: `test -s docs/changes/LINGO-NN/spec.md` and D, plus requirement-to-step review; implementation rows wait for the accepted spec. The IDs below are **reserved proposed IDs** that their first document row must define; links are to current roadmap/epics until those files exist.

## 4. Stages and owner gates

| Stage | Goal / result for owner | Entry | Exit | Owner checkpoints |
|---|---|---|---|---|
| Plan reconciliation | One executable source of order and acceptance | This review PR | Conflicts resolved, issues mapped, no silent ADR edits | H-U; existing H-0 still requires #2 evidence |
| LINGO-07 completion | Reviewed Mac design + usable references for later web | #33 latest state, docs merged, H-U | Residual repairs measured, assets ≤30 MB, ready PRs; no teacher runtime | H-07a resume confirmation; H-07b visual acceptance/merges |
| LINGO-03 Stage 0 | Safe history, economical stable Mac, monorepo | H-0/H-U; #1/#31/#33 and follow-ups owner-merged | MR-01…08 evidence, baseline exported, no unresolved P1 in changed surfaces | H-1: 30 min, RU UI, restore rehearsal |
| Stage 1 | Evidence that web voice and $0 capacity are viable | H-1, Stage 0 PRs merged | Ports/skeleton, device matrix, quality comparison and day table | H-2a setup; H-2b spike deploy; H-3 device results and acceptance of voice capability |
| Stage 2 | PWA + engine usable across web devices | H-3 accepted, P-11 complete; agreed fallback if necessary | WAC-01…14 report, two full days, no history loss; Mac history still separate | H-4a release; H-4b trial (existing H-4); H-5 acceptance |
| LINGO-04 | Same history on Mac and web; optional engine turns | H-5 | Revocable device token, offline recovery, idempotent import, standalone fallback | H-04-0 spec; H-04-1 token/import/device check; H-04-2 acceptance |
| LINGO-05 | All four teacher areas within daily quota | H-04-2 | Memory, FSRS warm-up, scenarios/plans, progress/reports on Mac/web | H-05-0 spec/ADR; H-05-1 personal review; H-05-2 week evidence/acceptance |
| LINGO-06 | Native phone with locked-screen voice; speed where feasible | H-05-2 | Both phones proven after re-signing, measured real-time or explicit turn-based fallback | H-06-0 spec; H-06-1 provisioning feasibility; H-06-2 device/7-day trial; H-06-3 acceptance |

### P-00 — document and issue reconciliation (C, 200–450 lines)

Preparation detail: [P-00 delivery plan](../changes/P-00/plan.md), P00-D01…D05, refines this existing row without adding product goals or renumbering P-01…P-20. Accepted P00-SPEC-02 and the actual owner decision chain govern the preparation boundary. The amendment itself remains proposed until H-U.


Goal: turn this amendment into accepted execution inputs. Requirements: [S03] and [intent O-01…O-22][INT], SDLC Definition of Ready. Files: LINGO-03 intent/spec/plan/handoff, ROADMAP status, AGENTS/process contradictions; issue bodies #2…#30/#32. Depends: H-U. Acceptance: record H-0/H-U evidence and Q1 resolution; spec/plan links point here, old parent IDs retained, child issues have acceptance checks and predecessor IDs; WS-09 is fixture replay unless owner changes offline scope; no future spec claimed accepted. Verify: D; `gh issue list --state open --limit 100`; `gh pr list --state open --limit 100`; manual crosswalk against §5. Risk: unauthorized scope change; do not resolve product alternatives by fiat. Owner only: acceptance. The current no-publication preparation may create reviewable drafts before H-U; formal canonical/issue adoption waits for H-U, actual H-0 evidence and separately authorized adoption/publication. Future executor merge authority is conditional under §3. This documentation step may precede redesign completion; Stage 0 code may not.

### P-00 preparation slices (local only, before formal adoption)

| Slice | Depends | Observable delivery | Boundary |
|---|---|---|---|
| P00-D01 | Accepted P-00 spec/plan; phase start/brainstorm | Pinned inputs, decision and parent-issue crosswalk | Read-only sources; no remote issues |
| P00-D02 | D01 | Targeted AGENTS/process/roadmap/LINGO-03 amendments as proposals; source IDs and 80 rows retained | No adopted requirement changes |
| P00-D03 | D02 | One English document candidate/patch at exact clean base, including prior preparation records | Local files, no live application/publication |
| P00-D04 | D03 | AC-linked document/patch/privacy checks and reviewable H-U/H-0 dossier | Owner answers are not invented |
| P00-D05 | D04 | Honest local implementation evidence and self-contained verification packet | Pending gates preserved, no PRs |

The P00-D preparation chain is not formal P-00 reconciliation. H-U/H-0 and any adoption/publication permission remain separate human nodes after a reviewable dossier; they are not prerequisites for drafting that dossier. Q1 is decided in D01-01: Russian first-run with explicit Russian/English/System preferences preserved. Q3 remains read-only offline history with seeded queue fixtures. Neither decision claims a code fix or accepts all of H-U. Future Q2/Q4/Q5/Q6/Q7 stay at their own gates. A later folder called build does not change the P-00 scope.

## 5. Implementation steps and dependency table

A row is a PR/session. `All P-xx` means every suffix in that family. Requirement cells link to authoritative specs; abbreviated M/W/C/E/etc are verification profiles from §3. Every stage entry gate also applies even when not repeated in a row. Size estimates are not permission to exceed the ceiling.

### LINGO-07 — residual work on #32/#33

Current [R07 requirements][S07]; no core/prompts/providers/schema changes here. New PRs stack on #33 in separate worktrees; preserve #33 draft until all required follow-ups are incorporated/merged by owner. Existing 12 review fixes are verified, not rewritten.

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| 07-a Integrate accepted docs, preserve existing UI fixes | R07-03/05/08 | DESIGN.md §9, CI, redesign handoff, root scripts | P-00, H-07a; owner merges #1/#31 | Exactly one Mac job, both catalogs compile, web adaptation retained, 12 regression fixes pass; root M+B+V+D | Merge conflict; L; 150–350 |
| 07-b Repair pending image set | R07-01/02/03/07 | `design/redesign-2026` named targets, blocked-work.json, manifest | 07-a | One PR/session per ≤5 targets; 10 blocked targets + keys Add defect + six architecture diagrams reconciled without double-counting; at most 3 successful attempts/target; inspect actual pixels, label planned; V+D | Subscription 429; L; 100–250 text, ≤2 MB assets/batch |
| 07-c Correct remaining consistency families | R07-02/03/04 | Platform references, manifests | 07-b | One PR/session per ≤5 screens for mark, tabs, controls, destructive red and light system sheets; explicit per-screen PASS/FAIL; V+D | OCR alone insufficient; L; 100–250 text, ≤2 MB/batch |
| 07-d Align production geometry | R07-03/05/07 | Mac Views/Design, `production-repair-tasks.json`, comparison evidence | 07-c | Repeat bounded suffix PRs per 1–3 screens until all 37 tasks adjudicated; 1280×800 pt at 2×, measured max deviation ≤4 pt or explicit unresolved FAIL; root M+B+V+D | Large shared views; serial same-file work; L; 250–500 each |
| 07-e Package and report | R07-07/08 | WebP references, README, comparison table, handoff/report | All 07-b/c/d | Tracked references ≤30 MB; original PNGs only owner-authorized delivery folder; app remains dist; every screen status and signature verified; `du -sh design/redesign-2026`; B+V+D | Binary budget/history; L; 150–350; H-07b owner accepts/merges, squash #33 |

### LINGO-03 Stage 0 — keep P-01…P-06 and issues #3…#8

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| P-01 Atomic layout move | [MR-01][S03], ADR-0004 | Swift package → apps/mac; snapshots/evals → contracts; scripts/CI/maps/allow-list | P-00, H-07b | No behavioural diff; fixtures unchanged; own worktree build caches; root dist output; M+B+V+D; rename-aware diff ≤600 text edits | Path/cache collisions; L; 300–550 plus pure renames |
| P-02a Safe errors | [MR-02, WR-28][S03], AGENTS §6.10 | core LLM/SSE/errors/chain, safe-log tests, contract error fixtures | P-01 | Synthetic upstream body containing utterance/key never reaches logs/UI diagnostic text; preserve status/retry fields; M+D | Losing useful limit diagnostics; L; 180–350 |
| P-02b Enforce eval budget/night | [MR-02][S03], AGENTS §6.5 | Headless, DialogRunner, clock/budget tests, shared eval policy fixtures | P-02a | Reject daytime/override, 08:00 boundary, DST, depleted total budgets; cap retries across models, no key suffix in output; M; N only after guard passes | Batch overrun; L; 250–450 |
| P-02c Correct usage/reserve model | [MR-02][S03], ADR-0005 | LLMTypes, provider/chain, RateLimits, QuotaTests, contracts policy fixtures | P-02b | Record stop reason; unknown count/bounded reservation remains visible; estimate matches sent cap incl. reasoning; synthetic p99 distribution; M+D | Truncation / legacy usage decoding; L; 300–500 |
| P-02d Compact prompts/input cap | [MR-02][S03] | PromptBuilder, ContextPolicy, snapshots, eval evidence | P-02c | System target ≤900 tokens; total cap includes system/summary/latest turn with explicit oversize policy; measured ≤1.8k input+reserve target; 10 live-turn evidence only budgeted/night or natural owner H-1; dialog rules ≥90%, no_pronunciation 100%, no length stops; M+N+D | Quality regression; L; 300–550 |
| P-03 Verify RU/EN instead of rebuild | [MR-03][S03] | Mac InterfacePreferences, catalogs, localization check, CI | P-01, Q1 recorded at H-U | Fresh preferences match accepted default; explicit RU works on en-US Mac; 0 missing strings; dates/menu/service messages follow locale; M+B+V+D | Default conflict; L; 150–350 |
| P-04a Complete safe export/restore | [MR-04][S03] | SyncServices, new Journal export helper, backup tests, RELEASE | P-01 | ZIP includes own+cached events and restore metadata, no secrets/audio; restore into temp base yields same event IDs/state; failure/cancellation leaves source intact; M+D | Partial archive/identity collision; L; 250–500 |
| P-04b Daily backup | [MR-04][S03] | backup scheduler, AppSettings, DataSettings UI/catalog, RELEASE | P-04a, P-03 | Chosen folder bookmark; once/day while app active or next launch; atomic export, revoked access/error shown; injected-clock tests; M+B+V+D; owner selects folder at H-1 | Sleep/permission failure; L; 250–450 |
| P-05a Duration/recovery harness | [MR-05][S03] | AudioDiag, App CLI dispatch, AudioRecoveryTests | P-01 | Duration validated, deterministic counters/exit status, stop remains stopped; M+B; owner `dist/Lingo.app/Contents/MacOS/Lingo --audio-stability work/audio-stability.txt --duration 30` at H-1 | Mic/TCC; L/O; 180–350 |
| P-05b Custom key probe | [MR-06][S03] | KeyVerifier, KeysController, tests/catalog | P-03, P-02c | Only custom 404/405 triggers one bounded completion with selected configured model; 401/429 preserved; no bulk key probing; M+D; optional single signed live check | “One token” model incompatibility, no retry loop; L; 180–350 |
| P-05c Organization pools | [MR-07][S03], ADR-0005 | LLMSettings, ProviderHealth/ChainFactory, pool fixtures/tests | P-02d | Same-org keys share cooldown/reserve; different model/org ceilings stay distinct; legacy settings migrate without key reads; ownerRisk toggle/order tested; M+D | Misassigned org labels; L; 300–550 |
| P-05d Pool UI/service routes | [MR-07, MR-02][S03] | Keys/Quota settings, catalogs, purpose routing/usage tests | P-05c, P-05b, P-04b | Owner labels/toggle explicit; background work avoids primary shortage, unknown totals visible; main-only fallback tested; M+B+V+D | Overlapping catalogs/chain; L; 250–500 |
| P-06a Translate normative legacy docs | [MR-08][S03] | LINGO-01 docs, ADR-0001, allow-list | P-01 | One file/section batch per suffix PR ≤500 changed lines; IDs/decisions unchanged; no translation exceptions for completed files; D | Semantic translation error; C; 250–500 each |
| P-06b Remaining descriptions/checks | [MR-08][S03] | references, contracts/evals descriptions, allow-list, repo CI | All P-06a, P-02d | No pending-translation entries; utterances and evidence unchanged; D; M if fixture files touched | Accidentally translating test data; L if fixtures, otherwise C; 250–500 each |

H-1 waits for **all** Stage 0 rows, including backup/pools/English migration. A successful 20-second diagnostic or 96 unit tests is insufficient.

### Stage 1 — keep P-07…P-11 and issues #10/#12/#13/#15/#16

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| P-07a Workspace/harness | [WR-29, WAC-07][S03] | root package/lock/tsconfig, core-ts test setup, ci-ts | H-1 | Strict TS, pinned allow-list deps, mandatory test/build scripts, no skipped/empty suite pass; T+D | Lockfile growth: stage approved minimal packages per suffix; C; 250–500 |
| P-07b Event/ULID parity | [WR-05/08][S03] | core-ts/events types/codec/ulid, event fixtures/tests | P-07a | Preserve unknown data and millisecond ordering; round-trip sample fixture; invalid input rejected; C+T | JS numeric/Unicode precision; L; 300–500 |
| P-07c Reducer parity | [WR-08][S03] | core-ts/events/merge, reducer tests | P-07b | Golden expected state; seeded commutativity/idempotency, tombstones, equal timestamps; C+T | Tie ordering divergence; L; 300–550 |
| P-07d Reply parser | [WR-11/21][S03] | core-ts/protocol, neutral parser fixtures | P-07a | Swift/TS same segments for every chunk boundary, malformed/partial lines and interruption offsets; C+T | Streaming boundary bugs; L; 250–450 |
| P-07e Commands | [WR-21][S03] | core-ts/commands, command fixtures/tests | P-07a | Commands ≥95%, false positives ≤3%, local repeat/slower never call provider; C+T | Vocabulary drift; L; 250–450 |
| P-07f VAD/segmenter | [WR-20][S03] | core-ts/voice, shared timelines/tests | P-07a | Same fixed-clock outputs; cuts ≤10%, false merges ≤5%; C+T | Audio frame-time mismatch; L; 300–550 |
| P-08a Local Worker/D1 | [WR-27/29][S03] | engine config/index, migration 0001, E harness, workspace scripts | P-07a | Local D1 migrations repeat safely on clean db; static/API route split; no remote binding/secrets; E+T+D | Wrong DB target; C; 250–500 |
| P-08b Close API omissions | [WR-02/04/11/12/24/25][S03] | contracts OpenAPI + error/SSE/deletion fixtures, schema validation tests | P-08a, P-07b/d | Typed stream events and purpose enum (including hints where used); revoke-all/device list operations; reset generation/cursor semantics; cookie vs future bearer rules; server clips context; bounded custom settings; E+C | Broad contract change: split auth/privacy vs turn suffixes if >600; L; 300–550 each |
| P-08c Auth/session isolation | [WR-01…04][S03] | engine/auth/index, account/session migration additions, tests | P-08b | Reject replay/missing/forged state, foreign ID, wrong Origin, forged/expired cookie; sliding expiry; every read/write account-scoped; OAuth scope none; E+T | Auth boundary; C; 350–550 |
| P-09a Bounded STT spike backend | [WR-17/18/28][S03] | engine/transcribe, minimal ledger/budget migrations/tests | P-08c | Auth + 4MB/60s guard before forwarding, reserve ≥10s, duplicate request doesn't double bill, abort/unknown settled conservatively; no body logs; E+T | An exposed unbudgeted spike; C; 300–550 |
| P-09b Spike page | [WR-20/26][S03] | web voice-spike page, mic/recorder/player/metrics tests, W harness | P-09a, P-07f | User-gesture mic/TTS, MIME probing, fixed reply, tap-stop/PTT/continuous, Wake Lock lifecycle; export only timings; W+T | Safari routing, no full-turn proof; C; 350–550 |
| P-09c Deploy packet | [WR-27][S03] | RELEASE, spike device protocol/evidence templates | P-09b, H-2a | Exact owner commands/config IDs/non-secret origins ready; dry-run bundle and local migration pass; `npm exec -w services/engine -- wrangler deploy --dry-run`; E+D | Deploy must be owner-run; L/O; 150–300 |
| P-10a Language set/runner | [WR-14, WAC-08][S03] | contracts/evals/language, Mac eval or engine eval harness, safe result schema | P-02b, P-07a, P-08c | 20 EN +20 DE +20 RU switches, synthetic; all cases identified, runner resumes exact offsets and caps total attempts/resources; mocks prove time gate; M+T; publish exact signed/bound runner invocation | Runner may not exist for language set; split set/harness into ≤550-line PRs; L; 300–550 each |
| P-10b Candidate evidence | [WR-14, WAC-08][S03] | sanitized evidence and routing recommendation | P-10a, H-2a | One ≤15-attempt session/PR per batch; cover 60 cases/candidate over nights; 5 candidates ≤300 initial + ≤150 bounded retries in entire study, per-batch token/neuron cap from remaining allowance; rule scores and blind acceptability (target ≥80%) reported; N with P-10a command | Quota/quality; L; 100–250 evidence per batch; owner-risk pools not baseline capacity |
| P-11 Calibrate day plan | [WR-15, WS-11][S03] | handoff capacity table, routing configuration/ADR evidence | All P-10b, H-1, H-3 | Formula includes 240 measured/adjusted turns, STT min charge, summaries/hints/recaps, retries, cache-cold input, standalone Mac allowance and global neurons; publish baseline vs optimized headroom; `python3 apps/mac/scripts/metrics.py`; T+D | Model table ≠ real account limits; L; 180–350 |

H-2a follows P-08c/P-09a local preparation; no need to block P-07/P-08 on real credentials. H-2b follows P-09c and deploys spike. H-3 follows H-2b/P-09; P-10 batches can run before/after H-3 within night budget. P-11 waits for both model and device evidence. This order has no H-2/P-08 cycle.

### Stage 2 — keep P-12…P-20 and issues #17…#26

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| P-12a Durable sync | [WR-05…08][S03] | engine/sync, indexed events migration, core-ts sync tests | H-3, P-11, P-08b/c, P-07c | Same ID/content idempotent; same ID/different content 409; authenticated device ownership; transaction/cursor safe with own events and pagination; 2×25 fixture events converge to 50; E+C | Skipped page/data injection; L; 350–550 |
| P-12b Archive/restore hygiene | [WR-10][S03] | engine/data archive helper, additive migration, RELEASE | P-12a | Threshold before 400MB, export verified before compaction, tombstones and stale cursor bootstrap survive restore; max-batch CPU/D1 reads/writes measured with synthetic data; E+T | Data loss from naive compaction; C; 300–550; destructive remote work owner only |
| P-13a Prompt/context port | [WR-11/16][S03] | engine/turn/prompt builder/context, contracts snapshots | P-02d, P-07d, P-08b | Byte-identical prompts all modes/languages; enforce total server budget even for crafted large window/customPrompt; E+C | Client-trusted prompt budget; L; 300–550 |
| P-13b Reservation ledger | [WR-12/15][S03] | engine/ledger, attempts/budgets migration/tests | P-11, P-08b/c | Atomic reserve under concurrency; UTC day rollover; aggregate Workers AI cap across models/STT; preserve unknown usage; never overspend on racing calls; E+T | Double reserve/unknown spend; C; 350–550 |
| P-13c Routes/adapters | [WR-14/15][S03] | engine/turn/router/adapters, safe errors, ledger integration | P-13b, P-13a | Main-org pools then optional ownerRisk then Workers AI; shared-org limits, retry-after, bounded retry/refusal/timeout; service routes preserve dialogue headroom; E+T | Ambiguous outcome must not blindly regenerate; C; 350–550 |
| P-13d Turn lifecycle/leases | [WR-12/13][S03] | engine/turn state/status/cancel/lease, migrations/tests | P-13c, P-12a | Concurrent same turn → at most one provider attempt; takeover fences old writer; lease renewal/expiry; cancel before/during/after done; uncertain reconciliation does not fake result/usage; E+T | Races and orphaned attempts; C; 350–550 |
| P-13e SSE/budget API | [WR-11/15][S03] | engine/turn stream, ledger budget endpoint, tests | P-13d | Typed meta/delta/sentence/segment/usage/done/error; attempt restart flushes pending speech; client disconnect cancels; completed reply/status recoverable without a new call; E+T | Already-spoken text cannot be “unheard”; C; 300–500 |
| P-14 STT hardening | [WR-17][S03] | engine/transcribe fallback/duration validation, ledger integration | P-09a, P-13b | Real MIME cases via synthetic fixtures; reject forged duration/oversize, min 10s; verified no-retention fallback only; retries charged, unknown remains reserved; E+T | Duration parsing/CPU/retention; C; 300–500 |
| P-15a Visual shell/PWA | [WR-19/22/23][S03] | web/app/design/i18n, manifest/service worker, browser tests | H-3, 07-e, P-07a | RU default, EN switch, tokens only, tabs/sidebar, 44px targets/safe areas; no fabricated teacher data; 390×844/820×1180/1280×800 × themes × languages; W+T | Image concepts mistaken for runtime; C; 350–550 |
| P-15b Offline store/sync | [WR-09/22][S03] | web/store/api, IndexedDB, SW caching policy | P-15a, P-12a, P-07c | Persist request/queue, ack retry, visibility/open/turn/manual sync; WS-05 read-only offline; WS-09 via seeded queues; eviction bootstrap; no API/audio caching; W+T | Stale queue/data reset; C; 350–550 |
| P-15c Conversation/text flow | [WR-19/21][S03] | web/features/conversations, api/turn | P-15b, P-13e | Create/resume session, text turn, error/reconnect, one reply per turn; screenshot layouts and keyboard; W+T | Duplicate optimistic events; C; 300–500 |
| P-16a Capture lifecycle | [WR-20/26][S03] | web/voice mic/VAD/recorder/wake lock, tests | P-15c, P-14, P-07f, H-3 | PTT/continuous per accepted gate; interruption by background/permission/route change handled; zero persisted audio; metrics marks present; W+T | Device-only capture failures; C; 300–500 |
| P-16b Speech/cancellation | [WR-20/26, WAC-06][S03] | web/voice player/controller, turn client/tests | P-16a, P-13e, P-07e | Local repeat/slower zero network; stale turn/attempt never speaks, cancel aborts, tap-stop fallback labelled; fake-clock race tests; W+T; real recheck H-4b | Safari echo and resume gesture; C; 350–550 |
| P-17a Dialogue behaviour | [WR-21][S03], [R-14…28/51][S01] | web correction/hint/star features, core-ts behaviour fixtures | P-16b, P-07d/e | Correction modes, edit original transcript, @heard, four nonempty hint sections, star/unstar converge; fixture parity; C+W | UI may expose hidden corrections; L; 350–550 |
| P-17b Service calls/recap | [WR-21/15][S03], [R-22/23/27][S01] | engine service-purpose orchestration, web recap, fixtures | P-17a, P-13c/e | Topic phrases once/session, summary only on new turns, recap follows selected mode, retries idempotent; cancellation/new turn prevents duplicate background work; E+C+W | Background quota and RU discipline; L; 300–550 |
| P-17c Engine quality evidence | [WAC-07/08][S03] | engine eval adapter + sanitized report | P-17b, P-10a | Route through actual engine prompt path; all rules ≥90%, no_pronunciation 100%; language set reviewed, no untested candidate counted; E+N with documented P-10a runner | Stage 1 comparison isn't engine acceptance; L; 150–400 plus bounded evidence batches |
| P-18a Account data lifecycle | [WR-02/24/25, WAC-13][S03] | engine/auth devices/revoke, data export/delete, migrations/tests | P-12b, P-13d, P-08b | Account-only export/deletion includes events/turns/attempts/budgets/leases; revoke sessions; stale device receives reset before upload; no deleted data resurrection; E+T | Offline clients cannot be remotely erased while disconnected; C; 350–550 |
| P-18b Settings/privacy UI | [WR-24/25][S03] | web/settings/onboarding/resources, local logout/reset | P-18a, P-15c, P-13e, P-16b | First-run disclosure/mic test; voices/rate/T/G/mode; devices and revoke-all; budget/unknowns; logout clears IndexedDB/SW private caches/tabs; offline revoked device clears before next sync; W+T | Foreign-computer remnants; C; 350–550 |
| P-19a Mandatory CI/security | [WR-18/29][S03] | ci-ts/ci-repo/ci-mac, scanner fixtures | P-15c, P-08c | Tests/build cannot skip present workspaces, WebKit+Chromium, masked secret canaries rejected without value output; exactly one path-filtered Mac job; T+W+D | macOS free minutes/false positives; C; 200–400 |
| P-19b Release packet | [WR-27, WAC-14][S03] | RELEASE, config/migration inventory, smoke checklist | All P-12…P-18, P-19a | Clean clone M+T+W; dry-run deploy; backup/restore and compatible Worker rollback documented; one text/voice smoke, latency/CPU/write budgets ready for owner; E+D | DB rollback cannot blindly undo data; L/O; 200–400 |
| P-20 Evidence/acceptance report | [WAC-01…14][S03] | report/handoff, README/AGENTS/maps/ROADMAP | H-4b | Each WAC links tested SHA, command, output or owner observation; both Mac and engine ledgers reconcile two 4×30 days; no NOT RUN recast as PASS; D | Missing device/quality evidence; C; 250–500; stop H-5 |

### LINGO-04 — issue #28; conditional spec IDs 04-R1…R5

The current authority is [ROADMAP][ROAD] and [epic #28](https://github.com/itmax04/lingo/issues/28), not an existing LINGO-04 spec. 04-a defines `docs/changes/LINGO-04/spec.md`: R1 token auth, R2 import/sync, R3 standalone/offline, R4 optional engine turns, R5 devices/privacy. Every later row must link those accepted spec sections before starting.

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| 04-a Specify account transition | [ROADMAP/#28][ROAD], proposed 04-R1…5 | docs/changes/LINGO-04 set, ADR-0003 clarification only if needed | H-5 | Import/identity/folder coexistence and token revoke UX defined; no client OAuth secret; `test -s docs/changes/LINGO-04/spec.md`; D; stop H-04-0 | Scope/auth drift; C; 250–500 |
| 04-b Device-token lifecycle | 04-R1/5 after 04-a | contracts API, engine tokens, web Settings token UI, tests | H-04-0 | Owner creates token in Settings; shown once, hashed at rest, scoped/revocable, no echo/log; web cookie Origin still enforced, bearer scope tested; E+W+T | Token leakage; C; 350–550 |
| 04-c Mac account adapter | 04-R1/3/5 after 04-a | Mac account client/Keychain UI/settings/catalog/tests | 04-b | Owner pastes token only into app; invalid/revoked states, account ID pinned, sign-out doesn't destroy standalone history; M+B+V | Keychain/signature; L; 300–500 |
| 04-d Historical import | 04-R2 after 04-a | Mac sync adapter/import, contract ownership fixtures, engine import validation | 04-c | Backup-first; old mac device IDs and cached other writers mapped explicitly; server ownership rule not disabled; retry import yields exactly same IDs/state; M+E+C | Unauthenticated writer impersonation; L; 350–550 |
| 04-e Incremental/offline sync | 04-R2/3/5 after 04-a | Mac sync queue/cursor and account UI, tests | 04-d | Two-device edit/tombstone/unknown fields; offline backlog, cursor expiry/deletion reset, no duplicate folder/engine events; M+C+E; H-04-1 device run | Divergence/reupload after deletion; L; 350–550 |
| 04-f Optional engine turns | 04-R3/4 after 04-a | Mac engine turn adapter/settings, shared cancellation fixtures | 04-e, H-04-1 | On-device STT unchanged; optional route, local standalone fallback, uncertainty reconciled before retry; M+C+E; no double billing on engine drop | Ambiguous fallback charges; L; 350–550 |
| 04-g Acceptance report | 04-R1…5 after 04-a | report/handoff/maps | 04-f | Mac+phone history and revoke/delete tests; engine outage still allows standalone mode; safe metrics; D+M+T; H-04-2 | Incomplete real-device proof; L/O; 150–300 |

### LINGO-05 — issue #29; conditional spec IDs 05-R1…R5

05-a defines `docs/changes/LINGO-05/spec.md`: R1 memory controls, R2 FSRS/warm-up, R3 scenarios/exams/day plan, R4 progress/weekly report, R5 role budgets/privacy/parity. This preserves **all four** owner teacher areas, O-04/O-05, without adding scoring or gamification goals.

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| 05-a Teacher spec/ADR | [ROADMAP/#29][ROAD], proposed 05-R1…5 | LINGO-05 docs, ADR allow-list proposal for FSRS if used | H-04-2 | Explicit data retention/edit/delete, card selection, report cadence, 4×30 limits, no pronunciation; FSRS dependency licensed/pinned or own implementation specified; `test -s docs/changes/LINGO-05/spec.md`; D; H-05-0 | Unapproved library/implicit paid service; C; 300–550 |
| 05-b Teacher contracts/store | 05-R1/2/5 after 05-a | contracts events/API, core-ts+Swift compatible codecs, engine migrations | H-05-0 | Additive v1 events, old clients preserve unknowns; stable card/memory IDs, isolated accounts; C+E | Breaking old history; L; 350–550 |
| 05-c Learner memory engine | 05-R1/5 after 05-a | engine/teacher memory APIs/selection/tests | 05-b | Per-language editable/deletable memory, provenance and bounded prompt selection; deletion removes future prompt use; E+T | Stale/invented personal memory; C; 300–500 |
| 05-d Memory controls UI | 05-R1 after 05-a | web teacher/memory; Mac equivalent in separate suffix | 05-c | Show actual stored facts, edit/delete, no hidden memory; W or M+B+V per client; H-05-1 owner review | Personal data in screenshots; C web / L Mac; 200–400 each |
| 05-e FSRS scheduling | 05-R2/5 after 05-a | engine/teacher/cards/scheduler, contract fixtures | 05-b | Deterministic fixed-clock reviews; retry/idempotency, timezone/day boundary, own mistakes/starred words only; E+C | Scheduling/library mismatch; L for fixtures; 300–500 |
| 05-f Warm-up/vocabulary | 05-R2 after 05-a | web Today/Vocabulary; Mac equivalent separate suffix | 05-e | Review actions update scheduling once, no pronunciation score; actual due cards, never fabricated counts; W or M+B+V | Offline duplicated review; C web / L Mac; 250–450 each |
| 05-g Plans/scenarios/exams | 05-R3/5 after 05-a | engine teacher planner/prompts, shared fixtures/evals | 05-c, 05-e | 2 DE+2 EN; Germany/work, B1 Goethe/telc and IELTS-style speaking; bounded partner/analyst/planner calls; rules fixtures; E+C+N | Teacher consumes practice quota; L; 350–550 |
| 05-h Scenario/day-plan UI | 05-R3 after 05-a | web Today/session setup; Mac equivalent separate suffix | 05-g | Real plan/resume/scenario controls, no exam certification or pronunciation ratings; W or M+B+V | Placeholder mistaken for completion; C web / L Mac; 250–450 each |
| 05-i Progress/report engine | 05-R4/5 after 05-a | engine teacher progress/weekly, budgets, fixtures | 05-g | Aggregates trace to events; weekly report one per interval with safe retry and budget; deletion/recompute; E+C+N | Hallucinated progress/background spend; L; 300–500 |
| 05-j Progress/report UI | 05-R4 after 05-a | web Progress/Teacher; Mac equivalent separate suffix | 05-i | Show period, real counts, missing-data/limit state; W or M+B+V | False precision; C web / L Mac; 200–400 each |
| 05-k Teacher acceptance | 05-R1…5 after 05-a | evidence/report/handoff | 05-d/f/h/j, H-05-1 | Week record, target ≥70 reviewed cards/week and ≥85% blind acceptability, 120 minutes/day still fit; no_pronunciation 100%; N+M+T+D; H-05-2 | Short trial cannot prove weekly benefit; L/O; 200–350 |

### LINGO-06 — issue #30; conditional spec IDs 06-R1…R5

06-a defines `docs/changes/LINGO-06/spec.md`: R1 free provisioning, R2 thin client/account, R3 locked-screen/headphones, R4 real-time/adaptive turn pipeline with fallback, R5 memory/latency/privacy. Old ADR-0001 LINGO-02 local-model candidate lists do not revive the dropped LINGO-02 goal.

| ID / goal | Requirements | Files / areas | Depends | Acceptance and commands | Risk; execution; size |
|---|---|---|---|---|---|
| 06-a Native feasibility spec | [ROADMAP/#30][ROAD], proposed 06-R1…5 | LINGO-06 docs, entitlement/install matrix, ADR if needed | H-05-2 | Both phones, free signing/SideStore route, OS/entitlement uncertainty, re-sign recovery and memory cap acceptance defined; `test -s docs/changes/LINGO-06/spec.md`; D; H-06-0 | No guaranteed Live Activity/free entitlement; L; 250–450 |
| 06-b Minimal install probe | 06-R1/3/5 after 06-a | apps/ios project.yml/probe, allowed XcodeGen generation, install guide | H-06-0 | Unsigned I build; exact owner signing/install steps; owner verifies mic+headphones+lock-screen and required entitlements on both phones, no secrets captured; H-06-1 | Account/device setup owner only; L/O; 250–450 |
| 06-c Thin account/history client | 06-R2 after 06-a | apps/ios account/history, reused Mac-independent core, contracts tests | H-06-1, 04-e | Token import/revoke, same event history, offline display/sync, deletion reset; I+M+C | Accidentally importing AppKit; L; 350–550 |
| 06-d Locked-screen voice | 06-R3/5 after 06-a | apps/ios voice/audio lifecycle, tests | 06-c | Both phones: foreground→lock→headphones route change→resume; no audio persisted; interruption/permission failures visible; I+M, H-06-2 device metrics | Background suspension/thermal pressure; L; 350–550 |
| 06-e Real-time contracts/spike | 06-R4/5 after 06-a | contracts timelines/cancel semantics, engine spike, Swift/TS fixtures; ADR before new transport | 06-d | Measure free-tier feasibility, partial/speculative work charged and cancelled, no late speech; compare ≤2s median target to turn-based baseline; I+C+E+N | Additional infrastructure not automatically allowed; L; 350–550 |
| 06-f Adaptive endpoint/fallback | 06-R4/5 after 06-a | shared segmenter fixtures/Swift/TS, native controller | 06-e | No duplicate turns or speculative commits; cuts/false merges thresholds retained; free/slow-network failure returns to honest turn-based mode; I+C+E | Speculation quality/quota; L; 350–550 |
| 06-g Native acceptance | 06-R1…5 after 06-a | report/handoff/install runbook | 06-f, H-06-2 | Both devices after 7-day re-sign/update, history/key access behaviour recorded, memory/latency/locked-screen evidence; I+M+T+D; H-06-3 | A simulator cannot certify provisioning; L/O; 200–350 |

## 6. Dependency and parallel-work audit

The Depends columns are the detailed dependency table. Rows with repeated suffix batches chain in order within the family; a consumer waits for **all** batches. Gates inherit all stage rows declared in §4. Future specs do not depend on their implementation. No cycles: stage rank is reconciliation → 07 → 03/0 → 03/1 → 03/2 → 04 → 05 → 06; within each stage every row references an earlier row or an owner gate whose inputs are earlier rows.

| Safe parallel candidates after prerequisites | File boundary / integration rule |
|---|---|
| P-02a…d vs P-05a vs P-04a vs P-06a | LLM/dialogue vs AudioDiag vs new export helper vs legacy docs. Shared App dispatch/settings/catalog changes wait for their owning row |
| P-03 and P-04a | Interface preferences/catalog vs export backend; P-04b waits for P-03 |
| P-07c/d/e/f | events/merge vs protocol vs commands vs voice; freeze root workspace in P-07a; fixture subdirectories separate |
| P-09b and P-10a | spike UI vs eval dataset/harness; no parallel edits to root manifests/handoff |
| P-12a, P-13a/b, P-15a | sync vs prompts/ledger vs shell; migrations assigned unique sequential numbers by one integrator, never independently reuse 0002 |
| P-14 and P-15b | transcription implementation vs browser local store; ledger interface frozen in P-13b |
| 05-c and 05-e; web/Mac suffixes of 05-d/f/h/j | memory vs scheduler; different client trees after contracts are stable |

Do **not** parallelize P-02c/d with P-05c/d (LLM/chain), P-03/P-04b/P-05 UI (catalogs/settings), 07 geometry tasks touching the same view, contract edits consumed by both clients before fixture freeze, or writes to a common handoff. Each authorized session uses its own worktree; shared manifests, lockfiles, migrations and handoff updates serialize. A lack of merge is handled with stacked PRs, never by skipping dependency tests.

Critical path (longest actual duration depends on device/night/ImageGen availability): H-U/P-00 → docs merge/07 completion/H-07b → P-01 → P-02/P-05 + remaining Stage 0 → H-1 → P-07/P-08/P-09 → H-2b/H-3 + P-10 nights → P-11 → P-12/P-13/P-14/P-15 → P-16/P-17/P-18 → P-19b → H-4a → H-4b (two days) → P-20/H-5 → 04 → 05 (week observation) → 06 (7-day re-sign observation). P-19a CI preparation is not a release shortcut.

## 7. Owner-only actions and release gates

Executor prepares a **Russian numbered checklist** with exact ready paths, URL, build SHA and non-secret configuration values at each gate; the English table below is its source. Owner never pastes secrets or personal journals into chat. No real-audio forwarding before retention checks; no cloud credentials.

| Gate | Ordered owner actions | Evidence supplied back (non-secret) |
|---|---|---|
| H-U / H-0 | Review this exact amendment and recorded Q1/Q3 dispositions; separately confirm spec precedence and H-0 acceptance; review #1, then retarget/merge #31 to main; this stacked docs PR is retargeted after its base lands. Confirm redesign continuation separately | Acceptance wording/date; PR URLs; Q1 choice |
| H-07a/b | Explicitly resume remaining STEP 3–5; if subscription unavailable leave blocked. At delivery review measured differences and outstanding FAILs; merge green redesign PRs in dependency order; squash #33 | Accepted screen table, merge SHAs; never infer completion from reset time |
| H-1 | Merge Stage 0 PRs; run provided signed build; choose backup folder in app; export and restore to an isolated test location; grant microphone access yourself if needed; run 30-minute diagnostic and separate 30-minute live session; exercise repeat/slower/barge-in; confirm RU/EN | Counter-only diagnostics, turn count, median/p90, token totals, cutoffs/refusals, backup equality; no audio |
| H-2a setup | From prepared `services/engine`, run pinned `npx wrangler login`; verify Free plan/no billing upgrade. Run `npx wrangler d1 create lingo`; provide non-secret database ID. Executor writes binding/config. Create prod/dev GitHub OAuth Apps, scope none, callbacks `https://<actual-worker>.workers.dev/auth/callback` and `http://localhost:8787/auth/callback`; provide client IDs only. Enter `GITHUB_CLIENT_SECRET`, `SESSION_PEPPER`, `GROQ_KEY_MAIN` with `npx wrangler secret put <NAME>` in correct environment; optional owner-risk pools only if chosen. Verify Groq ZDR for transcription and fallback policy. Report actual limits without keys | Worker name/URL, D1 ID, client IDs, numeric GitHub ID, Boolean setup/ZDR completion and safe limit table. Real dev credentials, if needed, entered only locally by owner; mock tests require none |
| H-2b spike | After P-09c and green PRs, run `npx wrangler d1 migrations apply lingo --remote`, then `npx wrangler deploy` from prepared engine directory; verify GitHub sign-in and single synthetic voice smoke | URL/build SHA, sign-in/smoke status, no secret values |
| H-3 devices | On iPhone Air/11, iPad, Android, Windows and Mac browsers: record OS/browser/MIME/voice/headphones; 10 voice turns and 10 barge-ins each; test denied mic, background/resume, Wake Lock and tap-stop. Review continuous capability before Stage 2 | Timing matrix; phones ≤0.7s in ≥8/10, Mac browser ≤0.5s in ≥9/10 or documented failure; not full LLM latency acceptance |
| H-4a release | Merge complete Stage 2 stack; export safe database backup to local private storage; run prepared migration/deploy commands yourself; sign in, one text and one voice turn; check budget; use documented rollback if smoke fails | Deployed SHA, migration IDs, smoke result, no backup contents |
| H-4b / H-5 | Run 2 DE+2 EN ×30 min on two days using phone and standalone Mac; install iOS/Android PWA; foreign-computer sign-in/out; two-web-device history test; delete test data and reopen a stale browser. Review WAC report and accept only supported results | Both ledgers' aggregate usage, latency/comfort/device evidence; no assertion Mac/web history sync exists yet |
| H-04-0/1/2 | Accept spec/import/folder policy; create revocable token in web Settings and paste directly into Mac app; export existing history; perform import + phone/Mac offline recovery + token revoke; accept report | Event counts/hash equality, device status; never token value |
| H-05-0/1/2 | Accept teacher spec and any dependency ADR; review/edit/delete actual memory in app; use warm-ups/scenarios for a week; inspect progress/report and remaining 120-minute capacity | Aggregate review counts and quality notes; private memory remains in app |
| H-06-0/1/2/3 | Accept spec; personally sign in to Apple/SideStore, enable device settings/install/re-sign using prepared instructions; test both phones with locked screen/headphones, update and 7-day re-sign; accept measured fallback/limitations | OS/device/signing result, history survival, memory/latency counters; no Apple credentials |

## 8. Questions and separate proposals (not silently adopted)

Current recorded dispositions (2026-10-29): Q1 is decided in D01-01; Q3 is a fixture clarification preserving WS-05 read-only behavior. Q2/Q4/Q5/Q6/Q7 remain deferred to their named gates. The table retains historical alternatives, not unresolved requests to re-ask Q1/Q3. [D04-01](../changes/P-00/review-policy-2026-10-29.md) replaces the prior human-review policy; H-U/H-0 remain pending.

None prevents producing this plan. Q1 is resolved by D01-01: Russian first-run, retaining explicit Russian/English/System. Q3 preserves read-only offline history with seeded queue fixtures; later questions belong to their indicated gates. If an owner chooses an alternative, update the relevant intent/spec/ADR **before implementation**, never weaken §6 rules.

| ID / when | Recommended option | Alternative and consequence |
|---|---|---|
| Q1 H-U | Keep MR-03 Russian first-run default; preserve explicit user-selected System/English. Record correction of the contradictory redesign prompt | Accept System default as deliberate new requirement, amend MR-03/#5 and WAC-01 wording; do not pretend current code meets Russian-default requirement |
| Q2 H-04-0 | Keep ADR-0003 Settings-created device tokens | Native OAuth device/loopback is a separate auth ADR/spec proposal, not part of this plan |
| Q3 P-00 / H-U | Keep read-only offline product and seed WS-09 queues through test harness | If user-authored offline messages are desired, explicitly change WS-05/WR-20 and threat/queue UX; this adds behaviour, not assumed |
| Q4 H-3 | Retain WAC-05; if continuous mode fails, stop affected production voice work and document the blocker | Owner may accept a revised PTT-only platform requirement with tap-stop; WAC-06 fallback alone does not authorize dropping continuous mode |
| Q5 H-04-0 | Preserve local journal/folder mode, backup first, opt-in account import; deduplicate original event IDs | Disable legacy folder sync only by owner decision after verified migration |
| Q6 H-05-0 | Keep FSRS; approve an allow-list entry only after concrete library/license/version review, or choose an audited dependency-free implementation | A different repetition algorithm would change roadmap scope and needs explicit approval |
| Q7 H-06-1 | Prove $0 signing/locked-screen behaviour first; keep turn-based fallback when real-time cannot meet constraints | No paid account/API fallback. Unavailable entitlement remains a blocker or separately accepted scope adjustment |
| Proposal A (optional, not in DAG) | Preserve current redesign-before-Stage-0 order | If ImageGen remains blocked, owner could decouple remaining references from Mac stabilization to shorten the critical path; requires explicit sequence change and stable UI baseline |

### Decision compliance checklist

| Decisions | Preserved execution consequence |
|---|---|
| O-01/02/08/11 | Phone-first PWA; Mac standalone/on-device STT; actual device matrix; locked-screen native later |
| O-03/06/10 | $0; 4×30 remains acceptance, not estimate; owner-risk pools labeled/disableable and not baseline capacity |
| O-04/05/19 | Web → Mac account → all four teacher parts/scenarios → native; no earlier teacher runtime |
| O-07/09/18 | Engine, OAuth allow-list, monorepo, contracts first; native token auth follows ADR-0003 |
| O-12/13/14/15/16/21 | Codex executor, whole-stage autonomy via bounded sessions; local Mac, own worktrees; issues/milestones/PRs; separately scoped executor merges after checks/AI review/H-x; Russian summaries |
| O-17/20/22 | Stage 0 before web construction; approved redesign adaptation; no public/friends signup, isolation architecture retained |
| ADR-0001…0005 and 0007 | Existing stack/allow-lists; no local Mac LLM revival; no new authentication/transport/library without accepted ADR; visual-only redesign |

## 9. Verification and handover

- Planning evidence: baseline Swift tests PASS (96/28); current #33 CI PASS; live microphone, provider evals, devices, production, signing and ImageGen **NOT RUN in this planning task**. No device acceptance claimed.
- Planning delivery checks: **PASS** whitespace, English policy and full secret scan (0 findings); **PASS** immutable source-anchor bounds and relative links; **PASS** 80 unique six-field implementation rows and an acyclic 101-node step/gate graph (repeated batches inherit their family edges). Markdown-only changes do not warrant rerunning live suites.
- Per-step self-check: every implementation row has requirement, files, dependency, observable acceptance, command profile, risk, execution location and size. Repeated image/translation/eval/client batches are separate suffix issues/PRs, never one unbounded session.
- Critical release coverage: WAC-01 → H-1; 02/03 → P-08c; 04 → P-12a/P-15b + H-4b; 05/06 → P-16 + H-4b; 07 → P-07/P-13a; 08 → P-17c; 09 → H-4b; 10 → P-02a/P-19a; 11 → P-15a/b + H-4b; 12 → P-15a/P-18b; 13 → P-18a; 14 → P-19b. P-20 reconciles all evidence.
- Immediate next action after this PR: owner review at H-U. Executor must not run a stage simply because this planning PR exists. No need to ask implementation questions before delivering the reviewable plan.

## Source references

All local evidence below is pinned to the audited documentation commit unless explicitly pinned to redesign. Line anchors refer to that snapshot even after P-01 renames files.
[S03]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/spec.md#L1
[S01]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-01/spec.md#L1
[INT]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/intent.md#L55
[ROAD]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/ROADMAP.md#L7
[A02]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/decisions/ADR-0002-web-stack.md#L1
[A03]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/decisions/ADR-0003-authentication.md#L1
[A05]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/decisions/ADR-0005-model-routing-and-quota.md#L1
[E01]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Package.swift#L6
[E02]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/scripts/check-core-ios.sh#L2
[E03]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Dialogue/TurnController.swift#L1
[E04]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoMac/VoiceServices.swift#L1
[E05]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Dialogue/DialogEngine.swift#L120
[E08]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Journal/Event.swift#L74
[E09]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Journal/JournalIO.swift#L82
[E10]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Journal/JournalStore.swift#L94
[E11]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Journal/Merger.swift#L1
[E12]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoMac/SyncServices.swift#L63
[E13]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/ProviderChain.swift#L49
[E14]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/RateLimits.swift#L106
[E15]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/LLMSettings.swift#L4
[E16]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/architecture/CODEBASE.md#L23
[E17]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L5
[E18]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/.github/workflows/ci-ts.yml#L29
[E19]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/SSEClient.swift#L162
[E20]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/LLMTypes.swift#L126
[E21]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/ProviderChain.swift#L191
[E22]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoMac/Headless.swift#L69
[E23]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Dialogue/PromptBuilder.swift#L183
[E24]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/OpenAICompatibleProvider.swift#L34
[E25]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/ProviderChain.swift#L159
[E26]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/ProviderChain.swift#L278
[E27]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Dialogue/ContextPolicy.swift#L13
[E28]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/RateLimits.swift#L183
[E29]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Dialogue/DialogEngine.swift#L222
[E31]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/process/STAGE-PROMPTS.md#L43
[E32]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/process/STAGE-PROMPTS.md#L203
[E33]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L197
[E34]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L45
[E35]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L189
[E36]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L223
[E37]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L274
[E38]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/plan.md#L33
[E39]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/plan.md#L48
[E40]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/plan.md#L37
[E41]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoMac/AudioDiag.swift#L10
[E42]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/LLM/KeyVerifier.swift#L28
[E43]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/plan.md#L22
[E44]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/plan.md#L53
[E45]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoMac/Settings/OtherSettingsViews.swift#L99
[E46]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/.github/workflows/ci-mac.yml#L5
[E47]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/scripts/secret-scan.sh#L15
[E48]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L263
[E49]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/api/openapi.yaml#L278
[E50]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/packages/contracts/events/event.schema.json#L535
[E51]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/architecture/ARCHITECTURE.md#L136
[E52]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/process/STAGE-PROMPTS.md#L225
[E53]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/changes/LINGO-03/handoff.md#L3
[E54]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/AGENTS.md#L23
[E55]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/architecture/MAC.md#L51
[E56]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/Sources/LingoCore/Audio/VoiceIO.swift#L1
[E57]: https://github.com/itmax04/lingo/blob/48c19822f976f260d8f3f6042c71e0bf8e787154/docs/process/SDLC.md#L54
[S07]: https://github.com/itmax04/lingo/blob/4eab7cfb610aa7f99a71258b1f1aba0ba6483829/docs/changes/LINGO-07-redesign/spec.md#L1
[E07]: https://github.com/itmax04/lingo/blob/4eab7cfb610aa7f99a71258b1f1aba0ba6483829/docs/changes/LINGO-07-redesign/handoff.md#L1
[E30]: https://github.com/itmax04/lingo/blob/4eab7cfb610aa7f99a71258b1f1aba0ba6483829/Sources/LingoMac/Design/InterfacePreferences.swift#L9
