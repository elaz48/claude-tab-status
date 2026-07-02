#!/usr/bin/env bash
#
# claude-tab-status installer
# - copies the binary to ~/.local/bin
# - merges the hook configuration into ~/.claude/settings.json (with backup)
#
# Safe to re-run: existing claude-tab-status hooks are detected and skipped.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${CTS_PREFIX:-$HOME/.local/bin}"
BIN_PATH="$BIN_DIR/claude-tab-status"
SETTINGS_DIR="$HOME/.claude"
SETTINGS="$SETTINGS_DIR/settings.json"
# Keep $HOME literal in settings.json so the config stays portable;
# hook commands run through a shell, which expands it at runtime.
HOOK_CMD='$HOME/.local/bin/claude-tab-status hook'

say()  { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

# --- options -----------------------------------------------------------------
NO_NOTIFY=0
for arg in "$@"; do
  case "$arg" in
    --no-notify) NO_NOTIFY=1 ;;
    -h|--help)
      echo "Usage: ./install.sh [--no-notify]"
      echo "  --no-notify   quiet mode: tab title indicators only, no desktop notifications"
      exit 0 ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

# --- dependency checks ------------------------------------------------------
command -v jq >/dev/null 2>&1 || die "jq is required. Install it first:
    sudo apt install jq        # Debian/Ubuntu
    sudo dnf install jq        # Fedora
    sudo pacman -S jq          # Arch"

if (( NO_NOTIFY == 0 )) && ! command -v notify-send >/dev/null 2>&1; then
  warn "notify-send not found: tab titles will work, desktop notifications will not."
  warn "Install libnotify-bin (Debian/Ubuntu) or libnotify (Fedora/Arch) to enable them,"
  warn "or re-run with --no-notify if you only want tab titles."
fi

# --- install the binary -----------------------------------------------------
mkdir -p "$BIN_DIR"
install -m 0755 "$SCRIPT_DIR/bin/claude-tab-status" "$BIN_PATH"
say "Installed $BIN_PATH"

if (( NO_NOTIFY )); then
  "$BIN_PATH" notify off >/dev/null
  say "Quiet mode: tab title indicators only, no desktop notifications."
  say "Re-enable any time with: claude-tab-status notify on"
fi

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  warn "$BIN_DIR is not on your PATH. Hooks will still work (they use an absolute path),"
  warn "but add it to your PATH to use 'claude-tab-status list' directly."
fi

# --- merge hooks into settings.json -----------------------------------------
mkdir -p "$SETTINGS_DIR"
if [[ ! -f "$SETTINGS" ]]; then
  echo '{}' > "$SETTINGS"
  say "Created $SETTINGS"
fi

jq empty "$SETTINGS" 2>/dev/null || die "$SETTINGS is not valid JSON. Fix it manually, then re-run."

BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"
say "Backed up settings to $BACKUP"

NEW_HOOKS=$(cat <<EOF
{
  "SessionStart":     [ { "hooks": [ { "type": "command", "command": "$HOOK_CMD" } ] } ],
  "UserPromptSubmit": [ { "hooks": [ { "type": "command", "command": "$HOOK_CMD" } ] } ],
  "Stop":             [ { "hooks": [ { "type": "command", "command": "$HOOK_CMD" } ] } ],
  "SessionEnd":       [ { "hooks": [ { "type": "command", "command": "$HOOK_CMD" } ] } ],
  "Notification": [
    { "matcher": "permission_prompt|elicitation_dialog",
      "hooks": [ { "type": "command", "command": "$HOOK_CMD attention" } ] },
    { "matcher": "idle_prompt",
      "hooks": [ { "type": "command", "command": "$HOOK_CMD done" } ] }
  ]
}
EOF
)

TMP=$(mktemp)
jq --argjson new "$NEW_HOOKS" '
  .hooks //= {}
  | reduce ($new | to_entries[]) as $e (
      .;
      if ((.hooks[$e.key] // [])
          | any(.[]?; any(.hooks[]?; ((.command // "") | contains("claude-tab-status")))))
      then .
      else .hooks[$e.key] = ((.hooks[$e.key] // []) + $e.value)
      end
    )
' "$SETTINGS" > "$TMP"

jq empty "$TMP" || die "Generated settings failed validation, aborting. Your original file is untouched."
mv "$TMP" "$SETTINGS"
say "Hooks registered in $SETTINGS"

# --- done --------------------------------------------------------------------
cat <<'EOF'

Done! Next steps:
  1. Restart any running Claude Code sessions (hooks load at startup;
     settings edited mid-session are usually picked up too, but a restart is the sure way).
  2. Run '/hooks' inside Claude Code to verify the entries appear.
  3. Try 'claude-tab-status test' in a terminal tab to see the title cycle.

Watch your tabs:
  💤  idle       session started
  ⚡  working    Claude is processing
  🔴  attention  Claude is waiting for YOU
  ✅  done       finished, your turn

Overview of all sessions:  claude-tab-status list
Notifications on/off:      claude-tab-status notify on|off
EOF
