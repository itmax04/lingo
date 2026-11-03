# Lingo documentation — index

Status: current · Date: 2026-10-28. Start with [`AGENTS.md`](../AGENTS.md) (rules and commands), then pick your path below.

## By app

| I work on … | Read in this order |
|---|---|
| **Lingo for Mac** (Swift) | [ARCHITECTURE](architecture/ARCHITECTURE.md) §1–4, §6 → [MAC](architecture/MAC.md) → [EVOLVING](process/EVOLVING.md) §1, §3, §4 → [ADR-0001](decisions/ADR-0001-stack.md) → current change in [changes/](changes/) |
| **Lingo Web + Engine** (iPhone, iPad, Android, Windows, any browser) | [ARCHITECTURE](architecture/ARCHITECTURE.md) → [WEB](architecture/WEB.md) → [EVOLVING](process/EVOLVING.md) §1, §3, §5 → [ADR-0002…0005](decisions/) → [contracts](../packages/contracts/README.md) → [LINGO-03 spec](changes/LINGO-03/spec.md) |
| **Shared behaviour** (events, prompts, commands, protocol) | [contracts](../packages/contracts/README.md) → [EVOLVING](process/EVOLVING.md) §3 → MAC §7 and WEB §10 |
| **Design** | [DESIGN.md](../DESIGN.md) → `design/redesign-2026/` (reference images per platform) → EVOLVING §3.5 |

## By document

| Document | Answers |
|---|---|
| [architecture/ARCHITECTURE.md](architecture/ARCHITECTURE.md) | What the system is made of, how the parts talk, why (both apps) |
| [architecture/MAC.md](architecture/MAC.md) | Mac app: modules, files, voice turn, data on disk, commands, where to change what |
| [architecture/WEB.md](architecture/WEB.md) | Web + engine: containers, planned code layout, API, data, web voice turn, deploy, where to change what |
| [architecture/CODEBASE.md](architecture/CODEBASE.md) | Repository map, shared contracts, scripts, change index |
| [process/EVOLVING.md](process/EVOLVING.md) | How to make each kind of change without breaking the architecture; ADR template; keeping docs true |
| [process/SDLC.md](process/SDLC.md) | Lifecycle, roles, autonomy, Definition of Done, git workflow, reporting |
| [process/TESTING.md](process/TESTING.md) · [process/RELEASE.md](process/RELEASE.md) | Test levels and device checks · deploy and release |
| [process/CODEX.md](process/CODEX.md) | How Codex runs a step: loop, checks, independent review, merge rules, start prompts |
| [plans/COMPLETION-PLAN-2026-11.md](plans/COMPLETION-PLAN-2026-11.md) | Everything left to finish Lingo, in order, with owner checkpoints |
| [process/STAGE-PROMPTS.md](process/STAGE-PROMPTS.md) | Start prompt for every stage, incl. the final audit |
| [decisions/](decisions/) | ADRs — why a hard-to-reverse choice was made |
| [changes/LINGO-NN/](changes/) | Per change: intent, spec (requirements), plan, handoff (current state), report |
| [ROADMAP.md](ROADMAP.md) · [GLOSSARY.md](GLOSSARY.md) | Order of changes · terms |
| [reference/](reference/) | Owner brief and background material (not requirements) |
