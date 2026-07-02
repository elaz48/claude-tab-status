#!/usr/bin/env bash
#
# claude-tab-status uninstaller
# Removes the hook entries from ~/.claude/settings.json (with backup),
# deletes the binary and runtime state. Keeps your config file unless
# you pass --purge.

set -euo pipefail

BIN_PATH="${CTS_PREFIX:-$HOME/.local/bin}/claude-tab-status"
SETTINGS="$HOME/.claude/settings.json"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/claude-tab-status"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  STATE_DIR="$XDG_RUNTIME_DIR/claude-tab-status"
else
  STATE_DIR="/tmp/claude-tab-status-$(id -u)"
fi

say()  { printf '\033[32m✔\033[0m %s\n' "$*"; }
die()  { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required to edit settings.json."

if [[ -f "$SETTINGS" ]]; then
  BACKUP="$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  cp "$SETTINGS" "$BACKUP"
  TMP=$(mktemp)
  jq '
    if .hooks then
      .hooks |= with_entries(
        .value |= map(select(
          (any(.hooks[]?; ((.command // "") | contains("claude-tab-status")))) | not
        ))
      )
      | .hooks |= with_entries(select((.value | length) > 0))
      | if (.hooks | length) == 0 then del(.hooks) else . end
    else . end
    | if ((.env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE? // "") == "1") then
        del(.env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE)
        | if ((.env // {}) | length) == 0 then del(.env) else . end
      else . end
  ' "$SETTINGS" > "$TMP"
  jq empty "$TMP" || die "Generated settings failed validation, aborting."
  mv "$TMP" "$SETTINGS"
  say "Removed claude-tab-status hooks from $SETTINGS (backup: $BACKUP)"
  say "Removed env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE if it was set to 1,"
  say "so Claude Code's native title updates are back."
fi

rm -f "$BIN_PATH" && say "Removed $BIN_PATH"
rm -rf "$STATE_DIR" && say "Removed runtime state"

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$CONFIG_DIR" && say "Removed config $CONFIG_DIR"
else
  [[ -d "$CONFIG_DIR" ]] && say "Kept config $CONFIG_DIR (use --purge to remove it)"
fi

say "Uninstalled. Restart running Claude Code sessions to drop the hooks."
