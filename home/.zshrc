
. "$HOME/.local/share/../bin/env"
export OMNP_COOKIE_PATH="$HOME/.local/share/agent-cookie/"
export OMARCHY_COOKIE_PERSIST="true"

# mise - universal runtime manager
[[ -f ~/.profile.mise ]] && source ~/.profile.mise

# OpenClaw shell completions (lazy: loads the ~280KB script on first TAB,
# and self-refreshes when the CLI is updated). After mise, so openclaw is
# on PATH for the staleness check. The loader runs compinit if zsh has none.
[[ -f ~/.config/shell/openclaw-completions.sh ]] && source ~/.config/shell/openclaw-completions.sh
