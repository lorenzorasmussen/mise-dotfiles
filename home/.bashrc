# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
# Ensure working directory is persistent (home directory)
cd "$HOME"

# Agent cookie persistence exports (MUST be before interactive guard)
export OMARCHY_COOKIE_PERSIST="true"
export OMNP_COOKIE_PATH="$HOME/.local/share/agent-cookie/"
export PI_CODING_AGENT_DIR="$HOME/.omp/agent"

# If not running interactively, don't do anything else (leave this above the rc source)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

. "$HOME/.local/share/../bin/env"
. "$HOME/.cargo/env"
# mise - universal runtime manager (interactive shells)
[[ -f ~/.profile.mise ]] && source ~/.profile.mise

# OpenClaw shell completions (lazy: loads the ~240KB script on first TAB,
# and self-refreshes when the CLI is updated). After mise, so openclaw is
# on PATH for the staleness check.
[[ -f ~/.config/shell/openclaw-completions.sh ]] && source ~/.config/shell/openclaw-completions.sh

# OpenClaw Completion
[ -f '/home/lorenzo/.openclaw/completions/openclaw.bash' ] && source '/home/lorenzo/.openclaw/completions/openclaw.bash'

# Composio CLI
export PATH="$HOME/.local/bin:$PATH"

# Agent + dev-tool shell completions (herdr, omp, codex, copilot, gh, grok,
# mise, opencode). After mise so the CLIs are on PATH for the version check,
# and after ~/.local/bin because the refresh helper is invoked by absolute path.
[[ -f ~/.config/shell/agent-completions.sh ]] && source ~/.config/shell/agent-completions.sh

export OPENCODE_AGENT_SKILLS_SUPERPOWERS_MODE=true
