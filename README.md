# Lingo

A personal voice tutor for spoken English and German, with explanations in Russian on request — on a Mac, a phone, a tablet
and any browser, entirely on free tiers.

**Contributors and AI agents: start with [AGENTS.md](AGENTS.md).**

| Part | Where | Status |
|---|---|---|
| Lingo for Mac (Swift, on-device recognition) | `apps/mac` | MVP working (LINGO-01) |
| Lingo Engine (Cloudflare Worker + D1) | `services/engine` | LINGO-03 Stage 1–2 |
| Lingo Web (PWA) | `apps/web` | LINGO-03 Stage 2 |
| Shared contracts (schemas, fixtures) | `packages/contracts` | started |

## Quick start (Mac)
```bash
swift build --package-path apps/mac && swift test --package-path apps/mac  # build and test
apps/mac/scripts/build-app.sh    # build and sign dist/Lingo.app
open dist/Lingo.app              # run
```

## Documentation
| What | Where |
|---|---|
| Agent and contributor guide | [AGENTS.md](AGENTS.md) |
| Documentation index | [docs/README.md](docs/README.md) |
| Architecture (whole system) | [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md) |
| Lingo for Mac — architecture and code | [docs/architecture/MAC.md](docs/architecture/MAC.md) |
| Lingo Web + Engine (all devices) — architecture and code | [docs/architecture/WEB.md](docs/architecture/WEB.md) |
| Repository map | [docs/architecture/CODEBASE.md](docs/architecture/CODEBASE.md) |
| How to update and extend | [docs/process/EVOLVING.md](docs/process/EVOLVING.md) |
| Roadmap | [docs/ROADMAP.md](docs/ROADMAP.md) |
| Development process (SDLC), testing, release | [docs/process/](docs/process/) |
| Decisions (ADR) | [docs/decisions/](docs/decisions/) |
| Current change | [docs/changes/LINGO-03/](docs/changes/LINGO-03/) |
| Contracts | [packages/contracts/](packages/contracts/) |
| Design tokens | [DESIGN.md](DESIGN.md) |
| Glossary | [docs/GLOSSARY.md](docs/GLOSSARY.md) |
