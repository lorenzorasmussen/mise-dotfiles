
. "$HOME/.local/share/../bin/env"
export OMNP_COOKIE_PATH="$HOME/.local/share/agent-cookie/"
export OMARCHY_COOKIE_PERSIST="true"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# mise - universal runtime manager
# NOTE: ~/.profile.mise emits shell-specific activation code and picks zsh
# over bash when $ZSH_VERSION is set. Do not "simplify" it back to
# `mise activate bash`.
[[ -f ~/.profile.mise ]] && source ~/.profile.mise

# Agent + dev-tool shell completions (herdr, omp, codex, copilot, gh, grok,
# mise) plus pacman's 108 site-functions completions.
# MUST be sourced before openclaw-completions.sh: this one puts its fpath
# entries in place *before* running compinit, and compinit only ever sees the
# fpath as it exists at the moment it runs. The openclaw loader also calls
# compinit if it is missing, and if it went first our entries would be lost.
[[ -f ~/.config/shell/agent-completions.sh ]] && source ~/.config/shell/agent-completions.sh

# OpenClaw shell completions (lazy: loads the ~280KB script on first TAB,
# and self-refreshes when the CLI is updated).
[[ -f ~/.config/shell/openclaw-completions.sh ]] && source ~/.config/shell/openclaw-completions.sh


# Added by Antigravity CLI installer
export PATH="/home/lorenzo/.local/bin:$PATH"
