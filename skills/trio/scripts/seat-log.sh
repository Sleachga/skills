#!/usr/bin/env bash
# seat-log.sh — distill a subagent's transcript into a reviewable activity log.
#
#   seat-log.sh <transcript.jsonl> [--output-lines N] [--commands-only]
#
# The Agent tool hands back an `output_file` path for every seat it spawns:
# the seat's full JSONL transcript. Reading that raw costs more context than
# the work itself, so this pulls out the part a reviewer actually needs —
# every command the seat ran, whether it failed, and what it printed.
#
# File edits are reported as paths only. What the code *became* belongs in the
# diff, which is ground truth; what matters here is what the seat *did*.
#
#   --output-lines N   lines of output to keep per command (default 12, 0 = none)
#   --commands-only    drop Read/Grep/Glob noise, keep commands and edits

set -uo pipefail

FILE="${1:-}"
OUT_LINES=12
COMMANDS_ONLY=0
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --output-lines) OUT_LINES="${2:-12}"; shift 2 ;;
    --commands-only) COMMANDS_ONLY=1; shift ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$FILE" ] || { printf 'usage: seat-log.sh <transcript.jsonl> [--output-lines N] [--commands-only]\n' >&2; exit 2; }
[ -r "$FILE" ] || { printf 'cannot read transcript: %s\n' "$FILE" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'jq is required\n' >&2; exit 1; }

case "$OUT_LINES" in ''|*[!0-9]*) printf -- '--output-lines needs a number\n' >&2; exit 2 ;; esac

jq -rs --argjson keep "$OUT_LINES" --argjson terse "$COMMANDS_ONLY" '
  # tool_result content arrives as a plain string or as an array of blocks
  def text: if type == "string" then .
            elif type == "array" then ([.[]? | .text? // empty] | join("\n"))
            else (. // "" | tostring) end;

  def clip($n):
    (split("\n") | map(select(length > 0))) as $l
    | if $n == 0 then []
      elif ($l | length) <= $n then $l
      else ($l[0 : ($n / 2 | floor)]
            + ["… \(($l | length) - $n) more lines …"]
            + $l[-($n - ($n / 2 | floor)) :])
      end;

  # id -> result, so each call can be paired with what it returned
  (reduce (.[] | select(.type == "user") | .message.content[]?
           | select(.type == "tool_result")) as $r
     ({}; .[$r.tool_use_id] = { err: ($r.is_error == true), out: ($r.content | text) })
  ) as $res

  | [ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") ]
  | to_entries
  | map(
      .key as $i | .value as $t | ($res[$t.id] // { err: false, out: "" }) as $r
      | ($i + 1) as $n
      | if $t.name == "Bash" then
          "[\($n)] $ \($t.input.command // "«no command»")"
          + (if $r.err then "\n      ✗ FAILED" else "" end)
          + ( ($r.out | clip($keep)) | map("\n      | " + .) | join("") )
        elif ($t.name | IN("Edit", "Write", "NotebookEdit", "MultiEdit")) then
          "[\($n)] \($t.name) → \($t.input.file_path // $t.input.notebook_path // "?")"
          + (if $r.err then "  ✗ FAILED" else "" end)
        elif ($t.name | IN("Read", "Grep", "Glob")) then
          if $terse == 1 then empty
          else "[\($n)] \($t.name) \($t.input.file_path // $t.input.pattern // $t.input.path // "")" end
        else
          # unknown tool: show the most identifying value, not the key names
          (($t.input // {}) | (.url // .query // .description // .prompt // .pattern
                               // .file_path // .path // (keys | join(","))) | tostring) as $what
          | "[\($n)] \($t.name) \(if ($what | length) > 100 then ($what[0:100] + "…") else $what end)"
          + (if $r.err then "  ✗ FAILED" else "" end)
        end
    )
  | if length == 0 then "(the seat ran no tools)" else join("\n") end
' "$FILE"

# a tally makes an unusual run obvious at a glance — 40 Reads and one Edit is a
# seat that spent its turn lost, and that is worth seeing before the diff
printf '\n--- %s ---\n' "$(basename "$FILE")"
jq -rs '
  [ .[] | select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name ]
  | if length == 0 then "no tool calls"
    else (group_by(.) | map("\(.[0])×\(length)") | join("  ")) end
' "$FILE"
