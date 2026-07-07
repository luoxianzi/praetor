# Green tests don't grant absolution

*Why praetor spends its effort on a judge instead of a faster model.*

You have probably already done this today: you handed a coding agent a task, walked away, came back, and it said **done**. The tests were green. The diff looked reasonable. You merged it.

That merge was an act of faith. This is the story of why we stopped making it — and built a gate that can't be talked out of a NO.

---

## The number that started it

We ran praetor's executor (the Codex CLI doing grunt work) on real tasks and had an independent reviewer check every result. Across our early live runs, **roughly 1 in 3 unattended executor runs failed independent review.**

Not 1 in 3 *crashed*. They came back **looking done** — plausible diff, green tests, confident summary — and still failed review. Every one of those is a change you would have merged on faith and only discovered later, if ever.

The lesson wasn't "use a better model." A better model lowers the rate; it does not make the faith safe. The lesson was: **the return needs a gate, and the gate has to be independent.**

---

## The trap (where the gate drew blood)

The cleanest way to show what "independent" buys you is a case where the executor did good work and was rejected anyway — correctly.

In a Legion run (several workers in parallel, each with a frozen list of files it is allowed to touch), we deliberately wrote one worker's brief to instruct it to *also* append a line to `NOTES.md` — a file **outside** its declared manifest of `src/delta/**`.

The worker obeyed. It implemented its feature. Its acceptance test was **green**. The code was **functionally correct.**

The judge — a fresh agent that never saw the plan, only the frozen criteria and the diff — returned this, verbatim:

```
VERDICT: FAIL — NOTES.md modified outside manifest scope src/delta/**
```

The branch was deleted. Nothing reached the base branch. A lane with fully passing tests and correct code was killed **purely for touching one file it wasn't allowed to touch.**

That is the property that makes delegation safe. Green tests describe what the code *does*; they say nothing about what it was *allowed* to do. In parallel work especially, "a worker quietly edited shared code" is exactly the failure that passes its own tests and breaks everything downstream. Making the file manifest part of the frozen bar turns that from a merge-time surprise into a normal, boring FAIL.

---

## Why the judge has to be a stranger

The obvious objection: *why not just have the planner check the work?*

Because a model grading work it was involved in is grading its own homework. The industry has converged on this the hard way — the current consensus is that asking an AI to review its own output is architecturally unsound, because a model cannot objectively evaluate what it just produced. The prescribed fix is a **separate validator with separate context and permission to fail the work.**

praetor takes the corollary that most setups miss: **the judge has to be independent of the planner, not just of the executor.** If Claude wrote the plan *and* graded the result, it is still grading its own homework — one level up. So the judge:

1. **Never saw the planning conversation.** It gets only the frozen acceptance criteria and the diff. It has no memory of why a choice was made, so it cannot be charmed by the reasoning — only by the evidence.
2. **Reads a bar that was frozen in git *before* the executor ran.** Deterministic commands with exit codes, not vibes. The definition of "done" cannot move after someone sees the output.
3. **Has a binding FAIL.** Not advisory. Not a suggestion the planner can weigh against a persuasive diff. A FAIL cannot be overridden — not by you, not by Claude. If you want an overridable judge, you want a different tool, and [docs/DESIGN.md](DESIGN.md) explains why we won't build one.

Take away any one of those three and the gate leaks. A judge that saw the plan gets talked into it. A bar written after the fact gets bent to fit. An overridable FAIL is just a code review you'll skip when you're tired.

---

## The honest part: we left our failures in the README

A benchmark table that only shows wins is marketing, not measurement. Ours shows the scars on purpose.

Of the first four dispatch attempts, **two stalled** — one hung for 29 minutes with zero writes — and were killed by praetor's hard timeout law. Both retries then succeeded. We did not delete those rows. They are in the [README benchmark](../README.md#measured-not-promised) because the timeout law *is* the product: there is no silent-failure path, so when something hangs you find out loudly instead of waiting forever.

When we hit real bugs in the harness during those runs — stderr eating the session id we needed for retries; untracked tool-noise slipping past a diff-based manifest check — **we fixed the harness. We did not touch the verdict.** The judge's job is to be right about the work, not to be convenient for us. (The full combat log, numbers and all, is in [docs/LEGION.md](LEGION.md).)

That distinction is the whole ethic: you are allowed to fix the machinery around the gate; you are never allowed to soften the gate to make the machinery look better.

---

## What this means for you

If you already split your work — plan in Claude Code, execute in Codex, the way most people now do by hand — praetor is just the missing third seat: the one that checks whether what came back actually matches the plan you froze, before it merges.

You keep the speed of delegation. You lose the faith.

- **The pitch in one line:** Claude plans, Codex executes, and a judge you can't sweet-talk decides what merges.
- **The one thing to remember:** green tests don't grant absolution. Delegation without verification is just hope.

praetor is MIT, zero-config, and dormant until you summon it: **[github.com/luoxianzi/praetor](https://github.com/luoxianzi/praetor)**
