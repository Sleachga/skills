# Setup

[EXAMPLE.md](EXAMPLE.md) is a complete worked run of these steps with real
output, plus exactly what data reaches ntfy.sh. Read it if the user asks what
the setup looks like, what gets sent, or whether it is safe.

Walk the user through this. One step at a time — stop and confirm each before
moving on. Steps 3 and 4 happen on their phone and step 2 may happen in their
own terminal; you cannot verify any of those, so ask.

## 1. Pick a topic

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh init
```

Generates a 20-char random topic, writes `~/.claude/ntfy-topic` (mode 600),
prints it. Already configured? It prints the existing topic and changes
nothing — pass `--force` to rotate.

**Show the user the topic string.** They need to type it on their phone.

## 2. Ask which relay, and whether it needs credentials

Ask before going further, because it changes what the topic is worth:

> The free `ntfy.sh` relay has no accounts — anyone who knows your topic name
> can read everything pushed to it. The approval notification includes the
> command Claude wants to run. Are you happy on the public relay, or do you
> have an ntfy Pro account or your own server?

**Public free relay** — nothing to do, continue to step 3. Say plainly that the
topic name is the only protection.

**ntfy Pro or self-hosted with access control** — they need an access token.
Do not take it into the chat. Ask them to run this in their own terminal:

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh auth
```

It prompts with echo off, reads from stdin, and writes `~/.claude/ntfy-token`
at mode 600. It never prints the token, and neither does `status`. For a
self-hosted server they also need `export NTFY_SERVER=https://ntfy.example.com`
in their shell profile, and for basic auth instead of a token, `NTFY_USER` and
`NTFY_PASSWORD`.

Confirm with `notify.sh status`, which reports the kind of credential without
revealing it.

## 3. Install the phone app

Tell them: install **ntfy** from the Play Store (Android) or App Store (iOS).
Free, no account.

## 4. Subscribe

In the ntfy app: **+** → paste the topic → Subscribe. Leave the server as the
default `ntfy.sh` unless `NTFY_SERVER` is set to a self-hosted instance.

Wait for them to confirm they've subscribed before the test push. A test push to an
unsubscribed topic looks identical to a broken setup.

## 5. Watch mirroring

- **Galaxy Watch / Wear OS** — Galaxy Wearable app → Notifications → confirm
  ntfy is enabled. Mirroring is on by default; the app list is per-app.
- **Apple Watch** — Watch app → Notifications → ntfy → Mirror iPhone.

Skip this step if they have no watch.

## 6. Install the hooks

```bash
${CLAUDE_SKILL_DIR}/scripts/install-hooks.sh
```

Adds three hooks to `~/.claude/settings.json`: `PermissionRequest` for when
Claude is blocked waiting on approval, `Notification` for Claude Code's own
notifications, and `Stop` for a finished turn. Report the paths it prints.

## 7. Verify end to end

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh test
```

Sends a push, then polls the ntfy API to confirm the server accepted it. A
green result proves server-side delivery only — **ask the user whether the
phone and watch actually buzzed.** That last hop is the one that breaks.

Then tell them: hooks need a Claude Code restart to take effect this session.

## Tuning

| Want | Do |
| --- | --- |
| Different sound | `export CLAUDE_NOTIFY_SOUND=/System/Library/Sounds/Hero.aiff` |
| Silence local sound, keep the buzz | `export CLAUDE_NOTIFY_SILENT=1` |
| Keep the ding, kill the push | `rm ~/.claude/ntfy-topic` |
| Self-hosted ntfy | `export NTFY_SERVER=https://ntfy.example.com` |
| Rotate a leaked topic | `notify.sh init --force`, then resubscribe on the phone |
| Add or replace a token | `notify.sh auth` (the user runs it, not you) |
| Drop the token | `notify.sh auth --clear` |

macOS sounds live in `/System/Library/Sounds` — `Glass` (default), `Hero`,
`Submarine`, `Sosumi`, `Ping`. Elsewhere, an unreadable sound file degrades to
the terminal bell.

## Privacy

`ntfy.sh` is a public relay. On the free tier there is no auth: anyone who
knows the topic name reads everything pushed to it, forever, and can push to it
too. The random topic name is the only thing protecting it.

Weigh that against what the hooks actually send. The approval push carries the
command Claude wants to run, so a command naming an internal hostname or a path
puts that on a public relay. If that is not acceptable, the answer is an access
token plus ntfy's access control, or a self-hosted server — not a promise to be
careful.

The token itself lives in `~/.claude/ntfy-token` at mode 600 and is never
printed, not by `auth` and not by `status`. Keep it out of the conversation.
