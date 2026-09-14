# Setup

[EXAMPLE.md](EXAMPLE.md) is a complete worked run with real output, plus
exactly what data reaches ntfy.sh. Read it if the user asks what the setup
looks like, what gets sent, or whether it is safe.

## Run it

Run this yourself. Don't paste instructions and make the user do it:

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh setup
```

It creates or reuses the topic, installs the three hooks, and prints the
resulting configuration. It is safe to re-run: an existing topic is kept and
hooks are de-duplicated.

Because you are not a terminal, it will skip two steps rather than pretend —
and those two are genuinely the user's:

| Skipped | Why | What you say |
| --- | --- | --- |
| The access token | Typed with echo off in their shell. A token that reaches you is a token in a transcript. | Give them the one command, below |
| The test push | Sends a message to a third party, and is pointless before they have subscribed | Tell them to run it once subscribed |

Hooks and the topic live in `~/.claude/`, not in the project, so this is a
once-per-machine job. Setting it up from any repo covers every repo.

## Then hand back exactly three things

Report these and stop. Do not attempt them yourself.

1. **The topic**, printed verbatim, so they can subscribe in the ntfy app.
   Install ntfy from the Play Store or App Store, **+**, paste, Subscribe.
2. **The token**, only if they are on ntfy Pro or a self-hosted relay with
   access control. Ask which relay first — see [Credentials in
   SKILL.md](SKILL.md#credentials). If they need one:

   ```bash
   ${CLAUDE_SKILL_DIR}/scripts/notify.sh auth
   ```

3. **A restart of Claude Code**, or the hooks stay dormant for the session.

Then `notify.sh test` once they say they have subscribed, and ask out loud
whether the watch actually buzzed — the relay accepting a push is not proof it
arrived.

If they have a watch: Galaxy Wearable → Notifications → enable ntfy, or Watch
app → Notifications → ntfy → Mirror iPhone.

## If the user would rather drive

They can run `notify.sh setup` themselves in a terminal, which is the same flow
plus the interactive relay question and the token prompt. Suggest it when they
are on ntfy Pro anyway, since it saves a round trip.

## Talking them through it

Stop and confirm at each of these, because you cannot verify any of them:

- **The relay choice.** On the free tier there are no accounts, so the topic
  name is the only protection — and the approval notification carries the
  command line Claude wants to run. Say that plainly before they pick.
- **ntfy Pro is not private by default.** A token authenticates, but ntfy.sh
  topics stay world-readable unless the topic is *reserved* under their
  account. Tell them to reserve it and restrict it, or they get authentication
  without privacy.
- **Subscribing on the phone**, before the test push. A push to a topic nobody
  is subscribed to looks identical to a broken setup.
- **Whether it actually buzzed.** `test` proves the relay accepted the message,
  not that the watch lit up. Ask out loud.
- **Restarting Claude Code**, or the hooks stay dormant for the session.

## Tuning

| Want | Do |
| --- | --- |
| Different sound | `export CLAUDE_NOTIFY_SOUND=/System/Library/Sounds/Hero.aiff` |
| Silence local sound, keep the buzz | `export CLAUDE_NOTIFY_SILENT=1` |
| Keep the ding, kill the push | `rm ~/.claude/ntfy-topic` |
| Self-hosted relay | setup step 2 stores it, or `export NTFY_SERVER=...` |
| Basic auth instead of a token | `NTFY_USER` and `NTFY_PASSWORD` |
| Rotate a leaked topic | `notify.sh init --force`, then resubscribe on the phone |
| Add or replace a token | `notify.sh auth` (the user runs it, not you) |
| Drop the token | `notify.sh auth --clear` |
| Remove the hooks | `install-hooks.sh --remove` |

macOS sounds live in `/System/Library/Sounds` — `Glass` (default), `Hero`,
`Submarine`, `Sosumi`, `Ping`. Elsewhere, an unreadable sound file degrades to
the terminal bell.

## Privacy

`ntfy.sh` is a public relay. On the free tier there is no auth: anyone who
knows the topic name reads everything pushed to it, forever, and can push to it
too. The random topic name is the only thing protecting it.

Weigh that against what the hooks actually send. The approval push carries the
command Claude wants to run, so a command naming an internal hostname or a path
puts that on a public relay. If that is not acceptable, the answer is a
reserved topic plus a token, or a self-hosted server — not a promise to be
careful.

The token lives in `~/.claude/ntfy-token` at mode 600 and is never printed, not
by `auth`, not by `setup`, not by `status`. Keep it out of the conversation.
