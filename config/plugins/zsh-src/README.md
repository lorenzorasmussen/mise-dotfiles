# zsh-src — a mise backend plugin for zsh

mise has no zsh in any registry, so this builds it from the official source
tarball. Installed as `zsh-src:zsh` (5.9.2).

    mise plugin link zsh-src ~/.config/mise/plugins/zsh-src   # already done
    mise install zsh-src:zsh@latest                           # ~165s
    mise use -g zsh-src:zsh@latest                            # pinned

`ls-remote` really does reach upstream tags:

    mise ls-remote zsh-src:zsh
    # 5.6 … 5.9.2

The plugin is linked from this directory, so editing a hook here takes effect
on the next `mise install` — no reinstall of the link needed.

## Why it has to exist

Measured 2026-10-06 on mise 2026.10.2. Every conventional route is closed:

| route | result |
|---|---|
| `mise use -g zsh` | `zsh not found in mise tool registry` |
| `github:zsh-users/zsh` | `No versions found` |
| `aqua:zsh-users/zsh` | `registry not available: no aqua-registry found` |
| `vfox:mise-plugins/vfox-zsh` | repo 404s |
| `asdf:mise-plugins/asdf-zsh` | repo 404s |
| `omarchy pkg add zsh` | needs a sudo password (unavailable unattended) |

**zsh publishes Git tags but no GitHub release assets.** mise's generic
`github:` backend installs from release assets, so tags alone are invisible to
it — which is why `github:zsh-users/zsh` reports no versions at all.

Beware: `mise use --dry-run` prints `would install` for every one of these
dead routes. It does not validate. `mise ls-remote <tool>` does.

## Build sequence, and the two traps in it

`hooks/backend_install.lua`:

1. `http.download_file` the tag tarball, `archiver.decompress` with
   `strip_components = 1`.
2. `./Util/preconfig && autoconf` — the git tree ships **no** `configure`.
3. `./configure --prefix=<install_path>` so zsh's fpath resolves inside the
   mise install rather than `/usr`.
4. `make -j$(nproc)`.
5. `make install.bin install.modules install.fns`.

**Trap 1 — `install.install` does not exist.** It reads like it should and the
error (`No rule to make target 'install.install'`) only appears after ~150s of
compiling. zsh's `Makefile.in` defines `install.bin`, `install.modules`,
`install.fns`, `install.runhelp`, `install.man`, `install.info`, `install.html`.
Only the first three are used:

- `install.man` builds man pages with yodl/texinfo — not installed, not needed.
- `install.runhelp` runs in `Doc/` and shells out to `git describe`, which
  fails hard on a tarball: `fatal: not a git repository`. It aborts the whole
  install, so it is excluded on correctness grounds, not speed.

**Trap 2 — mise's Lua `file` module has no `mkdir` or `remove`.** Only
`join_path`, `read`, `symlink`, `exists`, `list`, `glob`, `move`, `stat`.
Directory creation must go through `cmd.exec`. See
https://mise.jdx.dev/plugin-lua-modules.html.

## What this does and does not give you

Gives you: `zsh` on PATH in any shell that activates mise, its 1235 standard
functions (`_tmux` included), and its own `share/zsh/site-functions`.

Does **not** give you: a login shell. `/etc/shells` has no entry for the mise
path, so `chsh` would refuse — and needs root to fix. `getent passwd lorenzo`
still says `/bin/bash`. Switching the default shell is the user's call.

It also does not put `/usr/share/zsh/site-functions` on fpath, which is where
108 completions from other pacman packages live. That is handled separately,
by `~/.config/shell/agent-completions.sh`.

## Cost

A full build is ~165s wall clock, essentially all of it `make`. Re-installing
after a hook edit costs the same — there is no incremental cache.

If zsh ever appears in mise's registry, or `omarchy pkg add zsh` becomes
runnable, delete this plugin and drop the `zsh-src:zsh` line from
`~/.config/mise/config.toml`. Do not leave both.