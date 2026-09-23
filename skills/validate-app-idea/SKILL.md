---
name: validate-app-idea
description: >
  Validate an app or product idea built on a specific AI model, API or new
  tech: parallel research, a bull/bear debate, a tested cost and rate-limit
  model, a verdict page, go/no-go tests and a Claude Code handoff. Use when the
  user invokes /validate-app-idea, says "I want to use <model/API/tech> to
  build <app>", or asks whether an idea is viable before any building starts.
argument-hint: "[tech] [app idea]"
---

# Validate an app idea on a new model or API

Use this before any building starts. The output is a self-contained validation
page (an Artifact) with a clear verdict, plus a draft Claude Code handoff
brief. **Report first; build only after the user approves.**

## 1. Research the tech yourself first (before asking questions)

- Web search the model or API: what it is, launch date, pricing, limits, SDKs,
  what it's bad at.
- Fetch at least one practical guide and the official docs. Look for a
  known-limitations page and read it closely, because it usually changes the
  plan.
- Note the capability shape: what the tech outputs, what it can't do (math,
  dates, world knowledge, text generation), and whether it can be called
  client-side or must stay on a server.

## 2. Ask clarifying questions (lots of them)

Use AskUserQuestion in two rounds of up to 4 questions each, recommended
options first:

- **Round 1:** core features (multi-select, and offer "report on all + more
  ideas"), platform/stack, data source, key access + personal vs commercial.
- **Round 2:** output format, commercial audience/segments, report depth (data
  + licensing, architecture + cost model, competitors, MVP), and whether to
  build right after or report first.

Follow the literal answers, including free-text ones like "compare them and
fan out to subagents".

## 3. Set up the task list

1. Research in parallel
2. Bull/bear debate
3. Build and test the cost model
4. Build the validation page with verdicts and handoff
5. Verify facts, math and render

## 4. Fan out 4 research subagents in ONE message (parallel)

Give each the date, a max of ~700 words, a mandatory Sources list, and "don't
fabricate numbers, say 'not found'":

- **Audience segments:** market size, willingness to pay and price anchors,
  regulatory risk as of the current year, latency sensitivity, and fit with
  the tech. Rate each 1–5 on revenue, regulatory risk, tech fit and
  competition, with a one-line verdict.
- **Data sourcing + licensing:** free/open vs paid feeds, update latency, fetch
  mechanics (CORS!), pricing tiers, and commercial-use terms. Flag sources that
  are unsafe for a paid product.
- **Competitor landscape:** features, price, whether they show confidence or
  accuracy, weaknesses. Name 3–5 gaps the new tech could own.
- **Tech deep dive from primary docs:** exact SDK call shape, pricing, rate
  limits, context limits, versioning, failure modes, ToS / acceptable use,
  server-only vs client use, ecosystem examples. Mark anything unconfirmed.

## 5. Bull + bear debate: 2 more subagents in ONE message (parallel)

Once the research is back, give BOTH agents the same condensed brief: the idea,
the chosen features and segments, and the key findings from all 4 research
reports with their sources. Each may run its own extra web searches. Cap each
at ~500 words with a Sources list.

- **Bull agent:** the strongest honest case FOR building it. Why now, the
  unfair advantage the tech gives, the fastest path to revenue, which segment
  wins, and the evidence that would prove it early. It must name the single
  biggest risk it is choosing to accept.
- **Bear agent:** the strongest honest case AGAINST. Kill risks (legal, data
  licensing, tech limits, platform or vendor dependency, incumbents copying
  it, unit economics, vendor pricing that may be subsidized), and what the
  research may have gotten wrong or overlooked. It must name what evidence
  would change its mind.
- Neither may invent facts. Both argue from the research plus sourced searches.

Then settle the debate yourself. Every bear kill-risk becomes a condition on
the verdict, a go/no-go hypothesis, or an explicit "accepted risk". Every bull
claim the verdict relies on needs a test that proves it. If the bear's case is
stronger, the verdict says "Not validated" or "Validated with conditions";
don't soften it.

## 6. Build a tested cost + rate-limit model in code

Start from the starter model shipped with this skill rather than a blank file:

```bash
cp ${CLAUDE_SKILL_DIR}/scripts/cost-model*.mjs <workdir>/
node --test <workdir>/cost-model.test.mjs   # 10 passing tests before you touch it
```

It already has `workloadCost` (input, cached input and output priced
separately), `costPerUserWeek`, `sharedCostWeek`, `totalWeekly`,
`breakEvenSubscribers` (fixed data cost, price, store cut, per-user LLM cost)
and `burstMinutes` (minutes to serve N users after a breaking event, bounded by
BOTH requests/min and tokens/sec, with batching and per-request prompt
overhead). Then:

- Replace `EXAMPLE` with the idea's workloads per feature: calls × tokens per
  user per week, plus SHARED workloads computed once for all users. Use
  sourced prices and limits from the tech deep dive.
- Add tests for the idea's own numbers (the figures the page will show, the
  break-even at the chosen price, the burst time at the chosen tier) and run
  them. When a test fails, find out whether the model or the assumption is
  wrong before changing either. Batching often flips the bottleneck from
  requests/min to tokens/sec — that is a real finding, not a bug.
- Key lessons to check every time: rate limits often matter more than price;
  classify each event once and fan it out in code; the data feed usually
  dominates the P&L.

## 7. Build the validation page (hand-built HTML artifact)

Run Artifact quickstart (intent "other"), then write one self-contained HTML
file. Sections, kept concise:

1. **Verdict header:** "Validated / Validated with conditions / Not validated",
   plus Go / Layer-only / Avoid pills per segment.
2. **Conditions callout:** the plan-breaking caveats from the limitations docs
   and the bear case.
3. **Bull vs bear:** two side-by-side cards, each with its 3–4 strongest
   points, then a one-line "how the verdict settles it".
4. **Feature scorecard:** the tech's job vs code/data's job, a fit rating, and
   an MVP/later call. Add 4–6 extra feature ideas that fit the tech's shape.
5. **Segment comparison table:** 1–5 ratings, price anchors, verdict.
6. **Data:** prototype stack (~$0) vs launch stack (costs), plus a "keep out of
   the paid product" callout.
7. **Architecture:** a cascade (code → tech → calibration/rules → LLM only when
   needed), the rate-limit finding and hard rules (key on the server, pin the
   version, log decisions, treat input as hostile).
8. **Cost:** stat tiles and a per-feature table, labeled "tested (n/n pass) ·
   token counts estimated".
9. **Competitors table** and the gaps.
10. **MVP recommendation:** scope and out-of-scope.
11. **Go/no-go hypotheses table:** H1–Hn, each with a measurable pass bar and a
    method, covering the bear's kill-risks and the bull's load-bearing claims,
    plus fallback rules if some fail.
12. **Claude Code handoff** (draft, with a copy button): goal, stack, SDK usage
    rules, data licensing constraints, milestones, definition of done.
13. **Open questions** for the user, including any employer/IP conflict if the
    idea overlaps their day job.
14. **Sources.**

**Rendering rules (learned the hard way):** keep the page fully
self-contained. No mermaid, no Google Fonts, no external scripts; draw
diagrams as HTML/CSS step boxes. (Artifacts allow Google Fonts, but it stays
banned here so the HTML backup renders identically offline.) Tokens on `:root` with dark-mode blocks, a
sticky nav, tables in `overflow-x` containers, no horizontal scroll at 400px.

## 8. Verify

- Rerun the cost tests.
- Take one Playwright screenshot at 400px width (in cloud sessions, use the
  preinstalled Chromium via `executablePath: '/opt/pw-browsers/chromium'`) and
  check `scrollWidth` equals `clientWidth`.
- Check that every number on the page matches the model's output (print it
  with `node cost-model.mjs <users>`).
- Publish. Also send the HTML file as a backup in case the artifact link
  won't load.

## 9. Record it in the idea tracker (optional)

If the repo has the idea tracker (`scripts/idea.mjs`), offer to record the
result — don't do it unasked:

- No idea file yet → capture it with `/new-idea` (or
  `npm run idea -- new "<title>" --summary "..." --tags "..."`).
- Add a dated `## Log` entry with the verdict, the artifact link and the
  go/no-go hypotheses, then `npm run index && npm run validate`.
- Commit as `idea: validate <slug>`. If the user says go, `/start-experiment`
  is the next step.

## 10. Finish

Keep it brief: the verdict in one line, the 3–5 findings that change decisions
(conditions, cost vs data cost, rate limits, licensing traps, the bear's
strongest point), the open questions, and "say go and I'll hand off to Claude
Code or build the prototype here." End with Sources.
