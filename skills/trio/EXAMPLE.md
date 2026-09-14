# A worked run

A real trio run, start to finish, on a cart-pricing function. Nothing here is
illustrative — every finding and every number is from the actual run.

The point it demonstrates: the tester's suite went green, and the code was
still wrong in three ways. A green suite written from a contract inherits that
contract's blind spots. The navigator is the only seat positioned to see past
them, which is the whole reason it exists.

## The contract

The coordinator wrote `CONTRACT.md` first — signatures, return shape, and the
edge cases that decide correctness, including a worked example pinning the
rounding rule:

> Percent discounts round to the nearest cent, ties going up. A 15% discount on
> 2999 is 449.85, which rounds to 450.

That one line is doing more work than the paragraph around it. Remember it.

## Round 1 — driver and tester, concurrently

Both launched in a single message, so the implementation did not exist while
the tests were being written. The tester was told, in as many words, not to
read `src/pricing.js`.

The driver returned in 38s having written the function, and reported three
places where the contract was ambiguous and it had guessed:

- an empty cart short-circuits before the code is validated, so an empty cart
  with a 150% coupon returns zeros instead of throwing
- percent values and `valueCents` were not required to be integers
- an unrecognized `code.type` silently means "no discount"

The tester returned in 56s reporting 25 cases (the runner later counted 27),
and flagged **the same first ambiguity**, having deliberately declined to test
it:

> I only tested this with valid codes. It's ambiguous whether validation
> short-circuits before or after the empty-cart check; testing either way would
> bake in a guess the contract doesn't settle.

Two seats that could not see each other, guessing separately, converging on the
same gap. That is the spec being wrong, not the code — and it is a signal you
only get from running them independently.

## Verifying the seats, not just the code

Before trusting a green suite, the coordinator checked the tester actually
followed its one rule, using the activity log rather than its word:

```
$ ${CLAUDE_SKILL_DIR}/scripts/seat-log.sh <tester output_file>
[1] Read  .../CONTRACT.md
[2] $ ls -la .../triolab/ ; ls -la .../triolab/test
[3] Write → .../test/pricing.test.js
```

Contract, directory listing, write. It never opened the implementation. A rule
you cannot check is a rule the run does not actually have.

## The coordinator runs the tests

Not the seats. The first invocation was wrong and produced a module resolution
error that looked exactly like broken code — worth knowing, because reporting
your own bad command to the driver as a defect burns a round. Corrected:

```
# tests 27
# pass 27
# fail 0
```

27 independently written tests, green against an implementation their author
never saw. At this point the round looks finished. It is not.

## Round 1 — the navigator

Given the diff, the driver's activity log, the real test results, and the
driver's own claims explicitly labelled as claims rather than evidence. It ran
the code to check each suspicion and came back with three blocking defects.

**1. The one rule the contract spelled out was broken.**

```js
applyDiscount([{ sku: 'A', unitPriceCents: 1500, quantity: 1 }], { type: 'percent', value: 2.3 })
// got  discountCents: 34
// want discountCents: 35
```

2.3% of 1500 is exactly 34.50 — a tie, which the contract sends up. But
`1500 * 2.3` evaluates to `3449.9999999999995`, so the tie never reaches
`Math.round` and it rounds down. The driver had left a comment saying
`Math.round` handles ties, which is true of `Math.round` and false of the
expression feeding it.

Sweeping one-decimal percents against exact arithmetic, **63 of 1000 values are
wrong on a single subtotal**. The tester's rounding cases all happened to land
on floats that round correctly — including the contract's own 15%-of-2999
example, which passes.

**2. Non-integer `valueCents` produced non-integer money.** `valueCents: 10.5`
gave `discountCents: 10.5` and `totalCents: 989.5`, against a contract that
says all three fields are integers.

**3. An infinite price gave a `NaN` total.** `1e308` passes `Number.isInteger`,
the cap `discount > subtotal` is false for `Infinity > Infinity`, and the
subtraction yields `NaN`.

It also ruled on the driver's three judgment calls, and talked the coordinator
out of the driver's position on all three — most sharply on the silent
unknown-code-type, which it called "a customer-visible overcharge that no test
or log will ever surface."

## Adjudication

The coordinator re-ran each finding before acting on it. All three reproduced.

The ambiguities went back into `CONTRACT.md` as rules 6 through 10, rather than
being settled seat by seat — when two seats guess separately and converge, the
contract is what needs fixing.

## Round 2

Both seats were resumed rather than respawned, so each kept its own context: the
driver remembered the code it had written, and the tester remembered which
cases it had deliberately left alone.

The driver got the three defects as corrections. The tester got only the
contract amendments — never the fix, never the implementation. Tests follow the
contract, not the patch, or they degrade into a description of whatever the
code now happens to do.

The driver replaced the float multiplication with exact fractional arithmetic
in `BigInt`, added the integer and safe-integer guards, and reordered
validation so a malformed code throws before the cart is examined.

The tester, still working from the contract alone, went looking for more ties
the way the navigator had — by searching float behavior, not by reading the
fix — and found four beyond the one it was given: 64.6% of 250, 32.3% of 500,
16.4% of 375, 38.8% of 375. All are cases where the float product lands just
below the true tie. A tester that had read the patch would have had no reason
to look.

## Verifying, not trusting

The tester reported 52 tests. The runner reported 44 passing — just as its 25
became 27 in round 1. Neither number is a lie; they count differently. But it
is a standing reminder of why the coordinator runs the suite rather than
accepting a seat's summary of it.

The coordinator then re-checked each original defect directly, and swept one-
decimal percents across six subtotals against exact arithmetic:

```
finding 1 — 2.3% of 1500 -> 35                              PASS
finding 1 — 15% of 2999 -> 450 (contract example holds)     PASS
finding 2 — valueCents 10.5 throws TypeError                PASS
finding 3 — 1e308 price throws TypeError                    PASS
empty cart + percent 150 now throws                         PASS
unknown code.type throws                                    PASS
sweep: 0 mismatches out of 6000 cases                       PASS
```

## What the run cost, and what it bought

Three seats, two rounds, about six minutes of agent time.

The tests alone would have shipped a rounding bug hitting 63 of 1000
one-decimal percent values on a single subtotal — in the one rule the spec
bothered to spell out with a worked example. The suite was green the entire
time it was wrong.

The tests were not bad. They were written from the contract, and so was the
bug. That is the gap the third seat covers.
