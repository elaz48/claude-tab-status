# Security

## Threat model, in plain words

`claude-tab-status` is a single bash script invoked by Claude Code's hooks. What it does and does not do:

- **No network access.** The script never makes network calls. No telemetry, no update checks, no phoning home.
- **Reads:** the JSON hook payload on stdin, and its own config file.
- **Writes:** OSC title sequences to the session's own terminal device, per-session state JSON under `$XDG_RUNTIME_DIR/claude-tab-status/` (mode 700), and desktop notifications via `notify-send`.
- **Settings changes** (`~/.claude/settings.json`) happen only in `install.sh`/`uninstall.sh`: additive, jq-validated, with a permission-preserving timestamped backup before every write.

## Input handling

Hook payload values are treated as untrusted, because parts of them (like the working directory name) can be influenced by whatever repository Claude is working in:

- Values written into terminal escape sequences or notifications are stripped of control characters and length-capped, preventing escape-sequence injection from hostile directory names.
- Values used in file paths (`session_id`) are whitelist-filtered to `[A-Za-z0-9._-]`, preventing path traversal.
- Nothing from the payload is ever evaluated as code; JSON is parsed with `jq` only.
- The state directory is refused if it is a symlink or not owned by the current user (relevant for the `/tmp` fallback when `XDG_RUNTIME_DIR` is unset).

## Known trust assumptions

- The config file `~/.config/claude-tab-status/config` is sourced as shell. This is the same trust model as `~/.bashrc`: anyone who can write to your home directory already has code execution as you.
- Hook payloads come from your local Claude Code process, which is trusted; the sanitization above is defense in depth against payload *contents* influenced by untrusted repositories.

## Reporting a vulnerability

Please report vulnerabilities privately via GitHub Security Advisories on this repository (Security tab, "Report a vulnerability") rather than opening a public issue. You can expect a response within a few days.
