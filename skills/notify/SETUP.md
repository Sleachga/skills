# Setup

[EXAMPLE.md](EXAMPLE.md) is a complete worked run with real output, plus
exactly what data reaches ntfy.sh. Read it if the user asks what the setup
looks like, what gets sent, or whether it is safe.

## Hand them the script

Setup is one command, and **the user should run it themselves in their own
terminal**:

```bash
${CLAUDE_SKILL_DIR}/scripts/notify.sh setup
```

That is not ceremony. The script prompts for the ntfy access token with echo
off and reads it from stdin, so a token never has to travel through a
conversation, a tool call, or a transcript. If you run setup on their behalf,
that prompt is the one thing you cannot do for them.

It is safe to re-run: an existing topic is kept, hooks are de-duplicated, and
nothing is sent without asking.

## What it does

| Step | Action |
| --- | --- |
| 1 | Creates or reuses the ntfy topic, and prints it for the phone |
| 2 | Asks which relay: public, ntfy Pro with a token, or self-hosted |
| 3 | Installs the `Stop`, `Notification` and `PermissionRequest` hooks |
| 4 | Prints the resulting configuration |
| 5 | Offers a test push, after asking |

Then it lists what is left, which is all on their phone.

## If you run it yourself

You can. It detects that it has no terminal and adapts: it creates the topic,
installs the hooks, prints the configuration, and **skips both the token prompt
and the test push** rather than pretending. It then tells the user which two
commands to run themselves.

That is the right division. Everything except credentials and consenting to an
outbound push is yours to do; those two are theirs.

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
