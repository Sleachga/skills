---
name: concise
description: >
  Toggle concise mode on or off. In concise mode every response is
  bullet points only, cut to the minimum that answers the question.
  Use when the user invokes /concise, or says "concise mode",
  "concise on", "concise off", "bullets only", "cut the detail".
disable-model-invocation: true
---

A **toggle**. Invoking it flips the mode.

## Toggling

Read the conversation to find the current state — whether `/concise` has already
been invoked and not since turned off.

| Invocation | Do |
| --- | --- |
| `/concise` (bare), mode off | Turn **on** |
| `/concise` (bare), mode on | Turn **off** |
| `/concise on` | Turn on, regardless of state |
| `/concise off` | Turn off, regardless of state |
| `/concise status` | Report state. Change nothing. |

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

Concise cuts **scope** — how much gets said. (Distinct from `/caveman`, which cuts
**grammar**. They compose; neither implies the other.)

- Bullets only. No headings unless the answer genuinely spans 2+ topics.
- **6 bullets, hard ceiling.** More than that is a signal the answer needs `/expand`, not more bullets.
- One line per bullet. ~12 words. If it wraps, cut it.
- Answer asked → answer given. Nothing adjacent, nothing pre-empted.
- No preamble, no recap of visible tool calls, no closing summary, no caveat bullets.
- Numbers over adjectives. `path:line` over description. Bare commands.
- Fragments. Drop "I", "we", "this", "there is".
- One recommendation, never a survey. The reasoning is what `/expand` is for.

## Advertise what was cut

When material was dropped that a reasonable reader would want, close with exactly one
pointer line naming it:

> `/expand` — why 221 should be fixed not deleted.

Never more than one such line. Never a generic "let me know if you want more".

## Never compress

Verbatim and complete, even in concise mode — these are not scope, they are the answer:

- Error output, stack traces, test failures
- Security findings
- Destructive-action confirmations and their consequences
- Anything the user explicitly asked to have explained or quoted

A concise answer that truncates a stack trace is a wrong answer. Break the 6-bullet
ceiling for these without asking.

## Do not

- Do not turn on by yourself. User-invoked only.
- Do not answer a direct "explain" / "why" / "walk me through" tersely — that request
  outranks the mode for that one turn, same as `/expand`.
- Do not drop a real blocker, risk, or wrong assumption to hit the bullet count.
  Cut detail, never findings.
