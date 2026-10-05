# mise setup — handoff for the next agent

Last worked: **2026-10-06**. Everything below was measured on this host, not
inferred. Re-verify before trusting; the `mise` version skew described in
"Open question" is the thing most likely to have changed.

Durable reference: `~/.agents/skills/mise/references/host-omarchy.md`
(rewritten 2026-10-05 — an earlier version of it contained two wrong claims,
corrected there; extended 2026-10-06 with the zsh plugin and the completion
loader).

---

## 2026-10-06 — zsh, and shell completions for both shells

### zsh is now installed, via a local backend plugin

`zsh-src:zsh` 5.9.2, pinned in `config.toml`, built from source by
`~/.config/mise/plugins/zsh-src/` (read its README before touching it).

mise has no zsh in any registry, and every conventional route is closed —
zsh ships **Git tags but no release assets**, which is what kills mise's
generic `github:` backend; the aqua/vfox/asdf plugins all 404; and
`omarchy pkg add zsh` needs a sudo password this environment does not have
unattended. Full route table in the plugin README.

**`mise use --dry-run` prints "would install" for all of those dead routes.**
Use `mise ls-remote` to actually check a route.

### What else changed

- `~/.config/shell/agent-completions.sh` — one loader sourced by both
  `~/.bashrc` and `~/.zshrc`. bash gets lazy one-shot stubs (eager sourcing
  cost 75ms for 708KB); zsh gets `fpath` entries. ~2ms per shell start.
- `~/.local/bin/shell-completions-refresh` — version-fingerprinted generator
  writing to `~/.cache/shell-completions`. A full pass takes ~8s, so it runs
  **detached** from the rc path, at most once per 24h.
- **`~/.profile.mise` now picks the activation shell.** It was hardcoded to
  `mise activate bash`, so zsh got mise's tool PATH but no hook and no
  completion. Verified `mise hook: 1` under zsh now. Do not revert it.
- **`~/.zshrc` sources `agent-completions.sh` BEFORE
  `openclaw-completions.sh`.** `compinit` walks `fpath` only at the moment it
  runs, and the openclaw loader also calls `compinit`. Reverse these two lines
  and every generated zsh completion silently disappears.
- zsh's compiled-in fpath is only its own `--prefix`, so all **108** pacman
  completions in `/usr/share/zsh/site-functions` were invisible. The loader
  prepends it.
- Dotfiles: 26 → **28 entries** (75 → 83 files), 37 checkpoints.
  `mise doctor` → "No problems found".

### Verified, not assumed

Real PTY, literal TAB keystrokes, both shells: `herdr comp`, `omp comp`,
`codex exe`, `gh pr`, `opencode ac`, `mise ins`, `tmux `, `bat --sty`.
Everything above completes except `opencode` in zsh — see below.

### Two upstream completion bugs found

- **`opencode completion zsh` is byte-identical to its bash output** (930
  bytes; it ignores the shell argument). A `complete -F` bash script in zsh is
  a silent no-op, so opencode is bash-only here by decision, not omission.
- **`gh completion zsh` silently emits the *bash* script** — gh needs `-s`, so
  the generator argv is `completion -s`. This is the dangerous kind of wrong:
  the file looks fine and never completes.

Also: `mise __complete` errors on every call here, but mise's own completion
does not use it — it calls `__complete_word__ --shell zsh`, which works. Don't
"fix" mise's completion based on the `__complete` error.

### Open questions — these need the user, not you

- **zsh is not the login shell.** `/etc/shells` has no entry for the mise zsh
  path, so `chsh` needs both a root edit and a password. It is installed and
  configured, just not the default. Their call.
- **`yq`, `atuin`, `direnv`, `delta`** are in mise's registry and would
  install on request. Deliberately left unpinned — nothing here used them yet.

---

## Current state, verified

    mise doctor            # -> "No problems found"
    mise dotfiles status   # -> tracking 28 entries (83 files); 37 checkpoints
    systemctl --user is-enabled dev.mise.mise-history.service   # -> enabled
    systemctl --user is-active  dev.mise.mise-history.service   # -> active

- `~/.config/mise/config.toml` is a local-only git repo, no remote. One repo per
  program is this host's standing rule; do not move it into another repo's tree.
- mise's own dotfiles backend does the versioning. Every entry is
  `mode = "track"` — tracking records checkpoints and leaves the live file owned
  by whatever already owns it. See "Why track and not symlink" below before
  changing any mode.
- Automatic capture works via `dev.mise.mise-history.service`
  (`[bootstrap.services.mise-history] builtin = "history-watch"`). It checkpoints
  2 s after a tracked file goes quiet, reconciles every 10 m, and force-saves a
  permanently-changing file after 24 h.
- Checkpoints live in a **bare** repo:
  `git --git-dir ~/.local/state/mise/history/repo.git log`
  (`git -C ~/.config/mise log` will NOT show them).
- Shell completion is installed and verified two ways: the historical
  `mise completion bash --install` →
  `~/.local/share/bash-completion/completions/mise`, and now the shared loader
  `~/.config/shell/agent-completions.sh`, which generates and registers it for
  bash *and* zsh. Both end up registering `complete -F _usage_complete_mise
  mise`; the loader's wins by load order.

## What changed on 2026-10-05 (this session)

**1. Dotfiles coverage extended, 16 → 26 entries (38 → 75 files).**

Added, because they are live hand-edited config with no other version history
and no nested git repos: `alacritty`, `foot`, `kitty`, `ghostty`,
`xdg-terminals.list`, `environment.d`, `fish`, `autostart`, `nvim`, `tmux`.
The four terminals matter most — Omarchy ships them side by side, a typo in one
means no window opens and nothing on screen tells you why.

No manual `mise dotfiles add` was needed: adding the entries to `config.toml` was
enough, and the watcher captured the new files by itself within seconds
(checkpoint 12). That is the automatic-watch path working as designed.

**2. `~/.profile.mise` now pins which mise binary activates. This was a real bug.**

Interactive shells were running **mise 2026.9.14** (pacman's `/usr/bin/mise`)
while login shells ran **2026.10.2** (`~/.local/bin/mise`). Cause:

- Omarchy's `/usr/share/omarchy/default/bash/init` runs
  `eval "$(mise activate bash)"` for every interactive shell, at `.bashrc` line 15.
- `~/.local/bin` is not on PATH yet — `.bashrc` prepends it on line 36.
- mise installs no `mise` shim, so `command -v mise` found `/usr/bin/mise`.
- `mise activate` hardcodes its own absolute path into the `mise()` shell
  function it emits, so that function shadowed the correct binary for the whole
  session. A later `command -v mise` in `.profile.mise` resolved back to the
  function, so it could never recover.

Symptoms: `mise self-update` was **disabled** in a terminal, and every mise
command printed `WARN unknown field ... history.?.git_email`.

`~/.profile.mise` now names `~/.local/bin/mise` explicitly and falls back to
`type -P mise` (not `command -v`, which would return the function *name*). Since
`.bashrc` sources it on line 25 — after Omarchy's `init` — re-activating there
wins. Verified: interactive and login shells both report 2026.10.2.

**Do not revert this to `command -v mise`.**

## Open question — needs the user, not you

**One cosmetic WARN remains**, once per interactive shell, from Omarchy's `init`
running the old binary before `.profile.mise` gets a turn:

    mise WARN  unknown field in ~/.config/mise/config.toml: history.?.git_email

`history.git_email` is **valid** — it is in the published schema for both
v2026.10.2 and v2026.10.3, and it works (commits are authored
`mise <mise@omarchy-pro>`). 2026.9.14 simply predates the key. Do not "fix" it
by deleting the key.

### Do NOT remove mise-bin

An earlier draft of this file recommended `sudo pacman -Rns mise-bin`. **That is
wrong.** Measured 2026-10-05:

- `mise-bin` is an **Omarchy base package** (`install/omarchy-base.packages:80`),
  so `omarchy update` reinstalls it. Removal does not stick.
- `/usr/share/omarchy/migrations/1786952219.sh` deliberately migrated *to*
  `mise-bin` and *off* Arch's `mise`. Its comment: mise-bin carries mise's own
  release artifacts — PGO+BOLT-optimized on x86, glibc-native on both arches —
  and dropping it breaks `omarchy-zsh` and `omarchy-fish`, which need *a* mise.
  Neither is installed today (`zsh`/`fish` absent), but the breakage returns the
  moment they are.
- The newest `mise-bin` in the Omarchy repo is `2026.9.14-1` — the same version
  already installed. Standardising on it means sitting on 2026.9.14 until
  Omarchy rebuilds, warning the whole time.

So: **leave `mise-bin` installed.** Redundant but harmless and package-managed.
One warning line per shell is cheaper than the alternatives, and it is honest
rather than suppressed.

### The real decision, for the user

The two installs are now *pinned* rather than racing. Which one is canonical is
the user's call:

| | `~/.local/bin/mise` (**current pin**) | `/usr/bin/mise` (mise-bin) |
|---|---|---|
| version | 2026.10.2 | 2026.9.14 |
| updates via | `mise self-update` (works) | `omarchy update` |
| build | stock release | PGO+BOLT-optimized, glibc-native |
| `git_email` key | recognised | warns |
| shims + watcher service | point here | unused |

Flipping to mise-bin means reverting `.profile.mise`, re-running `mise reshim`
under it, and editing the watcher's `ExecStart`. Do not do that unilaterally.

## Deliberately not done, and why

- **Upgrading mise to 2026.10.3.** Blocked by mise's own 24 h minimum-release-age
  gate. Checked the schema at both tags first: `history.git_email` is in *both*, so
  upgrading was never the fix for the WARN and there was no reason to bypass the
  stability gate. It works normally now that the pin points at the self-installed
  copy.
- **Bumping `node` from the pinned `26.8.1` to `latest` (26.10.0).** Every other
  tool floats; node alone is pinned, which looks like drift. Left alone: a node
  bump can break native modules, and `~/Projects/paperclip` needs `>=24.11.0`,
  already satisfied. Ask the user.
- **Writing to `/etc/profile.d/`.** An earlier version of the host reference
  prescribed this. It cannot work: `/etc/profile.d` is read by `/etc/profile`,
  which only *login* shells load, and login shells already activate mise. See the
  reference file for the full consumer-by-consumer measurement.
- **`mise dot origin set <url>`.** No setup repository and no remote; this host
  versions config locally, one repo per program.

## Things that look like bugs but are not

- `sudo mise doctor` reporting all 20 tools missing. `secure_path` drops
  `~/.local/bin` and sudo sets `HOME=/root`, so root mise reads an empty config.
- mise knowing tool names that are pacman-owned (`deno`, `perl`, `lua`, `jq`).
  Knowing a name is not a collision; only a *pinned* version shadows a binary.
- node/python/ruby existing twice on disk. Load-bearing: Omarchy and base-devel
  depend on the pacman copies. They coexist by PATH order; mise wins in any shell
  that activates.
- `complete -p mise` printing nothing. bash-completion loads on demand at TAB.
  To verify: `bash -ic 'source ~/.local/share/bash-completion/completions/mise;
  complete -p mise'`.
- `bash: ~/.openclaw/completions/.refresh-check: cannot overwrite existing file`
  in every interactive shell. openclaw's self-refresh, unrelated to mise.

## Useful commands

    mise doctor
    mise dotfiles status                 # entries + checkpoint count
    mise dotfiles paths                  # what history tracks, per policy
    mise dotfiles history                # checkpoint list
    mise dotfiles rollback --to <id> --dry-run <path>   # always dry-run first
    mise dotfiles rollback --to <id> --yes <path>
    mise dotfiles undo                   # reverses a rollback
    git --git-dir ~/.local/state/mise/history/repo.git log

Verify a shell really activates mise (do not trust `mise --version` alone):

    env -i HOME=$HOME TERM=xterm bash -ic 'mise --version; node --version; pnpm --version'
    env -i HOME=$HOME TERM=xterm bash -lc  'mise --version; node --version; pnpm --version'

Both must agree. `MISE_LOG_LEVEL=trace` on a mise command names the version and
source file at `src/cli/version.rs`, which is how the shadowing was found.

## Why track and not symlink

`mode = "track"` everywhere is deliberate. Omarchy backs up and replaces
`~/.config/omarchy/**` on `omarchy refresh` and writes `*.bak.<epoch>` beside
whatever it touches; a symlink into a dotfiles tree would make Omarchy write
through the link into the repo. `/etc/skel` and Omarchy own `~/.bashrc`,
`~/.bash_profile`, `~/.profile`. mise is the safety net here, not the owner:
`mise dot rollback` recovers a config a bad edit destroyed without mise ever
claiming the file.

Also excluded on purpose: `~/.npmrc` (a credential store — mise's built-in filter
does not cover that name, and `npm login` would land an `_authToken` in
plaintext git history; it would need `encrypt = true` plus
`[history.encryption] recipients` first), `~/.bash_history` (session state),
`~/.config/shell/` (self-regenerating), `~/.config/omarchy/themes` (64 MB) and
`plugins` (162 MB) (downloaded/cloned assets, tracked as individual entries
rather than whole directories), `~/.local/share/**` (`mise install` owns it).

Global `[history] exclude = ["*.bak*"]` keeps refresh backups out of git.

## If you are extending this

1. Add the entry to `[dotfiles]` in `~/.config/mise/config.toml` with
   `mode = "track"`. The watcher picks it up on its own — no `mise dotfiles add`
   needed for an entry that is already in the config.
2. Check for a nested git repo first; mise excludes `.git` from history, so a
   doubly-versioned path just produces noise.
3. `cp config.toml config.toml.bak-$(date +%Y%m%d-%H%M%S)` before editing.
4. Verify with `mise dotfiles status` and a real edit + `rollback --dry-run`.
5. Commit to the `~/.config/mise` repo with a message explaining *why*.
