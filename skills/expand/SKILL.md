---
name: expand
description: >
  Expand the previous answer to full detail. The companion to /concise —
  used when a concise answer was too thin. Takes an optional subject to
  expand just one part. Use when the user invokes /expand, or says
  "expand that", "more detail on X", "unpack that".
disable-model-invocation: true
---

Re-answer the **immediately preceding response** at full detail.

## Scope

| Invocation | Expand |
| --- | --- |
| `/expand` (bare) | The whole previous answer |
| `/expand <subject>` | Only the part matching `<subject>` — the rest stays collapsed |

`/expand 221` or `/expand the storybook fix` means that bullet and nothing else.
Do not re-expand everything around it.

## Where the detail comes from

**First, from context already gathered.** A concise answer is a compression of work
already done, so the detail almost always exists in the transcript — the tool output,
the file contents, the reasoning behind the recommendation. Recover it from there.

Run new tools only when the requested detail was genuinely never collected. Say so
plainly when that happens, rather than implying it was known all along.

## Restore what concise dropped

Whichever of these are real for this answer:

- The reasoning — why this conclusion and not the obvious alternative
- The evidence, quoted: tool output, log lines, file contents, `path:line`
- The alternatives considered, and what ruled each out
- Assumptions the concise answer relied on silently
- Caveats, edge cases, and what would change the recommendation
- Follow-on consequences and what to watch

Skip any that would be padding. Length is not the goal — the goal is that nothing
load-bearing is left implicit.

## Formatting

Normal formatting, not concise formatting. Prose where prose is clearer, headings
where the answer has parts, tables where there are 3+ comparable items. The bullet
ceiling and the one-line-per-bullet rule are lifted for this turn.

## Mode interaction

- `/expand` is a **one-turn override**. It does not change concise mode's state.
- If concise mode was on, it is still on. The turn after this one is concise again.
- Do not print a mode-change confirmation — nothing changed.
- If concise mode was already off, just answer in more depth than last time.

## Do not

- Do not invoke by yourself. User-invoked only.
- Do not restate the concise answer and stop. Expansion means new information,
  not the same content spaced out.
- Do not pad to look thorough. If the previous answer really was complete, say which
  part was already the whole story and expand only what genuinely has more behind it.
