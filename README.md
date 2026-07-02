<div align="center">

# claude-tab-status

### Know which tab needs you. Instantly.

Glanceable status for every [Claude Code](https://code.claude.com) session, right in your terminal tab titles.
Linux-native. Zero workflow change. One bash script.

![Platform: Linux](https://img.shields.io/badge/platform-Linux-FCC624?logo=linux&logoColor=black)
![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)
![Dependencies: jq](https://img.shields.io/badge/dependencies-jq-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow)

</div>

```
 ┌───────────────┬───────────────┬───────────────┬───────────────┐
 │ ⚡ api-server  │ 🔴 checkout   │ ✅ landing    │ 💤 infra      │
 └───────────────┴───────────────┴───────────────┴───────────────┘
     working        NEEDS YOU        done            idle
```

## Why

You run three Claude Code sessions in parallel, each in its own tab. Now you play the game every agentic developer knows: click, click, click... *which one is stuck on a permission prompt?*

Claude Code's built-in tab title only knows two states, so "finished" and "blocked waiting for your approval" look exactly the same. `claude-tab-status` gives you four states you can read from across the room:

| | State | Meaning | Desktop notification |
|---|---|---|---|
| 💤 | **idle** | session started, nothing submitted yet | no |
| ⚡ | **working** | Claude is processing your prompt | no |
| 🔴 | **attention** | Claude is waiting for YOU (permission / input) | yes, critical |
| ✅ | **done** | turn finished, your move | yes, normal |

No tmux. No wrapper app. No new UI to learn. It hooks into Claude Code's official [hooks API](https://code.claude.com/docs/en/hooks-guide), observes lifecycle events, and writes the status straight to each session's own terminal. Keep using your tabs exactly as before.

## Quick start

```bash
git clone https://github.com/USERNAME/claude-tab-status.git
cd claude-tab-status
./install.sh
```

The installer registers the hooks and also sets `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` in your settings' `env` block, the official switch that stops Claude Code from overwriting your status titles with its own. Prefer Claude's native titles? Install with `--keep-native-title` (the 🔴 and ✅ states will still stick, but 💤 and ⚡ will get overwritten).

Restart your Claude Code sessions, then watch the magic:

```bash
claude-tab-status test    # cycles all four states on the current tab
```

**Requirements:** Linux, `jq`, any terminal that honors OSC title sequences (GNOME Terminal, Konsole, Kitty, WezTerm, Ghostty, Alacritty, XTerm... basically all of them). `notify-send` is optional (package `libnotify-bin` on Debian/Ubuntu).

## Tab titles only? Sure.

If desktop popups are not your thing, run everything in quiet mode. Tab title indicators stay on, notifications go away:

```bash
./install.sh --no-notify        # quiet from the start
claude-tab-status notify off    # or toggle any time
claude-tab-status notify on     # changed your mind
```

## The mini dashboard

Every hook event also records session state, so one command shows all your tabs at once:

```
$ claude-tab-status list
STATUS         PROJECT                  SINCE      TTY
🔴 attention   checkout                 2m ago     pts/3
⚡ working     api-server               14s ago    pts/1
✅ done        landing-page             8m ago     pts/5
```

Dead terminals and stale sessions are pruned automatically.

## Updating

```bash
cd claude-tab-status
git pull
./install.sh
```

The installer is idempotent: re-running it never duplicates hooks, it just refreshes the binary and adds any hook entries introduced by the new version. Because hooks invoke the binary fresh on every event, **script updates take effect immediately**. Only if a new version changes the hook configuration itself do you need to restart your Claude Code sessions.

## Your settings.json is safe

This tool touches `~/.claude/settings.json`, so it treats it with respect:

- **Every modification is backed up first.** Both `install.sh` and `uninstall.sh` create a timestamped copy like `settings.json.bak.20260702091500` before writing anything. Backups are never deleted automatically.
- **The merge is additive.** Your existing hooks, statusLine, permissions and everything else stay untouched. Only `claude-tab-status` entries are added.
- **Uninstall is surgical.** It removes only hook entries whose command contains `claude-tab-status`. Everything else is preserved byte for byte.

Want to roll back to any earlier state by hand?

```bash
ls -t ~/.claude/settings.json.bak.*                     # list backups, newest first
cp ~/.claude/settings.json.bak.<timestamp> ~/.claude/settings.json
```

Then restart your Claude Code sessions so the restored config is loaded.

## Configuration

Optional. Create `~/.config/claude-tab-status/config` (plain shell, sourced at runtime):

```bash
CTS_EMOJI_WORKING="⚡"
CTS_EMOJI_ATTENTION="🔴"
CTS_EMOJI_DONE="✅"
CTS_EMOJI_IDLE="💤"
CTS_NOTIFY=1             # master switch: 0 = tab titles only
CTS_NOTIFY_ATTENTION=1   # notify when Claude waits for you
CTS_NOTIFY_DONE=1        # notify when Claude finishes a turn
CTS_STALE_HOURS=12       # prune session state older than this
CTS_DEBUG=0              # 1 = log to $XDG_RUNTIME_DIR/claude-tab-status/debug.log
```

## How it works

Claude Code fires lifecycle hooks (`SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Notification`, `Stop`, `SessionEnd`) and pipes a JSON payload to the hook command's stdin. The script:

1. reads `hook_event_name`, `cwd`, `session_id` and `message` from the payload,
2. resolves the terminal device of that exact session (controlling tty, with a process-tree walk as fallback),
3. writes an OSC 0 title sequence (`ESC ] 0 ; title BEL`) directly to that device, which your terminal renders as the tab title,
4. records the state under `$XDG_RUNTIME_DIR/claude-tab-status/` for the `list` command,
5. optionally fires `notify-send` on attention and done transitions.

Because the title goes to the tty of the session that emitted the event, every tab gets its own status. Works the same over SSH.

The `PostToolUse` hook re-asserts ⚡ on every tool call. This keeps the working state alive during long turns, and it is also what flips 🔴 back to ⚡ the moment you approve a permission prompt and Claude resumes.

## Good to know

- **💤 or ⚡ not sticking?** That means Claude Code's own title updates are still on and racing with the status writer. Re-run `./install.sh` (it sets `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` since v0.3.0) and restart your sessions. If you installed with `--keep-native-title`, this is expected behavior.
- **tmux:** inside tmux the OSC sequence sets the pane title. Add `set -g set-titles on` to `~/.tmux.conf` to propagate it to the outer window title.
- **`idle_prompt` maps to ✅, not 🔴,** on purpose: a session that simply finished should not scream for attention.

## Security

No network calls, no telemetry, one auditable bash file. Payload-derived values are stripped of control characters before touching your terminal (escape-sequence injection from hostile directory names is neutralized), path components are whitelist-filtered, and the state directory refuses symlinks. Settings changes are additive, jq-validated, and preceded by permission-preserving backups. Details and reporting: [SECURITY.md](SECURITY.md).

## Roadmap

- Focus-jump: click a notification or a `list` row to raise the right tab (Kitty and WezTerm expose remote-control APIs)
- System tray / waybar indicator
- Sibling agents: Codex CLI, Gemini CLI
- Configurable title template

## Uninstall

```bash
./uninstall.sh          # removes hooks (with backup), binary, runtime state
./uninstall.sh --purge  # also removes the config file
```

Uninstalling also removes `env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE` (only if it is set to `"1"`), so Claude Code's native titles come back automatically. As always, a timestamped backup of `settings.json` is created before the change.

---

If this saves you a few hundred tab switches a day, a ⭐ helps others find it.

*This is an independent community tool, not affiliated with Anthropic.* MIT licensed.
