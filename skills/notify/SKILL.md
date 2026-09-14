---
name: notify
description: >
  Push a notification to the user's phone and smartwatch via ntfy, and install
  or repair the Claude Code hooks that ding when a turn finishes or input is
  needed. Use when the user invokes /notify, or says "notify me", "buzz my
  watch", "ping my phone", "ding when done", "set up notifications".
disable-model-invocation: true
---

Two halves. **Hooks** fire automatically — turn finished, input needed.
**`/notify`** is the manual push, for anything the hooks don't cover.

## Dispatch

| Invocation | Do |
| --- | --- |
| `/notify` (bare) | Push a one-line summary of what just happened in this turn |
| `/notify <message>` | Push that text verbatim |
| `/notify setup` | First-time setup — see [SETUP.md](SETUP.md); [EXAMPLE.md](EXAMPLE.md) is a full worked run |
| `/notify test` | Push a test, then confirm arrival via the ntfy poll API |
| `/notify status` | Report topic, hook state, sound. Change nothing. |
| `/notify off` | Remove the hooks and the topic file |

Never guess at setup state. Run `scripts/notify.sh status` first — it prints
topic, server, sound, and whether each hook is wired.

## Sending

```bash
scripts/notify.sh push "Migration done, tests still running"
```

Exit 0 with no output means delivered. Non-zero means no topic configured —
route the user to `/notify setup`, don't retry.

Keep pushes to one line, under ~120 chars. It lands on a watch face.

## Installing the hooks

```bash
scripts/install-hooks.sh          # install or repair
scripts/install-hooks.sh --remove # /notify off
```

Idempotent: it strips any prior `notify.sh` entry from `Stop` and
`Notification` before adding its own, and leaves unrelated hooks on those
events alone. Backs up `~/.claude/settings.json` first.

Hooks are read from user settings — if they don't fire after install, the
session needs a restart. Say so; don't re-run the installer.

## Do not

- Do not invoke this yourself. The hooks already cover finished and blocked.
- Do not put file contents, secrets, credentials, or PII in a push. ntfy.sh
  topics are public to anyone who knows the topic name — the name is the only
  secret. Project name and status text only.
- Do not create a topic the user hasn't seen. `setup` prints it for them to
  subscribe to; a topic they never subscribed to pushes into the void.
