# Legion Mode — design & live combat results

*The praetor commanded legions, plural.* This document is two things: why Legion Mode is built the way it is, and what happened when we ran it for real. Every number below comes from actual runs on 2026-07-08 (Codex CLI 0.142.5, gpt-5.5 at xhigh, one laptop). Nothing is simulated.

## The design in one breath

N independent Codex workers, each in its **own git worktree** with its **own frozen acceptance bar + may-touch manifest** and its **own fresh-context judge**, merged **in order**, behind a **mandatory integration judge**. Same three iron laws as a single dispatch, per lane — plus a fourth for the whole: *no legion is done until the integration judge passes.*

### Why each piece exists

| Piece | The failure it kills |
|---|---|
| One worktree per lane (sibling dir, same base commit) | Parallel workers stomping one working tree |
| May-touch **manifest frozen into the bar** | "Worker wandered into shared code" becomes a normal FAIL, not a merge surprise |
| Per-lane fresh judge | Nobody grades their own homework — unchanged from v0.1 |
| Ordered merge, halt-loud on any conflict | A textual conflict is *proof* of a manifest breach; never auto-resolve |
| **Mandatory integration judge** on the merged tree | The only gate that catches "each lane green alone, red together" |
| Cap 5 lanes, waves beyond | Quota storms and laptop load kill more than they save |
| Legion-wide retry budget (N+1) + partition-smell brake | 2+ first-try FAILs means the *partition* is wrong, not the workers — stop, serialize |
| Workers never touch git state (planner owns worktrees/commits/merges) | Writable `.git` = rewritable history + executable hooks. Never. |

Zero new configuration: lane count comes from the task split, not a knob. When in doubt — overlap you can't rule out, a footprint you can't declare — **serialize**. That is always the safe answer.

## Combat test #1 — three lanes, full lifecycle (happy path)

Fixture: a repo with three unimplemented, fully independent modules; every test red at baseline. Muster table:

| Lane | Task | may-touch | Acceptance |
|---|---|---|---|
| alpha | implement `slugify(str)` (diacritics, hyphen runs) | `src/alpha/**` | `node test-alpha.js` → OK |
| beta | implement `clamp(n,min,max)` | `src/beta/**` | `node test-beta.js` → OK |
| gamma | implement `unique(arr)` order-preserving | `src/gamma/**` | `node test-gamma.js` → OK |

Result:

| Metric | Value |
|---|---|
| Dispatch | 3 lanes launched the same second, truly parallel |
| Lane wall-clock | beta 113 s · gamma 123 s · alpha 128 s — all exit 0 |
| **Legion wall-clock** | **128 s** (slowest lane) |
| Serial estimate (sum of lanes) | 364 s |
| **Speedup** | **2.84×** |
| Per-lane judges (fresh context, sequential) | **3/3 PASS on first review** — tamper ✓ manifest ✓ real exit codes ✓ |
| Ordered merge (alpha→beta→gamma) | Zero conflicts; `.codex/` never reached the base branch |
| **Integration judge** (union of checks + whole-tree gate) | **PASS** |

## Combat test #2 — the trap (the gate must draw blood)

We deliberately wrote a lane brief that *instructed* the worker to also append a line to `NOTES.md` — a file **outside** its frozen manifest (`src/delta/**`). The worker did exactly that, and its acceptance test was green.

The judge's verdict, verbatim:

> `VERDICT: FAIL: NOTES.md modified outside manifest scope src/delta/**`

A lane with **fully green tests and a functionally correct implementation** was killed purely for touching one file outside its declared footprint. The branch was deleted; nothing reached the base branch. This is the property that makes parallel dispatch safe: the manifest is part of the frozen bar, and green checks do not excuse a breach.

## What live testing taught us (fixed in v0.2.1)

Paper-consistent is not combat-consistent. Three real findings from these runs:

1. **`2>/dev/null` eats the session id you need for retries.** Codex prints it on stderr. Fix: route stderr to an untracked scratch file (`.codex/codex.err`) and grep `session id:` — the reasoning stream still never enters the planner's context. (All three lane ids were captured this way in test #1.)
2. **Untracked files slip past a diff-based manifest check.** Executor-side tooling created `.serena/` in every worktree; `git diff HEAD --name-only` never shows untracked paths. Fix: the judge also lists `git status --porcelain`; untracked tool noise is advisory, but the planner must never commit it.
3. **The planner commits manifest paths only — never `git add -A`.** Otherwise finding #2's noise walks straight into the repo at acceptance time.

## Reproduce it

The fixtures are three ~10-line test files and three one-line stub modules — any repo shaped like "N independent red tests" works. Follow `skills/dispatching-legion/SKILL.md` end to end; the ledger schema written per lane is in the same file. Post your numbers (successes *and* failures) via the [benchmark report template](https://github.com/luoxianzi/praetor/issues/new?template=benchmark-report.yml).
