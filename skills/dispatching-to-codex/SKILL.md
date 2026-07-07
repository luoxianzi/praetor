---
name: dispatching-to-codex
description: Use when the user explicitly asks to hand a task to Codex — "use codex", "delegate this", "send it to codex", "交给codex", "派给codex", or the /delegate command. Runs the full dispatch lifecycle with frozen acceptance criteria and a binding independent judge. NEVER auto-dispatch — delegation happens only on the user's word. If a task looks Codex-shaped (bulk mechanical edits, wide read-and-report analysis, test scaffolding), you may offer the option in ONE line; if the user doesn't take it, drop it.
---

# Dispatching to Codex

Claude is the brain; Codex is the hands. You plan, freeze the bar, and judge. Codex executes on its own quota, in its own process, so your context stays small and your tokens go to judgment — not grunt work.

## Iron Laws (no exceptions)

1. **NO DISPATCH WITHOUT FROZEN ACCEPTANCE CRITERIA COMMITTED TO GIT.** If you cannot write a concrete pass/fail check, the task is not ready to delegate — do it yourself.
2. **NO ACCEPTANCE WITHOUT A FRESH-CONTEXT JUDGE VERDICT.** A FAIL cannot be overridden — not by you, not by "the diff looks fine".
3. **MAX 2 RETRIES, THEN LOUD TAKEOVER.** Every failure path ends with you doing the work and telling the user delegation failed. Silent success is forbidden.

## Is it worth dispatching? (say so BEFORE starting)

Dispatch overhead is real: branch + freeze + judge ≈ 2–5 minutes of wall-clock (measured ~4 min; see the README benchmark table) plus some of both quotas. Rule of thumb: a task you could finish in under ~5 minutes is not worth dispatching. If so, tell the user plainly: *"This is faster for me to do directly — still want Codex on it?"* Then respect their answer.

Good dispatches: bulk/repetitive edits, migrations, mechanical test-writing against a clear spec, wide "read everything, report back" analysis, output-heavy runs.
Bad dispatches: design work, subtle debugging, anything ambiguous, tiny tasks, and **any git-state operation** (branching, pulling, merging, rebasing, committing) — git is the planner's own hands; Codex edits files, never git state. Codex's sandbox keeps `.git/` read-only in `workspace-write` for exactly this reason.

## Lifecycle

0. **Preflight.** Run `${CLAUDE_SKILL_DIR}/preflight.sh`. `not-ready` → one-line explanation (e.g. "run `codex login` once and I can dispatch"), then do the work yourself. Never nag twice in a session. If it reports `git=no`, only the analysis-only shortcut below is available — for any write dispatch, say that write dispatches need a git repo and do the work yourself.

**Analysis-only shortcut:** if the dispatch edits NO files (wide read-and-report, investigation), skip ISOLATE/FREEZE/JUDGE — run `codex exec --sandbox read-only` (brief via stdin as in step 3) and review the report yourself. The gate exists for merges, not for reading. After the run, `git status --porcelain` must be empty (belt over the sandbox); if anything changed, discard it (`git checkout -- . && git clean -fd`) and restart on the full write path. Everything below is the write path.

1. **Isolate.** If `git status --porcelain` is non-empty, first `git stash push -u -m "praetor-<slug>"` and tell the user in one line that their uncommitted work is stashed and will be restored after. Then `git switch -c codex/<slug>` (branch already exists → append `-2`) — throwaway branch; main is never touched.
2. **Freeze.** Write `.codex/ACCEPTANCE.md`: one-line GOAL + the exact commands that must pass (exit codes, not vibes). Commit it BEFORE Codex exists. See skills/writing-codex-briefs for the format.
3. **Brief + dispatch.** Self-contained brief (Codex sees zero chat history). Pass the brief via **stdin with a quoted heredoc** — never interpolate it into the command line (quotes/backticks in task text would break the shell or inject):

   ```
   codex exec -m gpt-5.5 -c model_reasoning_effort="xhigh" --sandbox workspace-write - 2>/dev/null <<'PRAETOR_BRIEF'
   <the brief>
   PRAETOR_BRIEF
   ```

   Model/effort overrides, in priority order: `PRAETOR_MODEL` / `PRAETOR_EFFORT` env vars (use verbatim if set) → preflight reported `config=custom` (active relay provider: DROP the `-m`/`-c` flags, keep `--sandbox`, respect their config) → stock default above. Never `danger-full-access`.
   **Hard timeout:** run the dispatch through your shell tool's timeout at 600000 ms (10 min) — never unbounded. Timeout fired → record `A-TIMEOUT-KILLED` in the verdict history, reset the tree (`git checkout -- . && git clean -fd -e .codex`), and retry; a timeout consumes one of the 2 retries (Law 3).
   Note the **session id** Codex prints at dispatch start — you need it for retries. Big output → `-o <file>`, never into your context.
4. **Judge.** Spawn a FRESH subagent using the plugin's `codex-judge` agent + repo path + branch name. Codex's work is UNCOMMITTED — the judge reviews the working tree (`git diff HEAD`), runs every frozen check, checks the bar wasn't moved. Returns PASS or FAIL + evidence.
5. **Resolve.** PASS → you commit (Codex never commits) and report in plain language. FAIL → re-brief via the same stdin rule as step 3 (never interpolate the fix text into the command line):

   ```
   codex exec resume <session-id> - 2>/dev/null <<'PRAETOR_BRIEF'
   <the re-brief: judge's reasons + what to fix, same frozen bar>
   PRAETOR_BRIEF
   ```

   Use the session id captured at dispatch; if you did not capture one, send a fresh full dispatch instead — **never `resume --last`** (it resumes the machine's most recent Codex session and can hijack an unrelated task). Max 2 retries, then loud takeover.
6. **Cleanup.** PASS → ask the user in one line: merge `codex/<slug>` now, or leave the branch for their review — never merge without their word. Before any merge, drop the bar from the branch (`git rm .codex/ACCEPTANCE.md && git commit -m "praetor: drop acceptance bar"`) so `.codex/` never reaches the base branch. FAIL/takeover → switch back to the base branch and delete `codex/<slug>`. In ALL outcomes, back on the original branch: restore stashed work if step 1 stashed it (`git stash pop`), then append one line to `.codex/ledger.jsonl` (keep it untracked — a local audit log, not repo content): `{task, model, verdict_history, wall_seconds, dispatched_at}`.

**Kill switch:** a `STOP` file in the repo root halts all dispatching — check before every dispatch.

## Red Flags — excuses that mean STOP

| Excuse | Reality |
|---|---|
| "The diff looks obviously fine, skip the judge" | Obvious diffs are where silent regressions hide. Law 2. |
| "No time to write acceptance criteria" | Then there's no way to know Codex succeeded. Law 1. |
| "One more retry will fix it" | Retry 3+ burns both quotas for a coin flip. Law 3. |
| "Codex said tests pass" | Codex reporting ≠ judge verifying. Only exit codes count. |
| "It's just a small task, skip the branch" | Small tasks on main are how main breaks. Isolate or don't dispatch. |
| "The tree is only a little dirty, skip the stash" | The judge would grade the user's WIP and a PASS-commit would swallow it. Stash or stop. |
| "Codex's sandbox blocked `.git` writes — add `.git` to writable roots" | **Never.** `.git` read-only is the sandbox enforcing our own law (Codex never touches git state — writable `.git` = rewritable history and executable hooks). If the task needs git commands, it was never a valid dispatch: do the git work yourself. |
| "This edit task is basically analysis" | If it changes any file, it's a write dispatch. The shortcut is for reading only. |
| "User probably wants this delegated" | Probably ≠ said so. Offer in one line, then drop it. |
