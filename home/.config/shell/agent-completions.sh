# Shell completions for the CLI toolchain — shared loader for bash and zsh.
#
# Sourced from ~/.bashrc and ~/.zshrc (interactive shells only). Keep the
# sourcing line in each rc file as the ONLY thing that mentions this file, so
# bash and zsh can never drift apart.
#
# What it covers, and why each tool is handled the way it is:
#
#   tool      bash                      zsh
#   --------  ------------------------  --------------------------
#   herdr     generated, lazy           generated, fpath
#   omp       generated, lazy           generated, fpath
#   codex     generated, lazy           generated, fpath
#   copilot   generated, lazy           generated, fpath
#   gh        generated, lazy           generated, fpath
#   grok      generated, lazy           generated, fpath
#   mise      generated, lazy           generated, fpath
#   opencode  generated, lazy           NOT generated (see below)
#   tmux      free via bash-completion  free, from zsh itself (see below)
#   bat fd eza curl zoxide rg tldr …   free via bash-completion  fpath entry
#   openclaw  own loader, untouched     own loader, untouched
#
# opencode's `opencode completion zsh` is byte-identical to its bash output
# (verified 2026-10-06, 930 bytes each): the subcommand ignores the shell
# argument and always emits a yargs/bash script. Sourcing a `complete -F`
# bash script into zsh silently does nothing, so zsh gets no opencode
# completion from the CLI rather than a broken one. Re-check with
# `diff <(opencode completion bash) <(opencode completion zsh)`; if that
# becomes empty-vs-nonempty, add opencode to the zsh side of the generator.
#
# tmux needs no wiring on either shell, for different reasons. bash gets it
# from bash-completion (/usr/share/bash-completion/completions-core/tmux.bash);
# pacman's tmux package itself ships no completion. zsh gets it from zsh's own
# standard function set — `_tmux` is one of the 1235 files in
# <zsh-prefix>/share/zsh/5.9.2/functions/. Verified by TAB: `tmux <TAB>`
# offers 270 possibilities.
#
# Generated scripts live in ~/.cache/shell-completions, NOT here: they are
# build output that goes stale on every CLI upgrade, and this directory is
# tracked by mise's dotfiles history. See ~/.config/mise/config.toml for why
# ~/.cache and ~/.local/share are excluded from history. Wiping that cache dir
# is always safe — the next shell start regenerates everything.
#
# The tool table lives in shell-completions-refresh, which also writes a
# manifest of what it produced; this loader reads the manifest rather than
# keeping a second copy of the list.
#
# Regenerate everything by hand:  shell-completions-refresh --force
# Debug log:                    ~/.local/state/shell-completions.log

_SHCOMP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/shell-completions"
_SHCOMP_REFRESH="$HOME/.local/bin/shell-completions-refresh"
_SHCOMP_MANIFEST="$_SHCOMP_DIR/.tools"

# --------------------------------------------------------------------------
# bash
# --------------------------------------------------------------------------
if [ -n "${BASH_VERSION:-}" ]; then
    # bash-completion loads from its own directories on demand at TAB, so tmux
    # (/usr/share/bash-completion/completions-core/tmux.bash) and everything
    # else it ships need nothing here.
    #
    # Eagerly sourcing the generated scripts instead costs 75ms of shell
    # startup for the 708KB they add up to (measured 2026-10-06), so each one
    # is registered as a one-shot stub instead. The stub does not hardcode the
    # completion function's name — it sources the script, reads back whatever
    # the script itself registered with `complete -p`, and calls that. That
    # survives CLI upgrades renaming their handler, which a hardcoded
    # `complete -F _herdr ...` would not.
    #
    # The tool list comes from the manifest shell-completions-refresh writes,
    # so this file never has to be edited when a tool is added.
    if [ -r "$_SHCOMP_MANIFEST" ]; then
        while read -r _shcomp_tool; do
            [ -n "$_shcomp_tool" ] || continue
            _shcomp_file="$_SHCOMP_DIR/$_shcomp_tool.bash"
            [ -r "$_shcomp_file" ] || continue

            eval "_shcomp_lazy_$_shcomp_tool() {
            unset -f _shcomp_lazy_$_shcomp_tool
            source \"$_shcomp_file\" >/dev/null 2>&1
            local _shcomp_spec _shcomp_fn
            _shcomp_spec=\$(complete -p $_shcomp_tool 2>/dev/null) || return 0
            _shcomp_fn=\$(printf '%s\n' \"\$_shcomp_spec\" | sed -n 's/.*-F \\([^ ]*\\).*/\\1/p')
            [ -n \"\$_shcomp_fn\" ] && \"\$_shcomp_fn\" \"\$@\"
            return 0
        }"
            complete -F "_shcomp_lazy_$_shcomp_tool" "$_shcomp_tool"
        done < "$_SHCOMP_MANIFEST"
        unset _shcomp_tool _shcomp_file
    fi

# --------------------------------------------------------------------------
# zsh
# --------------------------------------------------------------------------
elif [ -n "${ZSH_VERSION:-}" ]; then
    # ORDER MATTERS: fpath first, compinit second.
    #
    # `compinit` walks fpath once, at the moment it runs, and records what it
    # finds in the dump. An fpath entry added afterwards is invisible until the
    # next compinit. So this block must run before any loader that calls
    # compinit -- which is why ~/.zshrc sources THIS file before
    # openclaw-completions.sh (that loader also runs compinit if it is missing).

    # 1. pacman ships 108 zsh completions under site-functions (bat, fd, eza,
    #    curl, zoxide, rg, tldr, starship, ...). mise's zsh is built with
    #    --prefix=<install>, so its compiled-in fpath is only that prefix --
    #    /usr/share/zsh/site-functions is NOT in it. Without this line every
    #    one of those 108 is invisible to this zsh.
    typeset -U fpath
    [[ -d /usr/share/zsh/site-functions ]] && fpath=(/usr/share/zsh/site-functions $fpath)
    # 2. Our own generated scripts. Named _<tool>, which is the autoloadable
    #    function convention compinit picks up.
    [[ -d "$_SHCOMP_DIR" ]] && fpath=("$_SHCOMP_DIR" $fpath)

    # 3. Now compinit can see them.
    if (( ! $+functions[compdef] )); then
        autoload -Uz compinit
        _shcomp_zcache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
        mkdir -p "$_shcomp_zcache" 2>/dev/null
        # Secure check first; -u fallback so a first run can never hang on the
        # "insecure directories" prompt.
        compinit -d "$_shcomp_zcache/zcompdump" >/dev/null 2>&1 ||
            compinit -u -d "$_shcomp_zcache/zcompdump" >/dev/null 2>&1
        unset _shcomp_zcache
    fi
fi

# --------------------------------------------------------------------------
# Refresh: keep generated scripts in sync with the installed CLIs.
#
# Foreground cost on every interactive shell start is zero forks: read a
# timestamp out of the gate file and compare it against $EPOCHSECONDS (a
# builtin in both bash and zsh).
#
# The regeneration itself MUST be detached. Measured 2026-10-06: a full
# `shell-completions-refresh` takes ~8s even when nothing needs regenerating,
# because it runs `<tool> --version` once per tool. Running that in the
# foreground would stall the first shell after every 24h window by 8 seconds.
#
# The generator lives in ~/.local/bin/shell-completions-refresh and is called
# by absolute path, because ~/.local/bin is only guaranteed to be on PATH
# later in .bashrc than this file is sourced.
# --------------------------------------------------------------------------
_shcomp_refresh() {
    local gate="$_SHCOMP_DIR/.refresh-check" now last=0 won noclobber=0

    [ -r "$gate" ] && read -r last < "$gate" 2>/dev/null
    now=${EPOCHSECONDS:-0}
    # Skip if a check ran less than 24h ago. `last` of 0 means never checked.
    if [ "${last:-0}" -gt 0 ] 2>/dev/null && [ $((now - last)) -lt 86400 ]; then
        return 0
    fi

    # Atomic claim without a subshell: under `set -C` the truncating redirect
    # fails if the file exists, so N shells starting at once produce exactly
    # one refresh instead of N. Restore noclobber either way.
    case $- in *C*) noclobber=1 ;; esac
    set -C
    printf '%s\n' "$now" > "$gate" 2>/dev/null
    won=$?
    set +C
    [ "$noclobber" = 1 ] && set -C
    [ "$won" = 0 ] || return 0

    [ -x "$_SHCOMP_REFRESH" ] || return 0

    # setsid -f fully detaches: no job in either shell, no wait, no stdio
    # inherited. Without setsid, fall back to a plain background subshell --
    # still off the critical path, just less tidy.
    if command -v setsid >/dev/null 2>&1; then
        setsid -f "$_SHCOMP_REFRESH" --quiet >/dev/null 2>&1 </dev/null
    else
        "$_SHCOMP_REFRESH" --quiet >/dev/null 2>&1 </dev/null &
    fi
}

[ -d "$_SHCOMP_DIR" ] || mkdir -p "$_SHCOMP_DIR" 2>/dev/null
_shcomp_refresh
unset -f _shcomp_refresh