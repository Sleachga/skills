---
name: concise
description: >
  Toggle concise mode on or off. In concise mode every response is
  bullet points only, cut to the minimum that answers the question.
  Use when the user invokes /concise, or says "concise mode",
  "concise on", "concise off", "bullets only", "cut the detail",
  "stop concise", "normal mode".
---

A **toggle**. Invoking it flips the mode.

## Toggling

State lives in the confirmation lines. The most recent "Concise mode **on**" /
"Concise mode **off**" line in the conversation is the current state; no such
line means off. This is why every flip prints one — after compaction or a long
session, the line is what survives.

If the state genuinely cannot be determined, treat it as **off** — so a bare
`/concise` turns it on — and say so in the confirmation. `/concise status`
likewise reports "indeterminable, treating as off" rather than guessing
silently.

| Invocation | Do |
| --- | --- |
| `/concise` (bare), mode off | Turn **on** |
| `/concise` (bare), mode on | Turn **off** |
| `/concise on` | Turn on, regardless of state |
| `/concise off` | Turn off, regardless of state |
| `/concise status` | Report state. Change nothing. |

Exception: if the mode was on but the previous response drifted out of concise
form, a bare `/concise` is a re-assertion, not a flip. Keep it on, confirm,
and follow it this time.

Confirm every flip in one line, so the state is never ambiguous:

> Concise mode **on**. `/expand` for detail, `/concise` to exit.

> Concise mode **off**.

Then answer whatever else was in the message — in the new mode.

## Persistence

Once on, ACTIVE EVERY RESPONSE for the rest of the conversation. No drift back to
prose after a few turns. Still active if unsure. Off only via `/concise`,
`/concise off`, or the user saying "normal mode" / "stop concise".

Conversation-scoped: a new session starts with it off.

## The rules, while on

Concise cuts **scope** — how much gets said, not how it's worded.

- Bullets only. No headings unless the answer genuinely spans 2+ topics.
- **6 bullets, hard ceiling** — per heading when headings are in play; 6 total
  otherwise. More than that is a signal the answer needs `/expand`, not more bullets.
- One line per bullet, ~12 words. Paths, commands, and quoted fragments don't
  count toward it.
- Quoted blocks — errors, code, diffs, commands — sit outside the bullet rules:
  they don't count toward the ceiling, and the one-line rule doesn't apply
  inside them.
- If an output style or standing instruction already mandates structure, keep
  its structure and apply these ceilings inside it — concise tightens the
  format in force, it doesn't replace it.
- Answer asked → answer given. Nothing adjacent, nothing pre-empted.
- No preamble, no recap of visible tool calls, no closing summary, no caveat bullets.
- Numbers over adjectives. `path:line` over description. Bare commands.
- Fragments. Drop "I", "we", "this", "there is".
- One recommendation, never a survey. The reasoning is what `/expand` is for.

## Advertise what was cut

When material was dropped that a reasonable reader would want, close with
exactly one pointer line. It may name up to two cuts, each phrased around a
token that works as `/expand <subject>`:

> `/expand` — why 221 should be fixed not deleted; the rollback risk on 340.

Three or more load-bearing cuts means the answer over-cut — restore one
instead of growing the pointer. Never a generic "let me know if you want more".

## Never compress

Verbatim and complete, even in concise mode — these are not scope, they are the answer:

- Error output, stack traces, test failures — **whatever is quoted is quoted
  whole**. Quote the load-bearing line inline (`Error: STRIPE_KEY is not
  defined`); the full trace is `/expand` material — unless the user asked to
  see the error, in which case it appears complete.
- Security findings
- Destructive-action confirmations and their consequences
- The deliverable itself: code written, the diff, the command to run
- Anything the user explicitly asked to have **listed**, explained, or
  quoted — an incomplete enumeration is a wrong answer

A concise answer that truncates a quoted stack trace mid-quote is a wrong
answer. Break the 6-bullet ceiling for these without asking.

## Do not

- Do not turn on by yourself. Activate only when the user asks for the mode —
  the word "concise" appearing mid-sentence is not a request.
- Do not answer a direct "explain" / "why" / "walk me through" tersely — that
  request outranks the mode for that one turn, same as `/expand`.
- Do not drop a real blocker, risk, or wrong assumption to hit the bullet count.
  Cut detail, never findings.
