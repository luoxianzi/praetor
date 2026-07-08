---
name: dispatching-to-codex
description: Use when the user SUMMONS Codex delegation in this conversation — "use codex", "交给codex", "用praetor", the /delegate command — and, once summoned, for every later task in the conversation that is delegate-shaped (mechanical, well-specified, checkable grunt work; auto-triage with a one-line announcement). DORMANT until summoned — if the user has not called for Codex/praetor in this conversation, never dispatch; at most offer the option once, in one line. Never dispatch design work, subtle debugging, tiny tasks, or git-state operations.
---

# Dispatching to Codex

Claude is the brain; Codex is the hands. You plan, freeze the bar, and judge. Codex executes on its own quota, in its own process, so your context stays small and your tokens go to judgment — not grunt work.

## Consent model: summoned imperium

The praetor takes office only when appointed — **dormant until the user summons it in this conversation** ("交给codex", "use codex", "用praetor", `/praetor:delegate`). Before a summon: never dispatch; you may point out the option ONCE in one line if work is clearly Codex-shaped, and drop it if not taken. **After a summon, you hold imperium for the rest of the conversation**: triage every subsequent task yourself, decide single dispatch vs a legion split (see dispatching-legion), announce each dispatch in one plain line ("Dispatching to Codex: <task> — bar frozen, ~N min, hands off the tree until I report; say the word to stop"), and act — no per-task permission. The brakes are standing and absolute: a plain-language veto ("don't send this", "别派给codex") pins that task to you for the session and is never re-litigated; "stop delegating for now" ends the imperium (back to dormant); a `STOP` file in the repo root halts all dispatching. If **superpowers** is installed, default to its workflows upstream — `brainstorming` for design-level asks, `writing-plans` before multi-step work — and let delegate-shaped plan tasks flow into dispatch. (superpowers ships for Codex CLI too; if the user installed it on the worker side, briefs land on a disciplined executor — praetor requires nothing of the sort.)

## Iron Laws (no exceptions)

1. **NO DISPATCH WITHOUT FROZEN ACCEPTANCE CRITERIA COMMITTED TO GIT.** If you cannot write a concrete pass/fail check, the task is not ready to delegate — do it yourself.
2. **NO ACCEPTANCE WITHOUT A FRESH-CONTEXT JUDGE VERDICT.** A FAIL cannot be overridden — not by you, not by "the diff looks fine".
3. **MAX 2 RETRIES, THEN LOUD TAKEOVER.** Every failure path ends with you doing the work and telling the user delegation failed. Silent success is forbidden.

## Is it worth dispatching? (say so BEFORE starting)

Dispatch overhead is real: branch + freeze + judge ≈ 2–5 minutes of wall-clock (measured ~4 min; see the README benchmark table) plus some of both quotas. Rule of thumb: a task you could finish in under ~5 minutes is not worth dispatching. If so, tell the user plainly: *"This is faster for me to do directly — still want Codex on it?"* Then respect their answer.

Good dispatches: bulk/repetitive edits, migrations, mechanical test-writing against a clear spec, wide "read everything, report back" analysis, output-heavy runs.
Bad dispatches: design work, subtle debugging, anything ambiguous, tiny tasks, and **any git-state operation** (branching, pulling, merging, rebasing, committing) — git is the planner's own hands; Codex edits files, never git state. Codex's sandbox keeps `.git/` read-only in `workspace-write` for exactly this reason.

## Lifecycle

0. **Preflight.** Run `${CLAUDE_SKILL_DIR}/preflight.sh`. `not-ready` → one-line explanation (e.g. "run `codex login` once and I can dispatch"), then do the work yourself. Never nag twice in a session. If it reports `git=no`, only the analysis-only shortcut below is available — for any write dispatch, say that write dispatches need a git repo and do the work yourself. If it reports `stranded-stash=` or `on-codex-branch=` (a previous session died mid-dispatch), surface that in one line and offer recovery FIRST — restore the stash / inspect-then-delete the leftover branch — before any new dispatch; never dispatch on top of a stranded run.

**Analysis-only shortcut:** if the dispatch edits NO files (wide read-and-report, investigation), skip ISOLATE/FREEZE/JUDGE — run `codex exec --sandbox read-only` (brief via stdin as in step 3; `mkdir -p .codex` first so the stderr redirect works) and review the report yourself. The gate exists for merges, not for reading. Belt over the sandbox: snapshot `git status --porcelain` BEFORE the run (to an untracked file, e.g. `.codex/pre.txt`); after the run, compare against a fresh `git status --porcelain`. Act ONLY on paths that are new or changed **relative to the snapshot** (`.codex/` excepted): delete new untracked paths, restore modified tracked files one by one (`git checkout -- <path>`), then restart the task on the full write path. The user's own pre-existing uncommitted work is sacred — a dirty tree is the NORMAL state here, so a bare `git checkout -- .` or `git clean -fd` would irrecoverably wipe their WIP: **never run either against the whole tree on this path.** If preflight reported `git=no`, add `--skip-git-repo-check` to the command (codex refuses to run outside a git repo without it) and skip the snapshot dance — there is no tree to protect. Everything below is the write path.

1. **Isolate.** If `git status --porcelain` is non-empty, first `git stash push -u -m "praetor-<slug>"` and tell the user in one line that their uncommitted work is stashed and will be restored after. Then `git switch -c codex/<slug>` (branch already exists → append `-2`) — throwaway branch; main is never touched.
2. **Freeze.** Write `.codex/ACCEPTANCE.md`: one-line GOAL + the exact commands that must pass (exit codes, not vibes). Commit it BEFORE Codex exists. See skills/writing-codex-briefs for the format.
3. **Brief + dispatch.** Self-contained brief (Codex sees zero chat history). Pass the brief via **stdin with a quoted heredoc** — never interpolate it into the command line (quotes/backticks in task text would break the shell or inject):

   ```
   codex exec -m gpt-5.5 -c model_reasoning_effort="xhigh" --sandbox workspace-write - 2>.codex/codex.err <<'PRAETOR_BRIEF'
   <the brief>
   PRAETOR_BRIEF
   ```

   Route stderr to the untracked `.codex/codex.err` — **never `2>/dev/null`**: the session id you need for retries is printed on stderr (live-test finding). Capture it right after dispatch: `grep -m1 'session id:' .codex/codex.err`. The reasoning stream stays in the file, out of your context.

   Model/effort overrides, in priority order: `PRAETOR_MODEL` / `PRAETOR_EFFORT` env vars (use verbatim if set) → preflight reported `config=custom` (active relay provider: DROP the `-m`/`-c` flags, keep `--sandbox`, respect their config) → stock default above. Never `danger-full-access`.
   **Hard timeout:** run the dispatch through your shell tool's timeout at 600000 ms (10 min) — never unbounded. Timeout fired → record `A-TIMEOUT-KILLED` in the verdict history, reset the tree (`git checkout -- . && git clean -fd -e .codex` — safe here: the write path always starts from a clean or stashed tree on a throwaway branch), and retry **with a fresh full dispatch, never `resume`** (the reset erased the work the old session believes exists); a timeout consumes one of the 2 retries (Law 3).
   **Any other non-zero `codex exec` exit** (crash, auth death) counts exactly the same: read `.codex/codex.err` for the reason, reset the tree the same way, and it consumes one retry. If the error is auth/login-shaped, stop retrying — tell the user to run `codex login` (stale credentials pass preflight's file-presence fallback; the real error only surfaces here). There is no error exit that silently re-dispatches outside the retry counter.
   While a dispatch runs, the working tree belongs to Codex: tell the user in the announcement not to edit the repo until you report back (they can watch live: `tail -f .codex/codex.err`).
   Big output → `-o <file>`, never into your context.
4. **Judge.** Spawn a FRESH subagent using the plugin's `codex-judge` agent + repo path + branch name. Codex's work is UNCOMMITTED — the judge reviews the working tree (`git diff HEAD`), runs every frozen check, checks the bar wasn't moved. Returns PASS or FAIL + evidence.
5. **Resolve.** PASS → you commit (Codex never commits). A PASS certifies the WHOLE working tree the judge saw, so bind the commit to it: run `git diff HEAD --name-only` and stage exactly that list — **never `git add -A`** (executor-side tool noise must not enter the repo), and never a from-memory subset (dropping one needed file ships a branch that fails the very check the PASS certified). After committing, `git status --porcelain` must show nothing but known tool noise. Then report in plain language. FAIL → re-brief via the same stdin rule as step 3 (never interpolate the fix text into the command line):

   ```
   codex exec resume <session-id> - 2>>.codex/codex.err <<'PRAETOR_BRIEF'
   <the re-brief: judge's reasons + what to fix, same frozen bar>
   PRAETOR_BRIEF
   ```

   Use the session id captured at dispatch; if you did not capture one, send a fresh full dispatch instead — **never `resume --last`** (it resumes the machine's most recent Codex session and can hijack an unrelated task). Max 2 retries, then loud takeover.
6. **Cleanup.** PASS → ask the user in one line: merge `codex/<slug>` now, or leave the branch for their review — never merge without their word. Before any merge, drop the bar from the branch (`git rm .codex/ACCEPTANCE.md && git commit -m "praetor: drop acceptance bar"`) so `.codex/` never reaches the base branch. FAIL/takeover → **discard the branch's working tree first** (`git checkout -- . && git clean -fd -e .codex` — the rejected work is uncommitted, and `git switch` would otherwise silently carry it onto the base branch), then switch back to the base branch and delete `codex/<slug>`. In ALL outcomes, back on the original branch: restore stashed work if step 1 stashed it (`git stash pop`; if the pop conflicts, halt loud and let the user resolve — never force or drop the stash), then append one line to `.codex/ledger.jsonl` (keep it untracked — a local audit log, not repo content): `{task, model, verdict_history, wall_seconds, dispatched_at}`.

**Kill switch:** a `STOP` file in the repo root halts all dispatching — check before every dispatch.

## Red Flags — excuses that mean STOP

| Excuse | Reality |
|---|---|
| "The diff looks obviously fine, skip the judge" | Obvious diffs are where silent regressions hide. Law 2. |
| "No time to write acceptance criteria" | Then there's no way to know Codex succeeded. Law 1. |
| "One more retry will fix it" | Retry 3+ burns both quotas for a coin flip. Law 3. |
| "Codex said tests pass" | Codex reporting ≠ judge verifying. Only exit codes count. |
| "It's just a small task, skip the branch" | Small tasks on main are how main breaks. Isolate or don't dispatch. |
| "This is obviously delegate-shaped — dispatch even though praetor wasn't summoned" | Dormant means dormant. One one-line offer at most; only a summon activates dispatch. |
| "Better ask permission per task, to be safe" | Once summoned, per-task asking is friction — announce and act. The brakes protect the user, not the asking. |
| "The user vetoed this earlier, but it'd really be faster…" | A veto stands for the session. Pinned means pinned. |
| "The tree is only a little dirty, skip the stash" | The judge would grade the user's WIP and a PASS-commit would swallow it. Stash or stop. |
| "Codex's sandbox blocked `.git` writes — add `.git` to writable roots" | **Never.** `.git` read-only is the sandbox enforcing our own law (Codex never touches git state — writable `.git` = rewritable history and executable hooks). If the task needs git commands, it was never a valid dispatch: do the git work yourself. |
| "This edit task is basically analysis" | If it changes any file, it's a write dispatch. The shortcut is for reading only. |
| "User probably wants this delegated" | Probably ≠ said so. Offer in one line, then drop it. |
