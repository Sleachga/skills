---
name: notify
description: >
  Push a notification to the user's phone and smartwatch via ntfy, and install
  or repair the Claude Code hooks that buzz when Claude is blocked waiting for
  approval, when a turn finishes, and when Claude Code raises a notification.
  Use when the user invokes /notify. Claude cannot invoke this itself, by
  design — the hooks already cover being blocked and being done, without the
  model in the loop, so there is nothing here to trigger on a phrase.
disable-model-invocation: true
---

Two halves. **Hooks** fire automatically — Claude is blocked on approval, a
turn finished, Claude Code raised a notification. **`/notify`** is the manual
push, for anything the hooks don't cover.

The hooks are the part that matters. They are fired by Claude Code itself, not
by the model, so they work whether or not anyone is at the keyboard and cost no
tokens. `PermissionRequest` is the one that carries the use case: it fires the
moment Claude is blocked waiting for approval, and it knows which tool is being
requested, so the push can say `Bash: rm -rf node_modules` rather than
"waiting for input".

## Dispatch

| Invocation | Do |
| --- | --- |
| `/notify` (bare) | Push a one-line summary of what just happened in this turn |
| `/notify <message>` | Push that text verbatim |
| `/notify setup` | First-time setup — see [SETUP.md](SETUP.md); [EXAMPLE.md](EXAMPLE.md) is a full worked run |
| `/notify test` | Push a test, then confirm arrival via the ntfy poll API |
| `/notify auth` | Store an ntfy access token — see [Credentials](#credentials) |
| `/notify status` | Report topic, auth, hook state, sound. Change nothing. |
| `/notify off` | Remove the hooks and the topic file |

Never guess at setup state. Run `notify.sh status` first — it prints topic,
server, sound, and whether each hook is wired. Every script lives in
`${CLAUDE_SKILL_DIR}/scripts/`; the working directory is the user's project,
not the skill, so a bare relative path will not find them.

## Sending

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh push "Migration done, tests still running"
```

Exit 0 with no output means delivered. Both failures are non-zero but mean
different things, and the message says which: `no topic configured` means setup
never ran — route the user to `/notify setup`. `push failed` means the topic is
fine and the relay was unreachable — say so once and move on, don't retry.

Keep pushes to one line, under ~120 chars. It lands on a watch face.

## Credentials

On the public `ntfy.sh` free tier there is no auth at all: the topic name is
the only thing protecting it. That was a defensible trade when the pushes said
"Turn finished". It is a worse one now that the approval push carries the
command line Claude wants to run.

So ask, during setup, which of these the user is on:

| Relay | Credentials |
| --- | --- |
| Public `ntfy.sh`, free | None. The random topic is the whole secret. |
| ntfy Pro, or self-hosted with access control | An access token, `tk_…` |
| Self-hosted with basic auth | `NTFY_USER` and `NTFY_PASSWORD` in the environment |

**Never handle the token yourself.** Do not ask the user to paste it into the
chat, do not pass it as a command argument, and do not read it from a file to
echo back. Tell them to run this in their own terminal:

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh auth
```

It prompts, reads the token from stdin with echo off, and writes it to
`~/.claude/ntfy-token` at mode 600. A token pasted into the chat is a token in
a transcript, and in a process listing if it arrives as an argument. `auth`
never prints it back, and neither does `status`.

`notify.sh auth --clear` forgets it. `notify.sh status` reports only whether
credentials exist and of what kind.

A push rejected with 401 or 403 exits 3 and says the relay rejected the
credentials, which is a different fix from an unreachable relay — route it to
`/notify auth`, not to network debugging.

## Installing the hooks

```bash
${CLAUDE_SKILL_DIR}/scripts/install-hooks.sh          # install or repair
${CLAUDE_SKILL_DIR}/scripts/install-hooks.sh --remove # /notify off
```

Wires three events, each `async` so a push never delays a permission prompt or
holds up a turn:

| Event | Fires when | Push |
| --- | --- | --- |
| `PermissionRequest` | Claude is blocked waiting for approval | `Bash: rm -rf build`, priority 4 |
| `Notification` | Claude Code raises a notification, e.g. an auth failure | the message, priority 4 |
| `Stop` | the turn ended | `Turn finished`, priority 3 |

Idempotent: it strips any prior `notify.sh` entry from all three before adding
its own, and leaves unrelated hooks on those events alone. Backs up
`~/.claude/settings.json` first.

Hooks are read from user settings — if they don't fire after install, the
session needs a restart. Say so; don't re-run the installer.

## Do not

- Do not invoke this yourself. The hooks already cover blocked and finished,
  and they do it without the model in the loop.
- Do not put file contents, secrets, credentials, or PII in a push. On the free
  tier the topic name is the only secret, so treat anything pushed as public.
  Project name and status text only.
- Do not ever take the ntfy token into the conversation — not to store it, not
  to check it, not to repeat it back. The user runs `notify.sh auth` themselves.
- Do not create a topic the user hasn't seen. `setup` prints it for them to
  subscribe to; a topic they never subscribed to pushes into the void.
