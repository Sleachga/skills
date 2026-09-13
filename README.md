# Skills

My Claude Code skills, installable as a plugin.

## Skills

- **/trio** — fan out three parallel subagents on one task (mixed models,
  independent takes), then synthesize their results.
- **/expand** — re-answer the previous response in full detail; takes an
  optional subject to expand just one part.
- **/concise** — toggle concise mode: every answer bullets-only at maximum
  density, until turned off.

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

## License

MIT
