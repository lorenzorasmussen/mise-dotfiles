# mise setup — handoff for the next agent

Last worked: **2026-10-05**. Everything below was measured on this host, not
inferred. Re-verify before trusting; the `mise` version skew described in
"Open question" is the thing most likely to have changed.

Durable reference: `~/.agents/skills/mise/references/host-omarchy.md`
(rewritten 2026-10-05 — an earlier version of it contained two wrong claims,
corrected there).

---

## Current state, verified

    mise doctor            # -> "No problems found"
    mise dotfiles status   # -> tracking 26 entries (75 files); 16 checkpoints
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
- Shell completion is installed and verified:
  `mise completion bash --install` → `~/.local/share/bash-completion/completions/mise`,
  registering `complete -F _usage_complete_mise mise`.

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

The clean fix is to remove the pacman package, which has `Required By: None` and
`Conflicts With: mise`:

    sudo pacman -Rns mise-bin

**Not done: it needs root and it is a deletion.** Ask first. With `mise-bin`
gone, Omarchy's `init` finds no `mise`, skips silently, and the WARN disappears.

Check first whether Omarchy re-adds it on update:

    grep -rn "mise-bin" /usr/share/omarchy/

## Deliberately not done, and why

- **Upgrading mise to 2026.10.3.** Blocked by mise's own 24 h minimum-release-age
  gate. Checked the schema at both tags first: `history.git_email` is in *both*, so
  upgrading was never the fix for the WARN and there was no reason to bypass the
  stability gate. Once `mise-bin` is gone, `mise self-update` will work normally.
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
