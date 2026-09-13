---
name: trio
description: Fan out three parallel subagents on one task — mixed models, independent takes — then synthesize their results. Use when the user types "/trio", says "trio" or "fan out", or wants multiple independent attempts compared.
---

# Trio

Three subagents attack the work in parallel; you synthesize. The value comes from
independence — three genuinely separate takes surface disagreements a single agent
would never notice — and from the model mix: not every seat needs the strongest model.

## Pick a mode

**Same task, three takes** (default — questions, reviews, designs, diagnoses):
all three get the same brief. Vary the angle, not the goal — e.g. for a bug:
one traces the code, one reproduces empirically, one questions the assumptions
in the report itself.

**Three-way split** (divisible work): partition into three non-overlapping chunks
with explicit boundaries. Only when the seams are genuinely clean — if the chunks
would need to coordinate, use same-task mode or don't use trio.

## Assign models

Match model to seat difficulty; don't default everything to the top model.

- Hard reasoning, ambiguity, synthesis-quality output → strongest available.
- Solid mainstream engineering work → mid-tier.
- Mechanical sweeps, enumeration, lookups → smallest.

A good default for same-task mode: one strong + two mid. For a split: strongest
model on the hardest chunk.

## Launch

All three `Agent` calls in ONE message so they run concurrently. Each brief must
be self-contained: the task, the relevant paths, what a finished answer looks
like, and a demand for evidence (`path:line`, command output) rather than opinion.

Do not share one agent's conclusions with another. Independence is the point.

## Synthesize

Never paste three reports. Merge:

- **Agreement** → high confidence; state it once.
- **Disagreement** → the interesting part. Name it, check the evidence yourself
  if cheap, and say which take you back and why.
- **Unique findings** → attribute ("only the empirical run caught…") so the user
  can weigh the source.

Report the merged result, disagreements first.
