# Skills

My Claude Code skills, installable as a plugin.

## Skills

- **/trio** — fan out three parallel subagents on one task (mixed models,
  independent takes), then synthesize their results.
- **/expand** — re-answer the previous response in full detail; takes an
  optional subject to expand just one part.
- **/concise** — toggle concise mode: every answer bullets-only at maximum
  density, until turned off.
- **/notify** — push a line to your phone and watch via ntfy, plus hooks that
  ding when a turn finishes or Claude needs input. `/notify setup` walks you
  through it.

## Installation

Inside Claude Code:

```
/plugin marketplace add sleachga/skills
/plugin install sleachga-skills@sleachga
```

## Layout

```
.claude-plugin/   plugin + marketplace manifests
skills/<name>/    one SKILL.md per skill
```

## Notifications

`/notify` shells out to `skills/notify/scripts/`. It needs `jq` and `curl`,
and the free [ntfy](https://ntfy.sh) app on your phone. Sound playback uses
`afplay` on macOS, `paplay`/`aplay` on Linux, and falls back to the terminal
bell. Topics on the public `ntfy.sh` relay are readable by anyone who knows
the topic name — push status lines, never content.

`skills/notify/EXAMPLE.md` is a worked setup run showing the exact HTTPS
request that reaches the relay.

## License

MIT
