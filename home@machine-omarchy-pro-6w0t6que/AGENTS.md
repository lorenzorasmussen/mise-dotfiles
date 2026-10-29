# Global Agent Workflow

This file guides agents working from `/home/lorenzo` and agents whose global
instructions point here. The user's current request always takes precedence,
then the nearest repository `AGENTS.md`.

## Host facts (would be missed without help)
- `/home/lorenzo` is a shared agent-dev workspace, not a single project. Important locations: `~/.config/opencode`, `~/.hermes/hermes-agent`, `Projects/paperclip`, `gmail-imap`, `workflows`, `gbrain`.
- Use `mise` for toolchains (never `sudo mise`). Check manifest/lockfile before runtime work. Package manager from lockfile.
- Read skills from `/home/lorenzo/.agents/skills/` first (symlinks: use `find -L`). Read selected `SKILL.md` before external docs.
- Omarchy desktop/system work: invoke the `omarchy` skill first; customize under `~/.config/`, keep `/usr/share/omarchy/` read-only.
- Lorenzo's built-in Apple keyboard uses the Danish (`dk`) layout. The key left of `1` is `½` (Shift: `§`); describe shortcuts using these legends.
- This laptop's F9 Voxtype dictation, remote free text cleanup, and compact bottom Voxscope HUD are documented in `~/.config/voxtype/README.md`; read it before changing voice input or the plugin.
- Prefer verified free remote models; verify with `ai-usage --check-free`. Never silently use paid.
- Context7 for library/SDK/API questions: `npx ctx7@latest library` then `npx ctx7@latest docs`.
- Use feature branches/worktrees; never work on `main`/`master`. Back up config before edits.
- Ask before sending, publishing, purchasing, deleting, credential changes, or acting on teammate work.
- Never put secrets in source, logs, notes, commits, or memory.
- Report checks as passed/failed/timed out/unrun; a build alone is not proof.

## Memory & resources (host is RAM-constrained: 7.6GB)
- zram is capped at RAM size (7.6GB) — cannot increase to 16GB without OOM. Swapfile resized to ~15.4GB.
- Multiple opencode instances (serve + interactive) each spawn local MCP servers independently → duplicate processes. Kill duplicates with `pkill -f "rea-agents.*mcp"` and consolidate instances.
- Top memory consumers: Chromium/Electron apps, opencode, node MCP servers. Close heavy apps under pressure.
- Don't rebuild what the harness already does (omp `-c/--continue`, `--resume`, Supermemory, persisted compaction).

## Herdr workers (slow host)
- Pass `--timeout 180000` to `herdr agent start`. Bare launch then prompt for Pi/OpenCode.
- Verify isolation directly: `bwrap --die-with-parent` binding job dir + worktree, `OPENCODE_CONFIG_DIR` in env. Closing a tab doesn't retire a worker — close the workspace.
- PTY allocation can fail host-wide (`/dev/pts` empty). Check before launching.
- Workers must not end turns with multiple-choice blocks. Close with status/changed/blocked/unblock.

## Evidence tiers
Every factual claim: **observed** (executed this run), **published** (external source), or **inference** (derived). Never present one tier as another. Before accepting worker completion, read its final report AND final message.

## End of reply format
Finish every final chat reply with:
```
## Next steps
A. <action>
B. <action>
C. <action>
D. All of A–C.
```
(Not for progress updates, worker reports, code/config artifacts, or unattended workers.)

## References
- Task workflow: `/home/lorenzo/.agents/task-workflow.md`
- Skills: `/home/lorenzo/.agents/skills/`
- Omarchy skill: invoke before desktop/system customization
