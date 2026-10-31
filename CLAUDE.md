# Lingo — Claude Code instructions

@AGENTS.md
@DESIGN.md

Claude-specific notes
- `AGENTS.md` is the single guide (shared with Codex and humans); keep it current instead of adding rules here.
- Talk to the owner in Russian; write everything in the repository in English.
- Use one git worktree per issue when several sessions work in parallel; never edit another session's working directory.
- Before the first web/engine task, load the project docs listed in AGENTS.md §1; for UI work follow DESIGN.md and the owner's frontend rules (design system first).
- Project permissions for common safe commands are in `.claude/settings.json`; anything outside them is asked for.
