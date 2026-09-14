---
name: fanout
description: >
  Fan out N independent agents on one task — mixed models, separate takes —
  then synthesize what they found. N is yours to choose unless the user names
  it. Use when the user invokes /fanout, or asks to fan out, parallelise,
  get several independent takes, or attack something from multiple angles at
  once.
argument-hint: "[n] [task]"
---

# Fanout

Several agents attack the same work in parallel, and you synthesize the
results. Independence is the entire product: separate takes surface what a
single agent never thinks to question.

This is for breadth. When you want one thing built correctly rather than many
angles considered, use `/trio`, which is a driver, a navigator and a tester
working as a team rather than N strangers working alone.

## Scope

| Invocation | Means |
| --- | --- |
| `/fanout <task>` | That task, with N chosen by you |
| `/fanout <n> <task>` | That task, exactly N seats |
| `/fanout` (bare) | The task already on the table, N chosen by you |
| `/fanout <n>` | The task on the table, exactly N seats |
| Nothing on the table | Ask what to attack. Do not guess. |

A leading integer is N, not part of the task. If the user names N, use it —
they are paying for it.

## Choosing N

N is a dial on **coverage**, not on quality. A second seat does not make the
first one smarter; it looks somewhere the first one didn't. So size N to how
wide the space of plausible answers is.

**Same-task mode.** Each seat is an independent sample, so the marginal value
drops fast. Seat two roughly doubles coverage. Seat six adds a sliver.

| Task shape | N |
| --- | --- |
| Narrow question, one likely answer, you mostly want a second opinion | 2 |
| Default: a review, a diagnosis, a design question | 3 |
| Wide space — "what could break here", threat modelling, open-ended design, unfamiliar code | 5 to 6 |
| You are hunting for rare items and want saturation | up to 8 |

Past about 8 you are paying linearly for seats while the synthesis gets
quadratically harder, and the eighth take is usually the third seat's point in
different words. If you find yourself wanting 12, the task wants splitting, not
more samples.

**Split mode.** N follows the seams, not your preference. Four clean parts
means four seats. Never invent a fifth seam to round up, never merge two good
ones to save a seat. If the seams need to coordinate, the work is not
splittable and you should be in same-task mode.

Say what N you chose and why in one line before launching, so the user can stop
you if they wanted a different spend.

## This is not a vote

The most dangerous thing about a large N is that agreement starts to look like
proof. It is not. Seats drawn from the same model, given the same brief, share
the same blind spots — five of them agreeing on a wrong assumption is five
copies of one mistake, not corroboration.

So:

- **Never resolve a disagreement by counting.** Majority is not truth. Go and
  check, and if you cannot check, report it open.
- **A lone dissenter is often the valuable seat.** One agent finding something
  the other six missed is the normal shape of a real discovery. Verify it on
  its merits, never dismiss it on its arithmetic.
- **Agreement is only evidence if the briefs were genuinely independent.** A
  hint leaked into every brief manufactures the consensus you then trust.

## Launch

All N `Agent` calls in **one message** so they run concurrently. Each brief
must stand alone: the task, the relevant paths, what a finished answer looks
like, and a demand for evidence — `path:line`, command output — rather than
opinion.

Write every brief neutral. No suspected cause, no preferred answer, no
"confirm that…". A leaked conclusion turns N takes into N echoes.

Vary the **angle**, not the goal. For a bug at N=4: one traces the code, one
reproduces it empirically, one questions the assumptions in the report, one
looks for the same pattern elsewhere in the codebase. Same target, different
approach, which is what makes the takes complementary rather than redundant.

Never fork a seat. A fork inherits your whole transcript, hunches included,
and ignores the model override. Fresh agents only.

**If the task writes files**, N seats cannot share one working tree. Give each
`isolation: "worktree"`, or brief for a diff or a plan rather than applied
edits and apply the winner after synthesis. At high N prefer the latter —
eight worktrees is a lot of machinery for takes you are mostly going to
discard.

## Models

Match model to seat difficulty rather than defaulting everything to the top
tier. Fanout is an Nx spend and the model mix is how you keep it honest.

- Hard reasoning, ambiguity, synthesis-grade output → strongest available
- Solid mainstream engineering → mid-tier
- Mechanical sweeps, enumeration, lookups → smallest

In Claude Code: `opus` strongest, `sonnet` mid, `haiku` smallest. A reasonable
same-task default is one strong seat and the rest mid, with the smallest model
for any seat whose job is enumeration. For a split, put the strongest model on
the hardest chunk.

A mixed fleet also buys you something a uniform one cannot: when seats on
different models agree, that agreement survives one model's particular blind
spot. Weak evidence, but better than none.

No model parameter available? Run them all on the default. The independence is
doing most of the work.

## Synthesize

The synthesis is the deliverable, and it is the part that gets hard as N grows.
At N=3 you can hold every take in your head. At N=7 you cannot, and pasting
seven reports is not synthesis, it is a filing cabinet.

**Cluster by claim, not by seat.** Go through the takes and collect the
distinct claims. For each one, note how many seats reached it independently and
what evidence they brought. Then report in this order:

1. **Contested** — first, because it is where the work is. Two seats reached
   opposite conclusions on something that matters. Verify it yourself: a Read
   or one command beats adjudicating on vibes. Back a side with evidence, or
   state plainly that it is open. Never split the difference.
2. **Singletons** — what one seat found and the others missed. Attribute by
   angle and model, "the repro run (haiku)", never "Agent 4". Verify the
   load-bearing ones before passing them on.
3. **Consensus** — state it once, briefly, and say how many seats reached it
   independently. This is usually the least interesting section, which is why
   it goes last.

**Note the returns.** If the last two seats produced nothing the others hadn't,
say so — it tells the user, and you, that N was already past enough for this
kind of task.

## When a seat fails

A seat that errors, times out, or returns unsupported opinion: synthesize from
the seats that landed and say which failed. Relaunch only if the failure was
mechanical and the answer still needs it. Never invent the missing take.

For a split, missing a seat means missing a chunk, which is a hole rather than
reduced coverage. Say so explicitly and re-run that chunk.

## Do not

- Do not invoke this yourself. N agents is a spend the user opts into.
- Do not fan out a task with no room for disagreement — a lookup, a one-liner.
  Say so and just answer it.
- Do not run without the `Agent` tool. Say fanout is unavailable and do the
  task once; N sequential passes by the same model is not N independent takes.
- Do not show one seat another's output, before or during the run.
- Do not paste the reports. Synthesize, or you have spent N times the tokens to
  produce N times the reading.
- Do not pad N to look thorough. An honest 3 beats a theatrical 8.
