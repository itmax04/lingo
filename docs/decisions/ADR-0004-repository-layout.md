# ADR-0004: Monorepo layout and shared contracts

Status: **accepted** (owner, 2026-10-26) · The move is plan step P-01 of [LINGO-03](../changes/LINGO-03/plan.md)

## Context
The repository holds a Swift package at its root (Mac app, core, evals) and will gain a website, a server and shared TypeScript code.
Several AI agents (Claude Code, Codex) and humans work on it; they need an obvious place for everything and one source of truth
for behaviour that exists in two languages.

## Decision
```
apps/mac/              the Swift package (Package.swift, Sources, Tests, Resources, mac scripts) — moved from the root
apps/web/              React + Vite PWA
services/engine/       Cloudflare Worker + D1 migrations (wrangler.jsonc)
packages/core-ts/      TypeScript ports used by web and engine
packages/contracts/    language-neutral contracts: event schema, OpenAPI, prompt snapshots, eval sets, golden fixtures
docs/                  architecture, decisions, changes (SDLC), process, reference
scripts/               repo-wide scripts: secret-scan, check-english, CI helpers
.github/               workflows, PR template
```
- **npm workspaces** at the root (`package.json` with `workspaces: ["apps/web", "services/engine", "packages/*"]`); the Swift package is built from `apps/mac` with `swift build --package-path apps/mac`.
- **Contracts first:** a behaviour shared by Swift and TypeScript (prompt text, reply protocol, commands, VAD/segmenter timelines, merge) is changed by updating the fixture in `packages/contracts` and both implementations in the same PR.
- Prompt snapshots move from `Tests/LingoCoreTests/Snapshots/` to `packages/contracts/prompts/`; eval sets from `evals/` to `packages/contracts/evals/`. Swift tests read them via a path relative to the package (`#filePath` → repo root).
- Generated or private material never enters the repo: `dist/`, `.build/`, `node_modules/`, `.wrangler/`, `evals/out/`, `private/`, models.

## Consequences
- One clone gives everything; CI can run per-area jobs with path filters.
- P-01 touches many paths at once — it is done in one PR with no behaviour change, verified by the full test suite and `scripts/build-app.sh`.
- The iCloud-specific `.build` symlink workaround is no longer needed after the move to `~/Developer/lingo` (kept harmless, removed in P-01).
