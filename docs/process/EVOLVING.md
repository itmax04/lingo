# Evolving Lingo — how to update and extend the apps within the architecture

Status: current · Version 1 · Date: 2026-10-28
Read with: [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) (whole system) · [MAC.md](../architecture/MAC.md) ·
[WEB.md](../architecture/WEB.md) · [CODEBASE.md](../architecture/CODEBASE.md) · [SDLC.md](SDLC.md) (process, Definition of Done) ·
[TESTING.md](TESTING.md) · [RELEASE.md](RELEASE.md) · [STAGE-PROMPTS.md](STAGE-PROMPTS.md).

SDLC says **when** and **who**; this file says **how** a change is made so the system keeps its shape.

---

## 1. Architecture invariants (never break them without an ADR)

| # | Invariant | Where it matters |
|---|---|---|
| I-1 | The Mac app works **standalone** — no engine, no web needed | Mac |
| I-2 | The web client holds **no prompts, keys, model calls or budgets** — the engine does | Web |
| I-3 | **One event journal**, schema v1 in `packages/contracts`; events are immutable; merge is a pure, commutative, idempotent function | both |
| I-4 | Behaviour that exists in Swift and TypeScript is defined **once** in `packages/contracts` and tested on both sides against the same fixtures | both |
| I-5 | **The model proposes, code decides:** saving, language switch, cancel, end of session, writing results are application code | both |
| I-6 | `LingoCore` has no AppKit/SwiftUI and builds for iOS | Mac |
| I-7 | Audio is never stored or logged; logs never contain utterance text or keys | both |
| I-8 | Secrets only in the Keychain (Mac) or Worker secrets (engine) | both |
| I-9 | Every model call is budgeted per pool; unknown usage is "uncertain", never zero | both |
| I-10 | **$0**: free tiers only; anything paid is out of scope | both |
| I-11 | Colours, type, spacing and radii come only from `DESIGN.md` | both |
| I-12 | No pronunciation assessment anywhere (code, prompts, evals, UI) | both |
| I-13 | Repository in English; Russian/German only as language data | both |

## 2. Pick the path for your change

| Kind of change | Path | Documents |
|---|---|---|
| Bug fix inside an accepted requirement | issue → branch → PR | `handoff.md` of the current change |
| Small improvement inside the current change's spec | issue → PR | `handoff.md` (executor decision `D-xx` if you chose between options) |
| New or changed requirement | stop, ask the owner; update `spec.md` (and `intent.md` if scope moves) before code | spec, plan |
| Structural change (new container, data store, dependency, platform, auth or routing policy) | write an ADR (§6), owner accepts, then code | ADR + ARCHITECTURE + MAC/WEB + CODEBASE |
| A new product goal | a new change `docs/changes/LINGO-NN/` per SDLC (brainstorm → intent/spec/plan → H-0) | full SDLC set + ROADMAP |

## 3. Recipes — shared parts (contracts first)

### 3.1 Add a field or an event type
1. Edit `packages/contracts/events/event.schema.json`. **Additive only** within v1: new optional fields, new event types.
   Old clients must ignore unknown types and fields (they already preserve them).
2. Regenerate the golden fixtures from the Swift reference code (never hand-edit them); explain in the PR.
3. Swift: `Journal/Event.swift`, `Payloads.swift`, `Merger.swift`; tests in `JournalTests`.
4. TypeScript: `packages/core-ts/src/events`; engine validation in `src/sync`; parity tests.
5. ARCHITECTURE §6.1 (type list). One PR for all of it.
- **Breaking change** (renamed or removed field, new merge rule): schema `v = 2` + ADR. Older clients treat v2 events as read-only;
  write a migration note in the ADR and keep reading v1 forever.

### 3.2 Change model instructions or the reply protocol
1. Change Swift `PromptBuilder` / `ContextPolicy` / `ReplyProtocol` **and** the engine's TypeScript port in the same PR.
2. Re-record the prompt snapshots (`packages/contracts/prompts`, today `Tests/LingoCoreTests/Snapshots`); both sides must be byte-identical.
3. Reply protocol: update the parser fixtures first, then both parsers.
4. Run the `dialog` eval **at night**, budgeted (≤ 15 requests per batch unless the plan says otherwise); thresholds in `evals/README.md`;
   `no_pronunciation` must stay 100 %.

### 3.3 Add or change a voice command
`CommandKind` + `CommandDetector` (Swift) and `core-ts/commands` (TS), same vocabularies; add positives and look-alike negatives to
`evals/commands`; `commands` eval ≥ 95 %, false positives ≤ 3 % on both sides.

### 3.4 Add a provider or a model, change routing or quota
1. Free tier only (I-10). If the routing policy, pool definition or owner-risk handling changes → update ADR-0005 first.
2. Mac: `LLM/ProviderID`, `ProviderEndpoints`, chain defaults; `ChainTests`, `QuotaTests`.
3. Engine: `src/turn` (routes per purpose), `src/ledger` (budgets); tests with mocked providers.
4. One daytime single request per new pool as evidence; capacity table for 4 × 30 min in the change's `handoff.md`.

### 3.5 Change the look
1. `DESIGN.md` first — every new value with a one-line reason; no value invented in code.
2. Mac: `Design/Theme.swift`, then views; web: regenerate `apps/web/src/design`, then components.
3. Compare with the reference in `design/redesign-2026/<platform>`; screenshots (Mac `--ui-snapshot`, web Playwright) light/dark × RU/EN in the PR.
4. New screens: if no reference exists, generate one (ImageGen, see `design/redesign-2026/prompts/IMAGEGEN-PROMPTS.md`) before building.

### 3.6 Add a dependency
Check the allow-list (ADR-0001 for Swift, ADR-0002 for TypeScript). Not listed → add an ADR entry (why, licence, size, alternatives),
owner accepts, then add it. Pin versions; binaries only with a checksum.

## 4. Recipes — Mac app

| Change | Steps |
|---|---|
| Voice loop or recognition | change `LingoCore/Audio`, `Speech`, `Dialogue`; regression test; `--selftest <wav>`; if latency may move, `scripts/metrics.py` before/after |
| New setting | `AppSettings` / `VoiceSettings` (with default) → settings view → String Catalog (ru) → spec default |
| New screen or section | view in `LingoMac/Views`, data via `AppModel`/`AppServices`, `Fixtures` for snapshots, `--ui-snapshot`, reference image |
| UI string | `String(localized:)` / `LocalizedStringKey`; Russian in the String Catalog; missing-translation check = 0 |
| Code for the future iPhone app | put it in `LingoCore`; `scripts/check-core-ios.sh` |
| Release a new build | `scripts/build-app.sh`, `codesign --verify --strict dist/Lingo.app`, version bump in `Resources/Info.plist`, note in the change's `handoff.md` |

Checks before the PR: `swift build && swift test`, `scripts/check-core-ios.sh` (if `LingoCore` changed), `scripts/check-english.sh`,
`scripts/secret-scan.sh`, screenshots for UI.

## 5. Recipes — web and engine

| Change | Steps |
|---|---|
| New endpoint | `openapi.yaml` → engine `src/<area>` (account-scoped queries, origin check, size limits) → web `src/api` → tests on both sides |
| Database | new migration `services/engine/migrations/NNNN_<what>.sql`; never edit an applied one; additive by default; destructive steps need an export first and an owner checkpoint; ARCHITECTURE §6.2 |
| New screen | `apps/web/src/features/<name>`, tokens from `src/design`, i18n ru/en, phone (four bottom tabs) and wide (sidebar) layouts, Playwright screenshots |
| Voice behaviour | `apps/web/src/voice` + `core-ts/voice`; unit tests with fake audio; real-device check on iPhone (TESTING.md) before calling it done |
| Teacher features (LINGO-05) | engine `src/teacher/*`, new event types via §3.1, budgets via §3.4, web `features/today`, `progress`, `vocabulary` |
| Deploy | prepare per RELEASE.md; remote migrations, secrets and `wrangler deploy` are run by the owner |

Checks before the PR: `npm ci && npm test`, Playwright for UI, bundle secret scan, `scripts/check-english.sh`, `scripts/secret-scan.sh`;
free-tier impact (requests, tokens, D1 rows) stated in the PR.

## 6. Architecture Decision Records

Write an ADR when a choice is hard to reverse or affects more than one part: a new container or platform, a data store or schema version,
an auth or security model, model routing or quota policy, a new dependency outside the allow-list, a repository layout change.

File `docs/decisions/ADR-NNNN-<slug>.md` (next free number; never renumber; superseded ADRs stay, marked "superseded by ADR-MMMM"):

```markdown
# ADR-NNNN: <title>

Status: proposed | accepted (owner, YYYY-MM-DD) | superseded by ADR-MMMM · Context: <links>

## Context
<facts, constraints, measured numbers, owner decisions>

## Decision
<numbered, testable statements>

## Consequences
<what gets easier, harder, riskier; what must be done; what is ruled out>

## Alternatives considered
<option — why not>
```

## 7. Keeping the documents true

| When this changes … | update in the same PR |
|---|---|
| a top-level folder, a module, a file's responsibility | CODEBASE.md, and MAC.md §2 or WEB.md §4 |
| a container, data store, protocol or trust boundary | ARCHITECTURE.md (+ ADR) |
| an event type, API endpoint, prompt or eval set | `packages/contracts` + ARCHITECTURE §6 / WEB.md §5 |
| a command, script or CI workflow | AGENTS.md §4 (commands), CODEBASE.md §4, MAC.md §5 / WEB.md §9 |
| a known pitfall discovered | AGENTS.md §8 and MAC.md §6 / WEB.md §7 |
| the status of a stage or change | `handoff.md`, ROADMAP.md, status rows in MAC.md / WEB.md |
| a design token | DESIGN.md (+ `scripts/check-design.py` passes) |
| a stage prompt | STAGE-PROMPTS.md |

Rules for documents:
- ARCHITECTURE/MAC/WEB explain structure and reasons; **requirements live only in `spec.md`**; decisions in ADRs.
- Mark what does not exist yet as *planned*; remove the mark in the PR that creates it.
- Every document has a status line with a version and a date; bump them when the content changes.
- Keep `AGENTS.md` short — it links, it does not repeat.
- English in the repository; reports to the owner in Russian (SDLC §10).
