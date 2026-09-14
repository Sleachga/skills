#!/usr/bin/env bash
# notify.sh — local sound + ntfy push for Claude Code.
#
#   notify.sh stop           hook mode, Stop event              (hook JSON on stdin)
#   notify.sh input          hook mode, Notification event      (hook JSON on stdin)
#   notify.sh permission     hook mode, PermissionRequest event (hook JSON on stdin)
#   notify.sh push "text"    ad-hoc push
#   notify.sh init [--force] create/print the ntfy topic
#   notify.sh setup          guided first-time setup, start to finish
#   notify.sh auth           store an ntfy access token (reads it from stdin)
#   notify.sh auth --clear   forget the stored token
#   notify.sh test           push a probe, verify the server accepted it
#   notify.sh status         print config and hook wiring
#
# Config (all optional):
#   ~/.claude/ntfy-topic   topic name, one line          (or $NTFY_TOPIC)
#   ~/.claude/ntfy-token   ntfy access token, one line   (or $NTFY_TOKEN)
#   ~/.claude/ntfy-server  relay URL, one line           (or $NTFY_SERVER)
#   NTFY_USER/NTFY_PASSWORD  basic auth, if the server uses it instead
#   NTFY_SERVER            default https://ntfy.sh
#   CLAUDE_NOTIFY_SOUND    path to a sound file
#   CLAUDE_NOTIFY_SILENT   set to any value to mute the local sound

set -uo pipefail

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TOPIC_FILE="$CLAUDE_DIR/ntfy-topic"
TOKEN_FILE="$CLAUDE_DIR/ntfy-token"
SERVER_FILE="$CLAUDE_DIR/ntfy-server"
SETTINGS="$CLAUDE_DIR/settings.json"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

read_server() {
  if [ -n "${NTFY_SERVER:-}" ]; then printf '%s' "$NTFY_SERVER"; return 0; fi
  if [ -r "$SERVER_FILE" ] && [ -s "$SERVER_FILE" ]; then
    tr -d '[:space:]' < "$SERVER_FILE"; return 0
  fi
  printf 'https://ntfy.sh'
}
SERVER="$(read_server)"
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

read_token() {
  if [ -n "${NTFY_TOKEN:-}" ]; then printf '%s' "$NTFY_TOKEN"; return 0; fi
  [ -r "$TOKEN_FILE" ] || return 1
  tr -d '[:space:]' < "$TOKEN_FILE"
}

# emits nothing when the relay needs no credentials, which is the ntfy.sh default
auth_args() {
  local tok
  if tok="$(read_token)" && [ -n "$tok" ]; then
    AUTH=(-H "Authorization: Bearer $tok")
  elif [ -n "${NTFY_USER:-}" ]; then
    AUTH=(-u "${NTFY_USER}:${NTFY_PASSWORD:-}")
  else
    AUTH=()
  fi
}

auth_kind() {
  if [ -n "${NTFY_TOKEN:-}" ]; then printf 'token (from $NTFY_TOKEN)'
  elif [ -r "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then printf 'token (%s)' "$TOKEN_FILE"
  elif [ -n "${NTFY_USER:-}" ]; then printf 'basic auth as %s' "$NTFY_USER"
  else printf 'none (topic name is the only secret)'; fi
}

play_sound() {
  [ -z "${CLAUDE_NOTIFY_SILENT:-}" ] || return 0
  if [ -r "$SOUND" ]; then
    if   command -v afplay >/dev/null 2>&1; then afplay "$SOUND" >/dev/null 2>&1 &
    elif command -v paplay >/dev/null 2>&1; then paplay "$SOUND" >/dev/null 2>&1 &
    elif command -v aplay  >/dev/null 2>&1; then aplay -q "$SOUND" >/dev/null 2>&1 &
    else printf '\a' >&2
    fi
  else
    printf '\a' >&2
  fi
}

# push <title> <body> <tags> <priority>
#   0 delivered · 1 unreachable or refused · 3 auth rejected
push() {
  local topic code; topic="$(read_topic)" || return 1
  [ -n "$topic" ] || return 1
  auth_args
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 \
    -H "Title: $1" -H "Tags: $3" -H "Priority: $4" \
    ${AUTH[@]+"${AUTH[@]}"} \
    -d "$2" "$SERVER/$topic" 2>/dev/null)" || return 1
  case "$code" in
    2??)     return 0 ;;
    401|403) return 3 ;;
    *)       return 1 ;;
  esac
}

project_name() {
  local cwd="${1:-}"
  [ -n "$cwd" ] || cwd="$PWD"
  basename "$cwd"
}

# keep a push readable on a watch face rather than truncated by the OS
clamp() {
  local s="$1" n="${2:-110}"
  if [ "${#s}" -le "$n" ]; then printf '%s' "$s"
  else printf '%s...' "${s:0:$((n - 3))}"; fi
}

cmd_hook() {   # $1 = stop|input|permission
  local payload cwd body
  payload="$(cat)"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
  case "$1" in
    permission)
      # PermissionRequest carries tool_name and tool_input, so say what is being
      # asked for. "Bash: rm -rf build" tells you whether to walk back to the
      # desk; "waiting for input" does not.
      body="$(printf '%s' "$payload" | jq -r '
        (.tool_name // "") as $t
        | (.tool_input // {}) as $i
        | ($i.command // $i.file_path // $i.path // $i.url // $i.pattern // "") as $d
        | if ($t | length) == 0 then ""
          elif ($d | length) > 0 then "\($t): \($d)"
          else "\($t) needs approval" end' 2>/dev/null)"
      [ -n "$body" ] || body="Needs your approval to continue"
      play_sound
      push "Claude Code - $(project_name "$cwd")" "$(clamp "$body")" "lock" "4"
      ;;
    input)
      body="$(printf '%s' "$payload" | jq -r '.message // empty' 2>/dev/null)"
      [ -n "$body" ] || body="Waiting for your input"
      play_sound
      push "Claude Code - $(project_name "$cwd")" "$(clamp "$body")" "bell" "4"
      ;;
    *)
      play_sound
      push "Claude Code - $(project_name "$cwd")" "Turn finished" "white_check_mark" "3"
      ;;
  esac
  wait
  # always 0: a notification must never fail a turn, and on PermissionRequest a
  # non-zero exit would interfere with the permission decision itself
  exit 0
}

cmd_push() {
  local body="$*"
  [ -n "$body" ] || die "usage: notify.sh push \"message\""
  require_topic >/dev/null || die "no topic configured - run: notify.sh init"
  play_sound
  push "Claude Code - $(project_name)" "$body" "speech_balloon" "3"
  case "$?" in
    0) ;;
    3) die "relay rejected the credentials - run: notify.sh auth" ;;
    *) die "push failed - check network and \$NTFY_SERVER" ;;
  esac
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

cmd_auth() {
  if [ "${1:-}" = "--clear" ]; then
    rm -f "$TOKEN_FILE"
    printf 'token removed. pushes now rely on the topic name alone.\n'
    return 0
  fi
  [ "${1:-}" = "" ] || die "usage: notify.sh auth [--clear]   (the token is read from stdin)"

  local tok
  if [ -t 0 ]; then
    printf 'paste the ntfy access token, then press enter (input hidden): ' >&2
    read -r -s tok; printf '\n' >&2
  else
    read -r tok || true
  fi
  tok="$(printf '%s' "${tok:-}" | tr -d '[:space:]')"
  [ -n "$tok" ] || die "no token given - nothing written"

  mkdir -p "$CLAUDE_DIR"
  (umask 077; printf '%s\n' "$tok" > "$TOKEN_FILE")
  chmod 600 "$TOKEN_FILE"
  # never echo the token back; the whole point is that it stays out of scrollback
  case "$tok" in
    tk_*) printf 'token saved to %s (mode 600)\n' "$TOKEN_FILE" ;;
    *)    printf 'token saved to %s (mode 600)\n' "$TOKEN_FILE"
          printf 'note: ntfy access tokens usually start with tk_ - check it if pushes 401\n' ;;
  esac
  printf 'verify with: notify.sh test\n'
}

ask() {  # ask <prompt> <default>  -> echoes the answer
  local reply
  printf '%s' "$1" >&2
  read -r reply || reply=""
  printf '%s' "${reply:-$2}"
}

# The whole first-time flow in one command. It exists so the user can run setup
# themselves in their own terminal: the access token is prompted for here, with
# echo off, and so never has to travel through a conversation with Claude.
cmd_setup() {
  local interactive=1; [ -t 0 ] || interactive=0
  local topic choice srv yn

  printf '\n=== notify setup ===\n\n'

  # --- 1. topic -------------------------------------------------------------
  if topic="$(require_topic)"; then
    printf '1/5  topic: %s\n     (already configured; notify.sh init --force rotates it)\n' "$topic"
  else
    cmd_init >/dev/null || die "could not create a topic"
    topic="$(require_topic)" || die "topic was not written"
    printf '1/5  topic: %s\n     (new)\n' "$topic"
  fi
  printf '\n     Subscribe to that exact string in the ntfy phone app.\n\n'

  # --- 2. relay and credentials --------------------------------------------
  if [ "$interactive" -eq 1 ]; then
    printf '2/5  Which relay?\n'
    printf '       1) public ntfy.sh, no account\n'
    printf '       2) ntfy Pro, access token\n'
    printf '       3) self-hosted server\n'
    choice="$(ask '     choose [1]: ' 1)"
    case "$choice" in
      2) cmd_auth ;;
      3) srv="$(ask '     server URL (e.g. https://ntfy.example.com): ' '')"
         if [ -n "$srv" ]; then
           mkdir -p "$CLAUDE_DIR"; printf '%s\n' "$srv" > "$SERVER_FILE"; SERVER="$srv"
           printf '     server saved to %s\n' "$SERVER_FILE"
         fi
         yn="$(ask '     use an access token? [y/N]: ' n)"
         case "$yn" in
           [Yy]*) cmd_auth ;;
           *) printf '     no token stored. set NTFY_USER and NTFY_PASSWORD for basic auth.\n' ;;
         esac ;;
      *) printf '     Public relay. There are no accounts on the free tier, so anyone\n'
         printf '     who knows the topic string can read everything pushed to it —\n'
         printf '     including the command line in an approval notification.\n' ;;
    esac
  else
    printf '2/5  credentials: skipped, this is not a terminal.\n'
    printf '     ASK which relay is in use before calling this done:\n'
    printf '       * public ntfy.sh  -> nothing more to do, but say plainly that\n'
    printf '         anyone knowing the topic can read every push, including the\n'
    printf '         command line in an approval notification\n'
    printf '       * ntfy Pro or self-hosted -> a token is required, and only the\n'
    printf '         user can enter it. Give them exactly this line to run:\n'
    printf '             %s auth\n' "$SELF_DIR/notify.sh"
  fi
  printf '\n'

  # --- 3. hooks -------------------------------------------------------------
  if [ -x "$SELF_DIR/install-hooks.sh" ]; then
    if [ "$interactive" -eq 1 ]; then
      yn="$(ask '3/5  Install the Claude Code hooks now? [Y/n]: ' y)"
    else
      yn=y
      printf '3/5  installing hooks\n'
    fi
    case "$yn" in
      [Nn]*) printf '     skipped. run install-hooks.sh when ready.\n' ;;
      *)     "$SELF_DIR/install-hooks.sh" 2>&1 | sed 's/^/     /' || printf '     hook install failed - see above\n' ;;
    esac
  else
    printf '3/5  install-hooks.sh not found next to this script; install hooks manually.\n'
  fi
  printf '\n'

  # --- 4. what we ended up with --------------------------------------------
  printf '4/5  configuration\n'
  cmd_status | sed 's/^/     /'
  printf '\n'

  # --- 5. verify ------------------------------------------------------------
  # a push is an outbound message to a third party, so ask before sending one
  if [ "$interactive" -eq 1 ]; then
    yn="$(ask '5/5  Send a test push now? Subscribe on the phone first. [Y/n]: ' y)"
  else
    yn=n
    printf '5/5  test push skipped (not a terminal). run "notify.sh test" when subscribed.\n'
  fi
  case "$yn" in
    [Nn]*) [ "$interactive" -eq 1 ] && printf '     skipped. run "notify.sh test" when you are subscribed.\n' ;;
    *)     cmd_test || printf '     test failed - see the message above.\n' ;;
  esac

  printf '\n=== remaining ===\n'
  if [ "$interactive" -eq 0 ]; then
    printf '  * confirm which relay, and hand over the auth command if it needs one\n'
  fi
  printf '  * install ntfy (Play Store / App Store), subscribe to: %s\n' "$topic"
  printf '  * watch: Galaxy Wearable -> Notifications -> enable ntfy,\n'
  printf '           or Watch app -> Notifications -> ntfy -> Mirror iPhone\n'
  printf '  * restart Claude Code, or the hooks stay dormant this session\n\n'
}

cmd_test() {
  local topic stamp
  topic="$(require_topic)" || die "no topic configured - run: notify.sh init"
  stamp="probe-$(date +%s)"
  play_sound
  push "Claude Code - test" "$stamp" "test_tube" "4"
  case "$?" in
    0) ;;
    3) die "relay rejected the credentials - run: notify.sh auth (or notify.sh auth --clear if the topic needs none)" ;;
    *) die "push rejected by $SERVER - check network and \$NTFY_SERVER" ;;
  esac
  # the relay needs a moment before a message is pollable
  local i found=0
  for i in 1 2 3 4 5; do
    sleep 2
    auth_args
    if curl -fsS --max-time 10 ${AUTH[@]+"${AUTH[@]}"} "$SERVER/$topic/json?poll=1" 2>/dev/null | grep -q "$stamp"; then
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
  if [ -n "${NTFY_SERVER:-}" ]; then printf 'server:  %s (from $NTFY_SERVER)\n' "$SERVER"
  elif [ -r "$SERVER_FILE" ];   then printf 'server:  %s (%s)\n' "$SERVER" "$SERVER_FILE"
  else                               printf 'server:  %s (default)\n' "$SERVER"; fi
  printf 'auth:    %s\n' "$(auth_kind)"
  if [ -n "${CLAUDE_NOTIFY_SILENT:-}" ]; then
    printf 'sound:   muted (CLAUDE_NOTIFY_SILENT set)\n'
  elif [ -r "$SOUND" ]; then
    printf 'sound:   %s\n' "$SOUND"
  else
    printf 'sound:   %s (unreadable - falls back to terminal bell)\n' "$SOUND"
  fi
  local ev
  for ev in Stop Notification PermissionRequest; do
    if [ -r "$SETTINGS" ] && jq -e --arg e "$ev" \
         '[.hooks[$e][]?.hooks[]?.command? // empty] | any(test("notify\\.sh"))' \
         "$SETTINGS" >/dev/null 2>&1; then
      printf 'hook %-19s wired\n' "$ev:"
    else
      printf 'hook %-19s not installed\n' "$ev:"
    fi
  done
}

case "${1:-}" in
  stop|input|permission) cmd_hook "$1" ;;
  push)       shift; cmd_push "$@" ;;
  init)       shift; cmd_init "${1:-}" ;;
  auth)       shift; cmd_auth "${1:-}" ;;
  setup)      cmd_setup ;;
  test)       cmd_test ;;
  status)     cmd_status ;;
  *)          die "usage: notify.sh {setup|stop|input|permission|push <msg>|init [--force]|auth [--clear]|test|status}" ;;
esac
