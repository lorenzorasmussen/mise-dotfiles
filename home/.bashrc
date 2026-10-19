# Omarchy environment (OMARCHY_PATH + PATH), needed even for non-interactive shells
[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap
# Ensure working directory is persistent (home directory)
cd "$HOME"

# Agent cookie persistence exports (MUST be before interactive guard)
export OMARCHY_COOKIE_PERSIST="true"
export OMNP_COOKIE_PATH="$HOME/.local/share/agent-cookie/"
# Pi's agent directory is scoped by ~/.local/bin/pi, not inherited by other tools.
unset PI_CODING_AGENT_DIR

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
# on PATH for the version check.
[[ -f ~/.config/shell/openclaw-completions.sh ]] && source ~/.config/shell/openclaw-completions.sh

# Composio CLI

# Agent + dev-tool shell completions (herdr, omp, codex, copilot, gh, grok,
# mise, opencode). After mise so the CLIs are on PATH for the version check,
# and after ~/.local/bin because the refresh helper is invoked by absolute path.
[[ -f ~/.config/shell/agent-completions.sh ]] && source ~/.config/shell/agent-completions.sh

# zoxide - smart `cd` (z, zi). Omarchy's default/bash/init already runs this
# (sourced at line 16 above), so this guarded line is a no-op while Omarchy
# provides the hook and takes over if that default ever stops. It is safe to
# run twice: the generated bash hook only appends __zoxide_hook to
# PROMPT_COMMAND when it is not already there. pacman owns /usr/bin/zoxide;
# it is not a mise tool.
if command -v zoxide >/dev/null 2>&1 && ! declare -F __zoxide_hook >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# fzf native bash integration (completion + key bindings: Ctrl+R history, Alt+C cd, Ctrl+T files)
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

export OPENCODE_AGENT_SKILLS_SUPERPOWERS_MODE=true

# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/installs/node/26.10.0/bin:$PATH"  # User-acquired agents

# User-acquired agents (added 2026-10-14)

# Devin usage shortcut (Devin only)
alias dusage='devin-cli-usage status'

# Combined usage for all AI providers (Devin, Copilot, Cursor, etc.)
alias ai-usage='omp usage'

# Individual tool usage shortcuts (concise output)
alias pi-usage='echo "Pi: No usage API. Run \"pi auth check --provider <name>\" to check provider"'
alias omp-usage='omp usage'
alias claude-usage='echo "Claude: Not logged in. Run \"claude auth login\" or check claude.ai"'
alias codex-usage='echo "Codex: Login status only - no usage API. Check web dashboard"'
alias copilot-usage='omp usage | grep -A 5 "Github Copilot"'
alias devin-usage='devin-cli-usage status'
alias droid-usage='echo "Droid: No usage command. Check Factory dashboard at factory.ai"'
alias kimi-usage='echo "Kimi: No usage command. Check web dashboard"'
alias opencode-usage='opencode stats --days 7 2>/dev/null | head -30'
alias kilo-usage='kilo stats --days 7 2>/dev/null | head -20'
alias hermes-usage='hermes usage 2>/dev/null || echo "No usage data"'
alias godercli-usage='echo "godercli: Command not found"'
alias qwen-usage='echo "Qwen: No usage command. Check web dashboard"'
alias cursor-usage='echo "Cursor: CLI hangs. Check cursor.sh dashboard or use omp usage"'
alias mastracode-usage='echo "Mastracode: No usage command. Check web dashboard"'
alias antigravity-usage='omp usage | grep -A 5 "Google Antigravity"'
alias grok-usage='echo "Grok: Run \"grok sessions list\" then \"grok usage <session_id>\""'
[[ -f /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion