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

if [ "$REMOVE" -eq 0 ]; then
  install -m 755 "$SRC_DIR/notify.sh" "$HOOK"
  PROGRAM='
    def clean: map(.hooks |= map(select((.command // "") | test("notify\\.sh") | not)))
             | map(select((.hooks | length) > 0));
    .hooks //= {}
    | .hooks.Stop = (((.hooks.Stop // []) | clean)
        + [{hooks:[{type:"command", command:($h + " stop"),  async:true, timeout:15}]}])
    | .hooks.Notification = (((.hooks.Notification // []) | clean)
        + [{hooks:[{type:"command", command:($h + " input"), async:true, timeout:15}]}])
  '
else
  PROGRAM='
    def clean: map(.hooks |= map(select((.command // "") | test("notify\\.sh") | not)))
             | map(select((.hooks | length) > 0));
    .hooks //= {}
    | .hooks.Stop = ((.hooks.Stop // []) | clean)
    | .hooks.Notification = ((.hooks.Notification // []) | clean)
    | del(.hooks.Stop | select(length == 0))
    | del(.hooks.Notification | select(length == 0))
  '
fi

jq --arg h "$HOOK" "$PROGRAM" "$SETTINGS" > "$SETTINGS.tmp"
jq -e . "$SETTINGS.tmp" >/dev/null || { rm -f "$SETTINGS.tmp"; echo "refusing to write invalid JSON" >&2; exit 1; }
mv "$SETTINGS.tmp" "$SETTINGS"

if [ "$REMOVE" -eq 0 ]; then
  echo "hook script: $HOOK"
  echo "settings:    $SETTINGS (backup: $BACKUP)"
  echo "wired:       Stop -> notify.sh stop, Notification -> notify.sh input"
  echo "restart Claude Code for the hooks to take effect in this session."
else
  echo "removed notify.sh from Stop and Notification in $SETTINGS"
  echo "backup:  $BACKUP"
  echo "the script itself is still at $HOOK - delete it if you want it gone."
fi
