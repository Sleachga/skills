# Skills

My Claude Code skills, installable as a plugin.

## Skills

- **/trio** — fan out three parallel subagents on one task (mixed models,
  independent takes), then synthesize their results.
- **/expand** — re-deliver the previous answer in full detail.
- **/concise** — compress the previous answer to maximum information density.

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
