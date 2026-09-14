# Setup

[EXAMPLE.md](EXAMPLE.md) is a complete worked run of these steps with real
output, plus exactly what data reaches ntfy.sh. Read it if the user asks what
the setup looks like, what gets sent, or whether it is safe.

Walk the user through this. One step at a time — stop and confirm each before
moving on. Steps 2 and 3 happen on their phone; you cannot verify them, so ask.

## 1. Pick a topic

```bash
scripts/notify.sh init
```

Generates a 20-char random topic, writes `~/.claude/ntfy-topic` (mode 600),
prints it. Already configured? It prints the existing topic and changes
nothing — pass `--force` to rotate.

**Show the user the topic string.** They need to type it on their phone.

## 2. Install the phone app

Tell them: install **ntfy** from the Play Store (Android) or App Store (iOS).
Free, no account.

## 3. Subscribe

In the ntfy app: **+** → paste the topic → Subscribe. Leave the server as the
default `ntfy.sh` unless `NTFY_SERVER` is set to a self-hosted instance.

Wait for them to confirm they've subscribed before step 4. A test push to an
unsubscribed topic looks identical to a broken setup.

## 4. Watch mirroring

- **Galaxy Watch / Wear OS** — Galaxy Wearable app → Notifications → confirm
  ntfy is enabled. Mirroring is on by default; the app list is per-app.
- **Apple Watch** — Watch app → Notifications → ntfy → Mirror iPhone.

Skip this step if they have no watch.

## 5. Install the hooks

```bash
scripts/install-hooks.sh
```

Adds `Stop` (turn finished) and `Notification` (input needed) to
`~/.claude/settings.json`. Report the two paths it prints.

## 6. Verify end to end

```bash
scripts/notify.sh test
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

macOS sounds live in `/System/Library/Sounds` — `Glass` (default), `Hero`,
`Submarine`, `Sosumi`, `Ping`. Elsewhere, an unreadable sound file degrades to
the terminal bell.

## Privacy

`ntfy.sh` is a public relay. Anyone who knows the topic name can read
everything pushed to it, and there is no auth on the free tier. The random
topic name is the only thing protecting it. Push status lines, never content.
Self-host or use ntfy's paid access control if that isn't good enough.
