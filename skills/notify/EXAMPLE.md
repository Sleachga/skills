# A worked setup

A real run of `/notify setup`, start to finish, so you know what the skill does
before you point it at a public relay. Every local command below is verbatim
output. The network leg is shown as the exact request the script builds — see
[What actually leaves your machine](#what-actually-leaves-your-machine).

The whole thing takes about two minutes, most of it on your phone.

## 1. Claude picks a topic

```
$ skills/notify/scripts/notify.sh init
topic: claude-code-fa9aednfjlzmomsyvb56
subscribe to this in the ntfy app (server: https://ntfy.sh)
```

That string is the whole security model — see [Why the topic is the
secret](#why-the-topic-is-the-secret). It is written to `~/.claude/ntfy-topic`
with mode 600 and reused forever. Running `init` again prints the existing
topic and changes nothing; `init --force` rotates it.

## 2. You install the phone app

Install **ntfy** from the Play Store or App Store. Free, no account, no signup.

## 3. You subscribe

In the app: **+** → paste `claude-code-fa9aednfjlzmomsyvb56` → Subscribe.
Leave the server as `ntfy.sh`.

Do this before the test push. A push to a topic nobody is subscribed to looks
exactly like a broken setup.

## 4. Your watch, if you have one

Galaxy or Wear OS: Galaxy Wearable → Notifications → confirm ntfy is enabled.
Apple Watch: Watch app → Notifications → ntfy → Mirror iPhone.

## 5. Claude installs the hooks

```
$ skills/notify/scripts/install-hooks.sh
hook script: ~/.claude/hooks/notify.sh
settings:    ~/.claude/settings.json (backup: ~/.claude/settings.json.bak-20260914T120000)
wired:       Stop -> notify.sh stop, Notification -> notify.sh input
restart Claude Code for the hooks to take effect in this session.
```

It copies the script to a stable path and points the hooks there, so a plugin
update that moves the cache cannot break them. What lands in
`~/.claude/settings.json`:

```json
{
  "Stop": [
    { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh stop",  "async": true, "timeout": 15 }] }
  ],
  "Notification": [
    { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh input", "async": true, "timeout": 15 }] }
  ]
}
```

Re-running the installer is safe — it strips its own old entries first, so you
get one copy however many times you run it, and hooks you added yourself on
those events are left alone.

## 6. Verify

```
$ skills/notify/scripts/notify.sh status
topic:   claude-code-fa9aednfjlzmomsyvb56
server:  https://ntfy.sh
sound:   /System/Library/Sounds/Glass.aiff
hook Stop:         wired
hook Notification: wired

$ skills/notify/scripts/notify.sh test
server accepted the push (probe-1789411299, confirmed after 2s)
now confirm it actually buzzed the phone and watch.
```

`test` pushes a probe and then polls the relay to confirm it was accepted.
That proves the server took it — **not** that your phone rang. The last hop is
the one that breaks, which is why the skill asks you out loud.

Then restart Claude Code, or the hooks stay dormant for the rest of the session.

## What it looks like in use

Three things push, each with its own tone and priority:

| Trigger | Title | Body | Priority |
| --- | --- | --- | --- |
| Turn finished (`Stop` hook) | `Claude Code - checkout-service` | `Turn finished` | 3 |
| Input needed (`Notification` hook) | `Claude Code - checkout-service` | `Claude needs your permission to use Bash` | 4 (buzzes harder) |
| `/notify <message>` | `Claude Code - checkout-service` | your text | 3 |

The title is the basename of the working directory, so two projects running at
once are distinguishable on a watch face at a glance.

## What actually leaves your machine

This is the part worth reading twice, because ntfy.sh is a third party.

One HTTPS POST per notification, nothing else. No telemetry, no session
contents, no phoning home. Captured verbatim from a real `Stop` hook firing in
`/Users/sanford/dev/checkout-service`:

```http
POST /claude-code-fa9aednfjlzmomsyvb56 HTTP/1.1
Host: ntfy.sh
Title: Claude Code - checkout-service
Tags: white_check_mark
Priority: 3

Turn finished
```

And a manual push:

```http
POST /claude-code-fa9aednfjlzmomsyvb56 HTTP/1.1
Host: ntfy.sh
Title: Claude Code - checkout-service
Tags: speech_balloon
Priority: 3

Migration done, 3 tests still failing
```

So a third party learns three things: your project's directory name, when you
are working, and whatever status line Claude writes. The skill instructs Claude
to push status only — never file contents, credentials, or output. That is an
instruction to a model, not an enforced boundary, so treat the project name and
the timing as genuinely public.

The `Notification` hook forwards Claude Code's own message, which names the
tool it wants to use (`Claude needs your permission to use Bash`). Harmless in
practice, but it is your project's shape leaking one word at a time.

## Why the topic is the secret

On the free tier there is no auth. Anyone who types your topic into the ntfy
app receives everything you push to it, forever, and anyone can push *to* it —
so a leaked topic means fake notifications too. The 20 random characters are
the entire defense.

If it leaks: `notify.sh init --force`, then resubscribe on the phone. If that
model is not good enough for your work, self-host ntfy and set
`NTFY_SERVER=https://ntfy.example.com`, or pay for ntfy's access control.

## Turning it off

```
$ skills/notify/scripts/install-hooks.sh --remove
removed notify.sh from Stop and Notification in ~/.claude/settings.json
backup:  ~/.claude/settings.json.bak-20260914T120000
the script itself is still at ~/.claude/hooks/notify.sh - delete it if you want it gone.
```

Hooks you added yourself on those events survive. To keep the local ding but
stop pushing to the relay entirely, delete `~/.claude/ntfy-topic` instead — the
sound is local and needs no network.

## When it does not work

| Symptom | Cause |
| --- | --- |
| `no topic configured - run: notify.sh init` | No topic file, or an empty one |
| `push failed - check network and $NTFY_SERVER` | Topic is fine; the relay was unreachable |
| `test` passes, phone silent | Subscribed to a different topic, or phone notifications are muted for ntfy |
| Nothing fires after a turn | Hooks installed but Claude Code was not restarted |
| Silent, but pushes arrive | `CLAUDE_NOTIFY_SILENT` is set, or the sound file is unreadable |

A push failure never blocks or fails a turn — the hooks exit 0 regardless, by
design. If the relay is down you lose notifications, not work.
