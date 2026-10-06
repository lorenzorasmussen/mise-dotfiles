# AGENTS.md

## Project Overview

Mise dotfiles for this host: `config.toml` plus a mise backend plugin that
provides the `zsh` runtime. Tracked so tool versions and shell wiring survive a
reimage.

`config.toml` is merged with, and lower priority than, `/etc/mise/conf.d/omarchy.toml`.
The comment at the top of `config.toml` records the measurement behind that:
the two files declare 17 and 1 keys with zero overlap, so nothing is declared
twice. If you add a key that omarchy also sets, expect a duplicate-declaration
warning and re-measure before assuming the merge is safe.

## Commands

```sh
mise ls                # installed tools
mise ls --global       # what config pins
mise current           # active versions
mise prune --dry-run   # disk reclaim preview; read-only, safe to run
mise upgrade           # installs new versions; relies on auto_prune below
```

`mise prune --dry-run` is the one to reach for first. Installs were 6.6 GB as of
2026-10-03 and the header comment records 13 stale versions at 3.67 GB, 56% of
everything installed. Node 26.8.1 alone is 750 MB.

Never `sudo mise`. It installs to a different tree than the one on PATH, which
produces a working-but-wrong runtime. `~/.local/bin` precedes mise's shim
directory on PATH, so a `~/.local/bin` install silently wins.

## settings.upgrade.auto_prune = true

This is the setting that keeps the install directory from growing without bound.
With `auto_prune = false`, every `mise upgrade` installs alongside the old
version and removes nothing. With it on, pruning deletes only versions no config
pins, and each deletion is recoverable by reinstalling at a pinned version.

The measured inventory and the automated maintenance script are not in this repo.
`config.toml` references `phase5/DISK_REPORT.json` and
`phase5/disk_maintenance.py`; neither path is tracked here. If you need them,
ask rather than recreating them from the header comment's numbers.

## Backup convention

`.gitignore` excludes `*.bak`, so the `cp <file> <file>.bak-<date>` habit used
across this host leaves the working tree clean. Committing a backup defeats the
point — check that a staged diff contains none.

## The zsh plugin

`plugins/zsh-src/` is a mise backend plugin: `metadata.lua` declares the backend
and `hooks/` implements `exec_env`, `install`, `list_tools`, and `list_versions`.
Lua, following mise's plugin API. Enabled in `config.toml` as
`"zsh-src:zsh" = "latest"`, which resolves zsh through this backend rather than
mise's default resolution. `plugins/zsh-src/README.md` covers it; shell
completion wiring is recorded in `HANDOFF.md`.

## Git

Seven commits, local only, Conventional Commits with scopes (`feat(dotfiles):`,
`fix(settings):`, `chore:`). `HANDOFF.md` is the running note for the next
session — read it before starting work here.
