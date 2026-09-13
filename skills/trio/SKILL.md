---
name: trio
description: >
  Fan out three parallel subagents on one task — mixed models, independent
  takes — then synthesize their results. Takes an optional task; bare /trio
  targets the task already under discussion. Use when the user invokes /trio
  or asks for trio by name.
argument-hint: "[task]"
---

# Trio

Three subagents attack the work in parallel; synthesize the results.
Independence is the point — three separate takes surface what one agent
never questions.

## Scope

| Invocation | Task |
| --- | --- |
| `/trio <task>` | The stated task |
| `/trio` (bare) | The task already on the table — the previous request or open question |
| `/trio` with nothing on the table | Ask what to attack. Do not guess. |

## Pick a mode

Default to same-task. Split only when the user asks for a split or the task
names three separable pieces itself. If unsure, same-task — a redundant take
costs tokens; a bad seam costs correctness.

**Same task, three takes** (questions, reviews, designs, diagnoses): all three
get the same goal; vary the angle each brief takes, not the goal — e.g. for a
bug: one traces the code, one reproduces empirically, one questions the
assumptions in the report itself.

**Three-way split** (divisible work): partition into three non-overlapping
chunks with explicit boundaries. Only when the seams are genuinely clean — if
the chunks would need to coordinate, use same-task mode or don't use trio.

## Assign models

Match model to seat difficulty; don't default everything to the top model.
Trio is roughly a 3x spend; the model mix is how you keep it honest.

- Hard reasoning, ambiguity, synthesis-quality output → strongest available.
- Solid mainstream engineering work → mid-tier.
- Mechanical sweeps, enumeration, lookups → smallest.

Map tiers to the names the Agent tool accepts — in Claude Code: `opus`
strongest, `sonnet` mid, `haiku` smallest. A good default for same-task mode:
one strong + two mid; for a split, the strongest model on the hardest chunk.
No model parameter available? Run all three on the default — independence
still pays.

Never fork. Forks ignore the model override and inherit the whole transcript —
your hunches included. Fresh agents only.

## Launch

All three `Agent` calls in ONE message so they run concurrently. Each brief
must be self-contained: the task, the relevant paths, what a finished answer
looks like, and a demand for evidence (`path:line`, command output) rather
than opinion.

Write the brief neutral: no suspected cause, no preferred answer, no "confirm
that…". A leaked conclusion turns three takes into three echoes, and the
agreement it manufactures is worthless.

If the task writes files, three seats cannot share one working tree. Same-task
mode: `isolation: "worktree"` per seat, or brief for a diff/plan rather than
applied edits — apply the winner after synthesis. Split mode: disjoint file
sets, or worktrees anyway.

## Synthesize

The synthesis is the deliverable. Verdict first, then:

- **Disagreement** — the interesting part. If a disagreement decides the
  answer, verify it yourself before backing a side — a Read or one command
  beats adjudicating on vibes. Not cheap to verify? Report it open.
- **Agreement** — high confidence, given neutral briefs; state it once.
- **Unique findings** — attribute by seat so the user can weigh the source.
  Name seats by angle and model — "the repro run (haiku)" — never "Agent 2".

A seat that errors, times out, or returns unsupported opinion: synthesize from
the seats that landed and say which failed. Relaunch only if the failure was
mechanical and the answer still needs it. Never invent the missing take.

For a split, synthesis is assembly plus the seams: check nothing fell between
chunks and that the parts agree on conventions where they touch.

## Do not

- Do not invoke by yourself. User-invoked only — three agents is a spend the
  user opts into.
- Do not trio a task with no room for disagreement (a lookup, a one-liner).
  Say so and just answer.
- Do not run without the Agent tool. Say trio isn't available and do the task
  once — three sequential passes by the same model is not independence.
- Do not share one seat's output with another, before or during the run.
- Do not paste three reports. Synthesize.
- Do not split the difference on a disagreement. Back a side or say it's open.
