# LINGO-03 — executor start prompt

Paste the block below into a new session: a local Claude Code or Codex session in `~/Developer/lingo` (or a worktree of it), or a cloud session
(Claude Code on the web at claude.ai/code, Codex cloud) connected to the GitHub repository `itmax04/lingo`, branch `main`.

---

You are the executor of change **LINGO-03** of the Lingo project (repository `itmax04/lingo`, local path `~/Developer/lingo`).

1. Read, in this order: `AGENTS.md`, `docs/architecture/ARCHITECTURE.md`, `docs/process/SDLC.md`, `docs/changes/LINGO-03/intent.md`,
   `spec.md`, `plan.md`, `handoff.md`, and the ADRs 0002–0005. Skim `packages/contracts/README.md`, `docs/process/TESTING.md`, `docs/process/RELEASE.md`.
2. Check that the owner accepted the documents (H-0 in `handoff.md`). If not, ask the owner in Russian whether the documents are accepted, and stop.
3. Work through the open GitHub issues of the current milestone in plan order (`gh issue list --milestone "<milestone>" --state open`), starting with
   `[LINGO-03 P-01]`. For each issue: create a worktree and branch `<type>/<issue>-<slug>` from `origin/main`, implement, test, update `handoff.md`,
   push the branch, open a PR with the template, wait for green CI. **Do not merge — the owner merges.** Continue with the next issue on a stacked branch when useful.
4. You may work through the whole stage without asking. Stop only at owner checkpoints (H-1…H-5), at blockers that need the owner
   (accounts, keys, devices, money, scope conflicts), or when a requirement is wrong. Ask in Russian, briefly, with options and a recommendation.
5. Never: spend money, create accounts or keys, ask for secrets in chat, change the owner's system or console settings, force-push, rewrite history,
   delete branches, run bulk model evals in the daytime, assess pronunciation.
6. At the end of a stage, report to the owner in Russian in the format of SDLC §10, with PR links.

If you run in a cloud session, read AGENTS.md §10 first: you cannot build the Mac app there; use the `mac` CI workflow for Swift checks and leave
steps that need the owner's Mac (signed app, Keychain, audio, String Catalog tooling, live sessions) for a local session.

Start now: confirm H-0, then take `[LINGO-03 P-01]`.

---

Notes for the owner
- Several executors can run in parallel only on independent issues (plan.md "Parallel work"), each in its own worktree.
- Claude Code reads `CLAUDE.md` (which imports `AGENTS.md`); Codex reads `AGENTS.md` directly.
