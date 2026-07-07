---
name: dispatching-legion
description: Use when the user explicitly asks to run SEVERAL Codex tasks in parallel — "dispatch these in parallel", "派几路codex一起干", "legion these", or hands over a multi-task plan with independent pieces. Runs multiple isolated Codex workers (one git worktree + frozen bar + independent judge each), then merges in order behind a mandatory integration judge. NEVER auto-run — parallel dispatch happens only on the user's word, and only when the tasks are provably independent. When in doubt, serialize with dispatching-to-codex instead.
---

# Legion Mode — commanding many Codex workers

The praetor commanded legions, plural. Same discipline as a single dispatch (skills/dispatching-to-codex), now across N isolated worktrees at once. **Parallel speedup is real only when a task splits into 2–5 genuinely independent, mechanical, multi-minute pieces.** If it doesn't, that's not a legion — it's one dispatch or none. Serializing is always the safe answer to any doubt.

Everything from `dispatching-to-codex` still holds **per lane**: the three iron laws, the git-state boundary (workers never touch git — the planner creates worktrees, commits, merges), the stdin-heredoc dispatch rule, hard 10-min timeout, loud failure, STOP file, ledger.

## When NOT to run a legion (→ fall back to a single dispatch)

- Tasks whose file footprints overlap, or you can't declare each footprint precisely.
- Fewer than 2 independent tasks, or any task that isn't mechanical + concretely checkable.
- Tasks with dependencies/ordering between them (v0.2 lanes are strictly independent).
- Any "probably disjoint". Strictly disjoint or serialize.

## Lifecycle

**0. Muster.** Build the lane table. With **superpowers** installed, use `superpowers:writing-plans` to decompose — each plan task with exact file paths + a concrete acceptance check becomes one lane. Without superpowers, write it inline. Each lane needs: a one-line goal, exact pass/fail commands, and a **may-touch manifest** (explicit paths/globs). Mechanically verify the manifests are **pairwise disjoint**; judge whether each declared set is semantically complete (shared allocators, SSoT modules, transitive imports) — when unsure, serialize. Cap at **5 lanes**; more independent tasks → waves of ≤5, each wave fully judged and merged before the next. Show the user the table (Lane | task | may-touch | acceptance) and get their word — legion is never automatic. You may offer once in ONE line if a plan is legion-shaped ("These 4 tasks touch disjoint files — parallel? ~15 min vs ~50 sequential"); if they don't take it, drop it.

**1. Preflight (once).** Run `${CLAUDE_SKILL_DIR}/../dispatching-to-codex/preflight.sh`; honor STOP; confirm `git worktree` works; base branch clean or stashed (v0.1 stash rule, done once in the main tree). Sweep stale legions: if `../<repo>-legion/` exists from a crashed run, report in one line and clean it first. Pick a short `<dispatch-id>` slug for ledger correlation.

**2. Isolate ×N (planner's hands only).** One worktree + branch per lane, all branched from the SAME commit (clean three-way merges):
`git worktree add -b codex/<dispatch-id>-<lane> ../<repo>-legion/<dispatch-id>/<lane> HEAD`
Sibling directory, never inside the repo. Copy untracked env files a lane's checks need; install deps in the worktree only if its acceptance commands require them (fold that cost into the worth-it call).

**3. Freeze ×N.** In each lane worktree, write and commit `.codex/ACCEPTANCE.md` = GOAL + exact checks + `MANIFEST:` (the may-touch list) BEFORE dispatch. The manifest is part of the frozen bar — it cannot move.

**4. Dispatch ∥N.** Launch all lanes as parallel background tasks, each rooted in its worktree, brief via quoted stdin heredoc (never interpolate):
```
codex exec -m gpt-5.5 -c model_reasoning_effort="xhigh" --sandbox workspace-write -C ../<repo>-legion/<dispatch-id>/<lane> - 2>"../<repo>-legion/<dispatch-id>/<lane>/.codex/codex.err" <<'PRAETOR_BRIEF'
<self-contained brief for this lane>
PRAETOR_BRIEF
```
Route stderr to the lane's untracked `.codex/codex.err` — **never `2>/dev/null`**: Codex prints the **session id** (needed for retries) on stderr, and /dev/null eats it (live-test finding). Capture it right after dispatch: `grep -m1 'session id:' <lane>/.codex/codex.err`. The reasoning stream stays in the file, out of your context. Hard timeout 600000 ms per lane. `PRAETOR_MODEL`/`PRAETOR_EFFORT`/relay overrides apply to all lanes identically.

**5. Watch.** Wait on background completions. Before acting on any completion and before every retry/merge, check the STOP file → if present, kill all codex processes, jump to Cleanup with a salvage report. One plain-language line per lane event ("legion: 3 workers dispatched" / "lane api-rename finished, judging" / "lane api-rename PASS" / "lane docs FAIL: test x failed").

**6. Judge (sequential).** After each lane finishes, spawn a fresh `codex-judge` subagent pointed at that lane's worktree + branch. It runs the frozen checks, the tamper check, AND the manifest check (any file outside MANIFEST → FAIL). No parallel judges in v0.2. FAIL → re-brief via `codex exec resume <that lane's session-id> - <<'PRAETOR_BRIEF' … PRAETOR_BRIEF` (stdin rule). Per-lane cap 2 retries. **Legion-wide retry budget = N+1 total** across all lanes; when it's spent, remaining FAIL lanes go straight to takeover — no resume. **Partition-smell brake:** if 2+ lanes FAIL their first attempt, stop retrying everything and offer to serialize — the partition is likely wrong, not the workers.

**7. Merge (ordered, after every lane has a final verdict).** For each PASS lane: planner commits the work in its worktree (Codex never commits) — **add the manifest paths only (`git add <manifest globs>`), never `git add -A`**: executor-side tool noise (e.g. `.serena/`, `.codex/codex.err`) must not enter the repo (live-test finding). Then drop `.codex/ACCEPTANCE.md` from the branch (`git rm .codex/ACCEPTANCE.md && git commit -m "praetor: drop acceptance bar"`), then merge lanes into the base branch in the declared order. **Any textual merge conflict = proof of a manifest breach that slipped both gates → halt all merging immediately, loud report, never auto-resolve.**

**8. Integrate (mandatory).** Spawn one fresh integration `codex-judge` on the merged tree: integration bar = union of all lanes' checks + whole-tree gates (typecheck/build/test) declared and frozen at Muster. This is the only gate that catches "each lane green alone, red together". FAIL → revert the last-merged lane, re-run to bisect the culprit, revert it, report it as FAIL. A legion is never "done" until integration PASSes.

**Partial-success policy (owner-chosen):** merge the lanes that pass (behind the integration judge on just those), and report the hole loudly — never silently call a 2-of-3 legion "done". Failed lanes get the Iron-Law-3 takeover offer ("Lane 2 failed twice; I'll do that piece myself unless you say otherwise").

**9. Cleanup (every exit path).** `git worktree remove --force <path>` for every lane, `git branch -D` FAIL branches, `git worktree prune`, `rm -rf ../<repo>-legion/<dispatch-id>` if empty, restore the main-tree stash if Preflight stashed. Ledger: one line per lane + one legion summary line in the untracked `.codex/ledger.jsonl`, correlated by `dispatch_id`.

## Composition with superpowers

superpowers decides *what the independent steps are*; praetor decides *whether each step is safe to hand to Codex, and enforces the bar.* If installed: `superpowers:brainstorming` → design; `superpowers:writing-plans` → tasks (its no-placeholder discipline is exactly what a frozen bar needs); each eligible task (mechanical + concrete checks + declarable disjoint footprint) → one lane. Ineligible tasks stay with `superpowers:subagent-driven-development` in the main tree — praetor never absorbs decomposition, planning, or non-delegated execution. After integration PASS, hand off to `superpowers:finishing-a-development-branch` for the merge/PR decision. Absent superpowers: the planner writes the muster table inline; identical freeze and manifest rules apply.

## Red Flags — legion-specific

| Excuse | Reality |
|---|---|
| "These probably don't overlap" | Probably ≠ proven. Undeclarable footprint = not legion-eligible. Serialize. |
| "Skip the integration judge, all lanes passed" | Lanes green alone can be red together. Integration judge is Iron Law 2 on the whole. |
| "Merge conflict — I'll just resolve it" | A conflict means a manifest breach slipped the gates. Halt loud; never auto-resolve. |
| "One lane's blocked; give its files to another lane" | That's dynamic re-partitioning — deferred. Fail the lane, take it over. |
| "Let's run 8 in parallel, the machine can take it" | Cap is 5; beyond that, waves. Quota storms and load kill more than they save. |
| "2 lanes failed first try, retry them all" | That's the partition smelling wrong. Stop, offer to serialize. |
