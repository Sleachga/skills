#!/usr/bin/env bash
# install-hooks.sh — wire notify.sh into Claude Code's Stop and Notification hooks.
#
#   install-hooks.sh            install or repair
#   install-hooks.sh --remove   strip the hooks (leaves the installed script)
#
# Copies notify.sh to ~/.claude/hooks/notify.sh and points the hooks at that
# stable path, so a plugin update relocating the cache cannot break them.
# Idempotent: prior notify.sh entries are stripped before ours is added, and
# unrelated hooks on those events are left alone.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOK_DIR="$CLAUDE_DIR/hooks"
HOOK="$HOOK_DIR/notify.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
REMOVE=0
[ "${1:-}" = "--remove" ] && REMOVE=1

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

mkdir -p "$HOOK_DIR"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
jq -e . "$SETTINGS" >/dev/null 2>&1 || { echo "$SETTINGS is not valid JSON - fix it first" >&2; exit 1; }

BACKUP="$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"
cp "$SETTINGS" "$BACKUP"

# PermissionRequest is the event that actually fires when Claude is blocked
# waiting for approval, and it carries tool_name/tool_input so the push can say
# what is being asked for. Notification is kept alongside it: it covers the
# other things Claude Code notifies about, such as auth failures.
#
# Every entry is async so a notification never delays the permission prompt
# itself, and never blocks a turn behind an unreachable relay.
if [ "$REMOVE" -eq 0 ]; then
  install -m 755 "$SRC_DIR/notify.sh" "$HOOK"
  PROGRAM='
    def clean: map(.hooks |= map(select((.command // "") | test("notify\\.sh") | not)))
             | map(select((.hooks | length) > 0));
    def wire($ev; $arg):
      .hooks[$ev] = (((.hooks[$ev] // []) | clean)
        + [{hooks:[{type:"command", command:($h + " " + $arg), async:true, timeout:15}]}]);
    .hooks //= {}
    | wire("Stop";              "stop")
    | wire("Notification";      "input")
    | wire("PermissionRequest"; "permission")
  '
else
  PROGRAM='
    def clean: map(.hooks |= map(select((.command // "") | test("notify\\.sh") | not)))
             | map(select((.hooks | length) > 0));
    def strip($ev): .hooks[$ev] = ((.hooks[$ev] // []) | clean);
    .hooks //= {}
    | strip("Stop") | strip("Notification") | strip("PermissionRequest")
    | .hooks |= with_entries(select((.value | length) > 0))
  '
fi

jq --arg h "$HOOK" "$PROGRAM" "$SETTINGS" > "$SETTINGS.tmp"
jq -e . "$SETTINGS.tmp" >/dev/null || { rm -f "$SETTINGS.tmp"; echo "refusing to write invalid JSON" >&2; exit 1; }
mv "$SETTINGS.tmp" "$SETTINGS"

if [ "$REMOVE" -eq 0 ]; then
  echo "hook script: $HOOK"
  echo "settings:    $SETTINGS (backup: $BACKUP)"
  echo "wired:       Stop -> stop, Notification -> input, PermissionRequest -> permission"
  echo "restart Claude Code for the hooks to take effect in this session."
else
  echo "removed notify.sh from Stop, Notification and PermissionRequest in $SETTINGS"
  echo "backup:  $BACKUP"
  echo "the script itself is still at $HOOK - delete it if you want it gone."
fi
