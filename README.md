# Skills

My Claude Code skills, installable as a plugin.

## Skills

- **/fanout** — fan out N independent agents on one task, then synthesize what
  they found. `/fanout 5 <task>` to pick N yourself, otherwise it sizes N to
  how wide the question is.
- **/trio** — pair program with three agents: a driver that writes the code,
  a navigator that reviews everything it did and corrects it, and a tester
  that writes tests without seeing the implementation.
  `skills/trio/EXAMPLE.md` is a worked run.
- **/expand** — re-answer the previous response in full detail; takes an
  optional subject to expand just one part.
- **/concise** — toggle concise mode: every answer bullets-only at maximum
  density, until turned off.
- **/notify** — push a line to your phone and watch via ntfy, plus hooks that
  buzz you when Claude is blocked waiting on approval, naming the tool it wants
  to run. `/notify setup` walks you through it.

## Installation

Inside Claude Code:

```
/plugin marketplace add sleachga/skills
/plugin install sleachga-skills@sleachga
```

## Layout

```
.claude-plugin/   plugin + marketplace manifests
skills/<name>/    one SKILL.md per skill, plus scripts/ where it needs them
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
