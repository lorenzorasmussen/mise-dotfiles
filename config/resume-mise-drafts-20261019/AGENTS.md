# Mise configuration

Read `/home/lorenzo/AGENTS.md` and `HANDOFF.md` before changing this repository.
Use the pinned runtimes in `config.toml`; do not run `sudo mise`.

The OpenCode wrapper selects the installed, exact pinned executable first and
falls back to `mise x` when that executable is absent. Integrity validation and
optional repair belong to `opencode-integrity`, a separate command; launching
the wrapper does not run the integrity check. Run `bash -n` on changed shell
scripts and run the checker without `--repair` for a nonrepair check.

Preview pruning with `mise prune --dry-run`. Keep historical measurements dated
and recheck current ownership before changing package or runtime pins. Pacman
owns OpenClaw; the host launcher selects the compatible Node runtime.

Keep `HANDOFF.md` current with verified changes, checks and rollback. Preserve
unrelated local edits, old runtime trees and recoverable backups.
