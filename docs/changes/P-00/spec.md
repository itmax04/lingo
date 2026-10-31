# P-00 preparation specification

Active adoption status: later DG-01/DG-02 accept H-U/H-0 documents, and DG-03 A provides conditional own docs PR/merge authority; see the [active ledger](handoff.md). P00-ADOPTION-SPEC-02 v1 covers the separate documentary operation. The accepted preparation requirements/scenarios below remain unchanged and are not product requirements.

## Historical preparation record

The following preparation record predates DG-01/DG-02/DG-03. Its then-pending gates and local-only authority are historical; the active decision ledger above takes precedence. Existing requirements and completed preparation evidence are preserved.

ID: P00-SPEC-02. Version: v1 with owner-authorized review-policy amendment D04-01. Date: 2026-10-29 (Europe/Berlin).
Status: ACCEPTED in D02-01 on 2026-10-29, covering this preparation specification and its AC/design boundaries.

This English transport record accompanies the full phase-02 SPEC, AC matrix, decision records and evidence. It specifies P-00 documentary preparation only. It does not replace LINGO-03 product requirements, accept H-U/H-0, authorize application implementation or grant publication rights. The local patch remains unapplied and unpublished.

## Accepted inputs and inspected versions

P00-INTENT-01, P00-CONTRACT-01 and P00-RISK-01 v1 were accepted in D01-03. D01-01 requires Russian on the first Mac launch without a saved preference, preserving explicit Russian/English/System choices. D01-02 is historical and superseded by D04-01: AI-only implementation/review for R2/R3, no mandatory human reviewer. No future AI release review is claimed completed. D02-01 explicitly accepts P00-SPEC-02 v1 and the 12 AC/design boundaries for documentary P-00 planning, preserving pending H-U/H-0. Read-only offline history with seeded queue fixtures and owner-run production/migrations remain unchanged.

Documentation baseline: clean docs/upgrade-plan, 22ec44de924f79eaa867c816c08276bb5c88484f. UI baseline: clean feat/redesign, 4eab7cfb610aa7f99a71258b1f1aba0ba6483829. Remote main: 1e254e7a631d28200716821810e5c3fe05bfd0d1. These snapshots do not override later confirmed live changes.

## Requirements

| ID | Required preparation behavior |
|---|---|
| P00-R01 | Remain within local documents/patches and safe packet transfer. No product code, schema, runtime-data or remote-state mutation. |
| P00-R02 | Validate real predecessor outputs, STATE and integrity before dependent work. WAITING_PREDECESSOR and boilerplate are not ready evidence. |
| P00-R03 | Record source SHA, branch, dirty/access state and observation date. Preserve stale or dirty inputs; do not reset another person's work. |
| P00-R04 | Maintain one source for each requirement, decision, implementation fact and evidence. Preserve existing product IDs and roadmap order; distinguish historical, proposed and accepted. |
| P00-R05 | Evidence names the criterion, version, environment, command/observation, expected, actual, status and path. Human acceptance is dated and scoped. COMPLETED or green CI does not accept H-x. |
| P00-R06 | Carry D01-01 exactly, retaining the visible implementation gap: current redesign still defaults to system. UI language does not change the learning dialogue language. |
| P00-R07 | Carry D04-01: AI-only execution/review for R2/R3, without a mandatory human reviewer. Require actual AI review/session and reviewed SHA before dependent release; missing review does not block R1 preparation. |
| P00-R08 | Preserve $0/no-card, no secrets/audio/personal runtime journals in packets, no utterances in diagnostics and no pronunciation assessment. Current P-00 has zero provider/ImageGen attempts and new CI runs. |
| P00-R09 | Errors/retries preserve existing files and a partial handoff. Never overwrite a started, damaged or unverified target; a fresh cycle directory is allowed. No clean/reset/history rewrite. |
| P00-R10 | An English local patch identifies the clean base and passes apply-check without being applied or published. Owner-facing packet outputs remain Russian. |
| P00-R11 | The next packet is self-contained: scaffold, context, library, methodology/tools, decision/artifact chain, clean HEAD snapshot and result index. Ready requires a separate ready check and transfer verification. The next phase remains not started and needs a new brainstorm. |
| P00-R12 | Every preparation requirement and scenario has an observable AC. Spec completeness, product verification and owner acceptance are separate; N/A needs a reason and NOT RUN is never PASS. |

## Scenarios

| ID | Given / when / then |
|---|---|
| P00-S01 | Given accepted intent, real prior outputs and a clean base, when spec/AC and checks complete, then deliver the local patch and verified next packet while preserving pending product gates. |
| P00-S02 | Given missing/boilerplate predecessor inputs, when starting dependent work, then block it and recover actual available results; do not invent completion. |
| P00-S03 | Given a running check/transfer, when reporting progress, then report actual IN_PROGRESS state rather than speculative PASS/READY. |
| P00-S04 | Given a hash/missing-file/read-stat mismatch, when validating input/target, then retain the original, record safe expected/actual metadata and use a verified scaffold at a fresh target. Never rebaseline the manifest to hide a mismatch. |
| P00-S05 | Given stale SHA or dirty live files, when comparing incoming and live, then preserve both versions and reassess dependent claims/patch. Clean-snapshot export stays blocked until its prerequisite is met. |
| P00-S06 | Given a previous target, staging folder or accepted decision, when resuming, then inspect handoff/state; preserve history and scoped acceptance. Reuse only a verified suitable state, otherwise use a fresh cycle path. |
| P00-S07 | Given denied live/GitHub access but a verified snapshot, when preparing documents, then state the limitation and allow snapshot-based proposals; current-state/build/release claims remain blocked without evidence. |
| P00-S08 | Given a future R2/R3 release without a reviewer, when deciding readiness, then block dependent merge/release, name the missing AI review/SHA evidence and continue safe R1 preparation. |
| P00-S09 | Given actual acceptance of particular preparation artifacts, when updating records, then accept only that stated scope; do not close product gates by implication. Silence leaves proposals proposed. |
| P00-S10 | Given D01-01 and current D04-01 (superseding D01-02), with unchanged code, when writing outgoing documents, then preserve the language/review decisions and mark implementation unverified; do not ask the same question again without a new conflict. |
| P00-S11 | Given unsafe credential-like values, audio, personal runtime data or symlink paths, when inspecting export, then stop the affected transfer without printing values; do not weaken the privacy check. |
| P00-S12 | Given failed assembly/ready/hash/link checks, when ending the phase, then retain NOT READY and a partial diagnosis; retry only with a concrete correction and relevant verification. |

These are preparation workflow states, not new app screens. Reuse the packet helper's input/execution states and the evidence contract's result statuses. Keep document acceptance and product gates separate from technical readiness.

## Acceptance matrix

Each AC points to the correspondingly numbered requirement; scenario coverage is explicit. The full packet's AC-MATRIX.json is the machine-readable trace index.

| AC | Requirement | Scenarios | Observable verification |
|---|---|---|---|
| P00-AC01 | P00-R01 | S01, S03 | Scope/artifact/action inspection and clean Git; zero runtime/remote mutations. |
| P00-AC02 | P00-R02 | S01, S02, S03 | Existing packet integrity/ready command plus actual incoming artifacts/result inspection. |
| P00-AC03 | P00-R03 | S05, S07 | Pinned source and live Git/connector observations include access/dirty limitations. |
| P00-AC04 | P00-R04 | S09, S10 | Trace direct decisions to their source and preserve canonical product IDs/specs/ADRs. |
| P00-AC05 | P00-R05 | S03, S09, S12 | Inspect dated/scoped owner records and honest evidence/statuses; H-U/H-0 remain pending. |
| P00-AC06 | P00-R06 | S10 | Compare D01-01, MR-03 and current system-default code without claiming a runtime fix. |
| P00-AC07 | P00-R07 | S08, S10 | Compare exact owner review policy across outputs; reviewer remains unassigned and future review not run. |
| P00-AC08 | P00-R08 | S01, S11 | Safe path/pattern inspection plus semantic export review and actual action scope. |
| P00-AC09 | P00-R09 | S04, S05, S06, S12 | Existing helper guards and prior real mismatch/recovery evidence; no need to damage a packet deliberately. |
| P00-AC10 | P00-R10 | S01, S05 | git apply --check at the pinned clean base, English/path inspection, no application/publication. |
| P00-AC11 | P00-R11 | S01, S06, S12 | Actual assembly, separate check --ready, snapshot/artifact hashes and transferred local links after acceptance. |
| P00-AC12 | P00-R12 | S01-S12 | Validate IDs/coverage/links/JSON, applicability and requirement-source mapping. |

## Applicability and gates

No visual change, PNG generation, runtime Swift/TS parity, Unicode offsets, attempts/cancellation, merge/reset implementation, OpenAPI/event schema change or new product ADR is in scope. These surfaces are N/A here; their prospective gaps remain assigned to the proper future steps. Code language behavior, geometry, devices, 30-minute stability and full-day capacity are NOT RUN/NOT PROVEN, not passed by documentation.

No new architecture/dependency is proposed. Existing ADR allow-lists and contracts-first rules remain. Future reconciliation should amend existing AGENTS/process/intent/spec/plan/ROADMAP precisely and retain the issue crosswalk; it must not create a competing product roadmap. Formal adoption of the upgrade amendment and LINGO-03 acceptance still need H-U/H-0.

Accept this specification/AC/design boundary explicitly before preparing the normal phase-03 successor. The next product cursor remains P-00 and its plan is proposed documentation work. A later folder named build does not authorize application implementation or GitHub publication. Source and owner-response evidence travel in the packet. Exact GPT-6.1 Sol serving ID is not verified and no model is switched automatically.
