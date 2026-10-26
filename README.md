# Lingo

A personal app for voice conversation practice in English and German, with explanations in Russian on request.
macOS first (LINGO-01), then an iPhone adaptation (LINGO-02). Free services only.

**Start here:** [AGENTS.md](AGENTS.md) — status, architecture, commands, rules and next steps, for humans and AI agents alike.

## Quick start
```bash
swift build && swift test        # build and run the tests
scripts/build-app.sh             # build and sign dist/Lingo.app
open dist/Lingo.app              # run
```

## Documents
| What | Where |
|---|---|
| Agent and contributor guide | [AGENTS.md](AGENTS.md) |
| The owner's original brief | [docs/reference/owner-brief.md](docs/reference/owner-brief.md) |
| Goal, scope, owner decisions | [docs/changes/LINGO-01/intent.md](docs/changes/LINGO-01/intent.md) |
| Requirements and acceptance criteria | [docs/changes/LINGO-01/spec.md](docs/changes/LINGO-01/spec.md) |
| Steps and owner checkpoints | [docs/changes/LINGO-01/plan.md](docs/changes/LINGO-01/plan.md) |
| Progress log and next step | [docs/changes/LINGO-01/handoff.md](docs/changes/LINGO-01/handoff.md) |
| Stack | [docs/decisions/ADR-0001-stack.md](docs/decisions/ADR-0001-stack.md) |
| Evals | [evals/README.md](evals/README.md) |
| Design | [DESIGN.md](DESIGN.md), [docs/design/lingo-mac.webp](docs/design/lingo-mac.webp) |

Some documents are still being translated from Russian; see AGENTS.md §8.
