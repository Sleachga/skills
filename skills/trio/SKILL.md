---
name: trio
description: >
  Pair programming with three agents: a driver that writes the code, a
  navigator that reviews everything the driver does and corrects it, and a
  tester that writes tests independently. Takes an optional task; bare /trio
  targets the task already under discussion. Use when the user invokes /trio
  or asks for trio, the trio, or pair programming by name.
argument-hint: "[task]"
disable-model-invocation: true
---

# Trio

Three seats on one task. A **driver** writes the code. A **navigator** watches
what the driver did and corrects it. A **tester** writes tests without seeing
the implementation. You are none of them — you are the coordinator who runs the
loop, holds the ground truth, and decides.

The value is structural, not extra effort. An agent reviewing its own work
grades its own homework, and an agent writing tests for code it just wrote
writes tests that pass. Separating the seats is what makes the review real.

## Scope

| Invocation | Task |
| --- | --- |
| `/trio <task>` | The stated task |
| `/trio` (bare) | The task already on the table — the previous request or open question |
| `/trio` with nothing on the table | Ask what to build. Do not guess. |

Trio is for work with enough substance to be gotten wrong: a feature, a
refactor, a bug with a non-obvious cause. For a one-line change, three seats
cost more than they catch — say so and just do it.

## The seats

| Seat | Writes | Never |
| --- | --- | --- |
| **Driver** | Source files | Writes its own tests; reviews its own work |
| **Navigator** | Nothing | Edits code; sees the task before the driver does |
| **Tester** | Test files only | Reads the driver's implementation |

One writer per file set. The driver owns source, the tester owns tests, the
navigator owns nothing — that is what lets all three share a working tree
without a merge problem. If the repo's layout would put them in the same file,
give the tester `isolation: "worktree"` instead.

**The navigator never edits.** A navigator that fixes the bug itself stops
being a second pair of eyes and becomes a second driver, and the driver stops
hearing about its mistakes. Corrections travel as instructions: the navigator
says what is wrong and what it should be, and the driver applies it. Apply a
correction yourself only if the driver has failed twice to apply it — and say
you did.

## What the navigator can actually see

Claude Code gives you no live feed into a running subagent. You cannot watch
the driver type. What you *can* do is hand the navigator the complete record
after each round, which is better than shoulder-surfing anyway — it is the
whole round at once, with nothing missed.

Three channels, in descending order of trust:

1. **The diff** — `git diff` after the driver's turn. Ground truth. What the
   code *became*, independent of anyone's account of it. Run `git add -N` on
   new files first, or a brand-new file is untracked and the diff comes back
   empty — you will hand the navigator nothing and not notice.
2. **The activity log** — every command the driver ran and what it printed.
   Each `Agent` call returns an `output_file` (the seat's transcript); pass it
   through `seat-log.sh` below for a compact log. Do not read the raw
   transcript — it costs more context than the work it describes.
3. **The driver's own report** — useful for *intent*, worthless as evidence. A
   seat that broke something reports the version of events in which it did not.

Give the navigator 1 and 2. Channel 3 only as "here is what the driver
believes it did", labelled as such, so a mismatch between the claim and the
diff is itself visible — that gap is often the most useful thing in the round.

The activity log is also how you *audit the seats*, not just the code. The
tester's log tells you whether it really wrote its tests from the contract or
quietly opened the implementation. A rule you cannot check is a rule the run
does not actually have, so check it before you trust the green suite.

```bash
${CLAUDE_SKILL_DIR}/scripts/seat-log.sh <output_file>                  # full log
${CLAUDE_SKILL_DIR}/scripts/seat-log.sh <output_file> --commands-only  # commands and edits only
```

## The round

One round is one slice of work. Most tasks take two or three.

**1. Define the slice.** A slice the driver can finish in one turn, plus the
*interface contract* — function signatures, file paths, expected shapes. The
contract is what lets the tester write real tests without seeing the code.

**2. Launch the driver and tester in one message, so they run concurrently.**
This is the point: the tester cannot copy an implementation that does not exist
yet. Tests written after reading the implementation encode its bugs as expected
behavior, and a green suite then proves nothing.

Brief each seat self-contained — task, contract, paths, what done looks like.
Neither seat is told what the other is doing. Do not tell the driver the tests
are coming; a driver writing to a known test is optimizing for green, not for
correct.

**3. Capture ground truth yourself.** `git diff` for the code. Then run the
tests — *you* run them. A seat reporting its own green suite is the single most
common way a trio run goes quietly wrong.

If the suite fails to even load — a module resolution error, no tests
collected — suspect your own command before you suspect a seat. Reporting your
own bad invocation to the driver as a defect burns a round and teaches it to
"fix" working code.

**4. Launch the navigator** with the brief, the diff, the driver's activity log,
and the real test results. Ask for findings ranked blocking / non-blocking,
each with a `path:line` and the failure it causes. An opinion without a
mechanism is not a finding.

**5. Adjudicate.** Blocking findings go back to the driver as corrections. A
failing test is a finding like any other, but decide *which* side is wrong
before assigning it — a red test can mean broken code or a tester that
misread the contract, and sending it to the wrong seat corrupts the work.

**6. Stop or go again.** Done when the tests pass and the navigator's blocking
list is empty. If a round produces no change in either, stop anyway and report
where it stalled — a fourth round rarely finds what three did not.

## Resuming seats

Spawn each seat once and resume it, rather than spawning fresh agents each
round. Keep the `agentId` from the spawn result and continue that seat with
`SendMessage`; it comes back with its context intact.

This matters most for the navigator. A navigator that remembers what it flagged
last round can see that a correction was ignored, or that the fix broke
something it already approved. A fresh navigator each round re-reviews from
zero and re-litigates settled questions.

Never use `context: fork` for a seat. A fork inherits your whole transcript —
your hunches, your suspicions, the answer you are half expecting — and three
seats that share your priors are one seat in a trench coat.

## Models

Seats are not equal. Spend where the judgment is.

- **Navigator: at least as strong as the driver.** Never weaker. A navigator
  that cannot follow the driver's reasoning rubber-stamps it, and a
  rubber-stamp is worse than no review because it manufactures confidence.
- **Driver:** strong. It is doing the work.
- **Tester:** mid-tier is usually enough — it works from a written contract,
  which is the easy half.

In Claude Code: `opus` strongest, `sonnet` mid, `haiku` smallest. A reasonable
default is opus navigator, opus or sonnet driver, sonnet tester. If no model
parameter is available, run all three on the default — the separation of roles
is doing most of the work, not the model mix.

## When a seat fails

A seat that errors or times out: relaunch it once if the round needs it,
otherwise continue with the seats that landed and say which is missing. Never
write the missing seat's output yourself — a navigator report you wrote is you
reviewing your own coordination, which is the exact failure the trio exists to
prevent.

If the driver and navigator disagree twice on the same point, stop the ping-pong
and decide it yourself with evidence — read the code, run the case. Then say
which way you ruled and why. An unresolved disagreement that costs two rounds
is a question for the user, not a third round.

## Report

What was built, what the navigator caught, what the tests cover. Specifically:

- Every blocking finding and whether it was fixed
- Anything the navigator flagged that you overruled, and why
- What the tests actually exercise, and what they do not
- Disagreements left open

The catches are the interesting part. A trio run that reports only the finished
code has thrown away everything you paid for.

## Do not

- Do not invoke this yourself. User-invoked only — three seats is a spend the
  user opts into.
- Do not let the tester see the implementation. It is the one rule that makes
  the tests worth anything.
- Do not accept "tests pass" from a seat. Run them.
- Do not let the navigator edit code.
- Do not show one seat another's output mid-round, except the driver receiving
  the navigator's corrections. Independence is the whole product.
- Do not paste three reports. You are the coordinator; synthesize.
- Do not run without the `Agent` tool. Say so and do the task once —
  three sequential passes by the same model is not three pairs of eyes.
