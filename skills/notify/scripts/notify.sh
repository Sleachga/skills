#!/usr/bin/env bash
# notify.sh — local sound + ntfy push for Claude Code.
#
#   notify.sh stop           hook mode, Stop event        (hook JSON on stdin)
#   notify.sh input          hook mode, Notification event (hook JSON on stdin)
#   notify.sh push "text"    ad-hoc push
#   notify.sh init [--force] create/print the ntfy topic
#   notify.sh test           push a probe, verify the server accepted it
#   notify.sh status         print config and hook wiring
#
# Config (all optional):
#   ~/.claude/ntfy-topic   topic name, one line          (or $NTFY_TOPIC)
#   NTFY_SERVER            default https://ntfy.sh
#   CLAUDE_NOTIFY_SOUND    path to a sound file
#   CLAUDE_NOTIFY_SILENT   set to any value to mute the local sound

set -uo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TOPIC_FILE="$CLAUDE_DIR/ntfy-topic"
SETTINGS="$CLAUDE_DIR/settings.json"
SERVER="${NTFY_SERVER:-https://ntfy.sh}"
DEFAULT_SOUND="/System/Library/Sounds/Glass.aiff"
SOUND="${CLAUDE_NOTIFY_SOUND:-$DEFAULT_SOUND}"

die() { printf '%s\n' "$*" >&2; exit 1; }

read_topic() {
  if [ -n "${NTFY_TOPIC:-}" ]; then printf '%s' "$NTFY_TOPIC"; return 0; fi
  [ -r "$TOPIC_FILE" ] || return 1
  tr -d '[:space:]' < "$TOPIC_FILE"
}

# read_topic succeeds on an empty topic file; callers that are about to push
# need the stronger check, or a blank topic misreports as a network failure.
require_topic() {
  local topic
  topic="$(read_topic)" || return 1
  [ -n "$topic" ] || return 1
  printf '%s' "$topic"
}

play_sound() {
  [ -z "${CLAUDE_NOTIFY_SILENT:-}" ] || return 0
  if [ -r "$SOUND" ]; then
    if   command -v afplay >/dev/null 2>&1; then afplay "$SOUND" >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then paplay "$SOUND" >/dev/null 2>&1 &
    elif command -v aplay  >/dev/null 2>&1; then aplay -q "$SOUND" >/dev/null 2>&1 &
    else printf '\a'
    fi
  else
    printf '\a'
  fi
}

# push <title> <body> <tags> <priority>
push() {
  local topic; topic="$(read_topic)" || return 1
  [ -n "$topic" ] || return 1
  curl -fsS --max-time 8 \
    -H "Title: $1" -H "Tags: $3" -H "Priority: $4" \
    -d "$2" "$SERVER/$topic" >/dev/null 2>&1
}

project_name() {
  local cwd="${1:-}"
  [ -n "$cwd" ] || cwd="$PWD"
  basename "$cwd"
}

cmd_hook() {   # $1 = stop|input
  local payload cwd body
  payload="$(cat)"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
  if [ "$1" = "input" ]; then
    body="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
    [ -n "$body" ] || body="Waiting for your input"
    play_sound; push "Claude Code - $(project_name "$cwd")" "$body" "bell" "4"
  else
    play_sound; push "Claude Code - $(project_name "$cwd")" "Turn finished" "white_check_mark" "3"
  fi
  wait
  exit 0
}

cmd_push() {
  local body="$*"
  [ -n "$body" ] || die "usage: notify.sh push \"message\""
  require_topic >/dev/null || die "no topic configured - run: notify.sh init"
  play_sound
  push "Claude Code - $(project_name)" "$body" "speech_balloon" "3" \
    || die "push failed - check network and \$NTFY_SERVER"
  wait
}

cmd_init() {
  local existing
  if existing="$(read_topic)" && [ -n "$existing" ] && [ "${1:-}" != "--force" ]; then
    printf 'topic already configured: %s\n' "$existing"
    printf '(pass --force to rotate - you must resubscribe on your phone)\n'
    return 0
  fi
  mkdir -p "$CLAUDE_DIR"
  local topic="claude-code-$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 20)"
  printf '%s\n' "$topic" > "$TOPIC_FILE"
  chmod 600 "$TOPIC_FILE"
  printf 'topic: %s\n' "$topic"
  printf 'subscribe to this in the ntfy app (server: %s)\n' "$SERVER"
}

cmd_test() {
  local topic stamp
  topic="$(require_topic)" || die "no topic configured - run: notify.sh init"
  stamp="probe-$(date +%s)"
  play_sound
  push "Claude Code - test" "$stamp" "test_tube" "4" || die "push rejected by $SERVER"
  # the relay needs a moment before a message is pollable
  local i found=0
  for i in 1 2 3 4 5; do
    sleep 2
    if curl -fsS --max-time 10 "$SERVER/$topic/json?poll=1" 2>/dev/null | grep -q "$stamp"; then
      found=1; break
    fi
  done
  [ "$found" -eq 1 ] || die "push sent but never appeared on $SERVER - wrong topic or relay down"
  printf 'server accepted the push (%s, confirmed after %ss)\n' "$stamp" "$((i * 2))"
  printf 'now confirm it actually buzzed the phone and watch.\n'
  wait
}

cmd_status() {
  local topic
  if topic="$(read_topic)" && [ -n "$topic" ]; then
    printf 'topic:   %s\n' "$topic"
  else
    printf 'topic:   (none - run: notify.sh init)\n'
  fi
  printf 'server:  %s\n' "$SERVER"
  if [ -n "${CLAUDE_NOTIFY_SILENT:-}" ]; then
    printf 'sound:   muted (CLAUDE_NOTIFY_SILENT set)\n'
  elif [ -r "$SOUND" ]; then
    printf 'sound:   %s\n' "$SOUND"
  else
    printf 'sound:   %s (unreadable - falls back to terminal bell)\n' "$SOUND"
  fi
  local ev
  for ev in Stop Notification; do
    if [ -r "$SETTINGS" ] && jq -e --arg e "$ev" \
         '[.hooks[$e][]?.hooks[]?.command? // empty] | any(test("notify\\.sh"))' \
         "$SETTINGS" >/dev/null 2>&1; then
      printf 'hook %-13s wired\n' "$ev:"
    else
      printf 'hook %-13s not installed\n' "$ev:"
    fi
  done
}

case "${1:-}" in
  stop|input) cmd_hook "$1" ;;
  push)       shift; cmd_push "$@" ;;
  init)       shift; cmd_init "${1:-}" ;;
  test)       cmd_test ;;
  status)     cmd_status ;;
  *)          die "usage: notify.sh {stop|input|push <msg>|init [--force]|test|status}" ;;
esac
