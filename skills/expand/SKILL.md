---
name: expand
description: >
  Expand the previous answer to full detail. The companion to /concise —
  used when a concise answer was too thin. Takes an optional subject to
  expand just one part. Use when the user invokes /expand, or says
  "expand that", "more detail on X", "unpack that".
---

Re-answer the **most recent substantive answer** at full detail — usually the
immediately preceding response. A mode-flip line like "Concise mode **on**."
is not an answer; expand the last substantive answer before it.

## Scope

| Invocation | Expand |
| --- | --- |
| `/expand` (bare) | The whole previous answer |
| `/expand <subject>` | Only the part matching `<subject>`. Answer with that part alone — do not reprint the rest of the previous answer |

`<subject>` is matched against the **content** of the previous answer — a
word, number, or phrase that appears in it. `/expand 221` means the bullet
that mentions 221 (an issue number, a `path:line`), not "bullet number 221" —
concise answers are not numbered.

If `<subject>` matches nothing in the previous answer, say so and name the
parts that are expandable. Do not expand the whole answer as a fallback, and
do not guess silently — if one part is the obvious near-match, offer it: "No
'221' in the last answer — did you mean the 224 migration bullet?"

A bare `/expand` right after a concise pointer line still expands the whole
answer — lead with the advertised item.

## Where the detail comes from

**First, from context already gathered.** A concise answer is a compression of
work already done, so the detail almost always exists in the transcript — the
tool output, the file contents, the reasoning behind the recommendation.
Recover it from there.

Run new tools only when the requested detail was genuinely never collected.
Say so plainly when that happens, rather than implying it was known all along.

If the transcript no longer contains the underlying work — context was
compacted, or the session was resumed — the detail is gone, not recoverable.
Re-run the tools to rebuild it, and say the answer was re-derived, not
remembered. Never reconstruct "evidence" from memory of a summary.

If there is no previous answer to expand (start of session), say so and ask
what to expand.

## Restore what concise dropped

Whichever of these are real for this answer:

- The reasoning — why this conclusion and not the obvious alternative
- The evidence, quoted: tool output, log lines, file contents, `path:line`
- The alternatives considered, and what ruled each out
- Assumptions the concise answer relied on silently
- Caveats, edge cases, and what would change the recommendation
- Follow-on consequences and what to watch
- For a work turn: what was actually changed and where, the verification that
  was run, and what was assumed rather than checked

Skip any that would be padding. Length is not the goal — the goal is that
nothing load-bearing is left implicit.

## Formatting

Normal formatting, not concise formatting. Prose where prose is clearer,
headings where the answer has parts, tables where there are 3+ comparable
items. The bullet ceiling and the one-line-per-bullet rule are lifted for this
turn.

## Mode interaction

- `/expand` is a **one-turn override**. It does not change concise mode's state.
- If concise mode was on, it is still on. The turn after this one is concise again.
- Do not print a mode-change confirmation — nothing changed.
- If concise mode was already off, just answer in more depth than last time.
- `/expand` after an expansion goes deeper on the expansion itself — the next
  level down: the raw tool output behind the quoted excerpt, the full file
  behind the `path:line`. If there is genuinely nothing deeper, say which
  parts were already at the bottom instead of re-spacing the same content.

## Do not

- Invoke only when the user asked — `/expand`, or words like "expand that" /
  "more detail on X". Never expand unprompted because an answer felt thin.
- Do not restate the concise answer and stop. Restating the conclusion
  *inside* the fuller answer is fine — the expansion should stand alone — but
  expansion means new information, not the same content spaced out.
- Do not pad to look thorough. If the previous answer really was complete, say
  which part was already the whole story and expand only what genuinely has
  more behind it.
