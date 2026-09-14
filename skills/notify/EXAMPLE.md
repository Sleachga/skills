# A worked setup

A real run of `/notify setup`, start to finish, so you know what the skill does
before you point it at a public relay. Every local command below is verbatim
output. The network leg is shown as the exact request the script builds — see
[What actually leaves your machine](#what-actually-leaves-your-machine).

The whole thing takes about two minutes, most of it on your phone.

In practice you run one command and it walks the steps below for you:

```
$ skills/notify/scripts/notify.sh setup
```

Run it yourself rather than having Claude run it. It prompts for the access
token with echo off, which is the one step that cannot be delegated without the
token landing in a transcript. The individual commands are shown below so you
can see what it is doing, and they all work standalone.

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

## 2. Credentials, if the relay wants them

Claude asks which relay you are on before going further, because it decides
what the topic name is worth.

On the free `ntfy.sh` tier there is nothing to configure and nothing protecting
you but the topic string. On ntfy Pro or your own server, you run this
yourself, in your own terminal:

```
$ skills/notify/scripts/notify.sh auth
paste the ntfy access token, then press enter (input hidden):
token saved to ~/.claude/ntfy-token (mode 600)
verify with: notify.sh test
```

The token is read from stdin with echo off, so it never appears in your shell
history, in a process listing, or in the conversation with Claude. It is not
printed back here and `status` will not print it either. Claude is instructed
never to take it into the chat at all.

Every push then carries `Authorization: Bearer tk_…`, and a relay that rejects
it produces a distinct error rather than a misleading network one:

```
$ skills/notify/scripts/notify.sh push "hi"
relay rejected the credentials - run: notify.sh auth
```

`notify.sh auth --clear` goes back to an unauthenticated topic.

## 3. You install the phone app

Install **ntfy** from the Play Store or App Store. Free, no account, no signup.

## 4. You subscribe

In the app: **+** → paste `claude-code-fa9aednfjlzmomsyvb56` → Subscribe.
Leave the server as `ntfy.sh`.

Do this before the test push. A push to a topic nobody is subscribed to looks
exactly like a broken setup.

## 5. Your watch, if you have one

Galaxy or Wear OS: Galaxy Wearable → Notifications → confirm ntfy is enabled.
Apple Watch: Watch app → Notifications → ntfy → Mirror iPhone.

## 6. Claude installs the hooks

```
$ skills/notify/scripts/install-hooks.sh
hook script: ~/.claude/hooks/notify.sh
settings:    ~/.claude/settings.json (backup: ~/.claude/settings.json.bak-20260914T120000)
wired:       Stop -> stop, Notification -> input, PermissionRequest -> permission
restart Claude Code for the hooks to take effect in this session.
```

It copies the script to a stable path and points the hooks there, so a plugin
update that moves the cache cannot break them. What lands in
`~/.claude/settings.json`:

```json
{
  "Stop": [
    { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh stop",       "async": true, "timeout": 15 }] }
  ],
  "Notification": [
    { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh input",      "async": true, "timeout": 15 }] }
  ],
  "PermissionRequest": [
    { "hooks": [{ "type": "command", "command": "~/.claude/hooks/notify.sh permission", "async": true, "timeout": 15 }] }
  ]
}
```

`async: true` matters on `PermissionRequest`: the push must not sit in front of
the approval prompt you are being notified about.

Re-running the installer is safe — it strips its own old entries first, so you
get one copy however many times you run it, and hooks you added yourself on
those events are left alone.

## 7. Verify

```
$ skills/notify/scripts/notify.sh status
topic:   claude-code-fa9aednfjlzmomsyvb56
server:  https://ntfy.sh
auth:    token (~/.claude/ntfy-token)
sound:   /System/Library/Sounds/Glass.aiff
hook Stop:               wired
hook Notification:       wired
hook PermissionRequest:  wired

$ skills/notify/scripts/notify.sh test
server accepted the push (probe-1789411299, confirmed after 2s)
now confirm it actually buzzed the phone and watch.
```

`test` pushes a probe and then polls the relay to confirm it was accepted.
That proves the server took it — **not** that your phone rang. The last hop is
the one that breaks, which is why the skill asks you out loud.

Then restart Claude Code, or the hooks stay dormant for the rest of the session.

## What it looks like in use

Four things push, each with its own tone and priority:

| Trigger | Body | Priority |
| --- | --- | --- |
| Blocked on approval (`PermissionRequest`) | `Bash: rm -rf node_modules && npm ci` | 4 |
| Claude Code notification (`Notification`) | the message it raised | 4 |
| Turn finished (`Stop`) | `Turn finished` | 3 |
| `/notify <message>` | your text | 3 |

The title on all four is `Claude Code - <directory name>`, so two projects
running at once are distinguishable on a watch face at a glance.

The approval push is the useful one when you are away from the desk. It names
the tool and what it wants to do, which is the difference between walking back
and not. Where the tool has nothing to show — a Skill invocation, say — it
degrades to `Skill needs approval`. Long commands are clamped to 110
characters so the watch shows the start rather than the OS truncating it
somewhere arbitrary.

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

The one that fires when Claude is blocked waiting on you:

```http
POST /claude-code-fa9aednfjlzmomsyvb56 HTTP/1.1
Host: ntfy.sh
Title: Claude Code - checkout-service
Tags: lock
Priority: 4

Bash: rm -rf node_modules && npm ci
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

Note what the approval push implies for privacy: it sends the **command line
Claude wanted to run**, which is more than a status line. A command containing
a hostname, a path, or a token would put that on a public relay. This is the
one push that can carry something you would not choose to publish, so if that
matters, self-host the relay.

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
removed notify.sh from Stop, Notification and PermissionRequest in ~/.claude/settings.json
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
| `relay rejected the credentials` | The server wants a token, or the stored one is wrong or expired |
| `test` passes, phone silent | Subscribed to a different topic, or phone notifications are muted for ntfy |
| Nothing fires after a turn | Hooks installed but Claude Code was not restarted |
| Turn-finished pings but approval never does | Only `Stop` is wired; re-run the installer to add `PermissionRequest` |
| Silent, but pushes arrive | `CLAUDE_NOTIFY_SILENT` is set, or the sound file is unreadable |

A push failure never blocks or fails a turn — the hooks exit 0 regardless, by
design. If the relay is down you lose notifications, not work.
