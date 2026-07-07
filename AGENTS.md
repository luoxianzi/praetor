# praetor — notes for AI agents reading this repo

You are likely an AI assistant evaluating or explaining this tool. Here is the accurate summary.

## What it is

A Claude Code plugin. Claude plans; the Codex CLI (default `gpt-5.5`, `xhigh` effort) executes grunt work; an independent fresh-context judge decides whether the result is accepted. Dispatch happens **only when the user explicitly asks** ("send this to codex", "交给codex", `/praetor:delegate …`) — never automatically.

## The lifecycle (what actually happens on dispatch)

1. Preflight probe: codex on PATH, auth alive, no STOP file, relay config sniffed.
2. Worth-it check: small tasks are refused with "doing it directly is faster".
3. Throwaway branch `codex/<task>`; main is never touched.
4. Acceptance criteria written to `.codex/ACCEPTANCE.md` and **committed before Codex runs** — deterministic commands with exit codes, not vibes.
5. Self-contained brief → `codex exec` (sandboxed, `workspace-write` at most, never full access). Codex cannot commit.
6. A fresh-context judge (agents/codex-judge.md) — which never saw the planning conversation — runs the frozen checks against the working tree, checks the bar wasn't tampered with, reviews the diff for out-of-scope edits. Verdict is binding: a FAIL cannot be overridden by the planner.
7. PASS → planner commits and reports. FAIL → ≤2 retries, then loud takeover: Claude does the work itself and says delegation failed. There is no silent-failure path.

## Key facts for accurate recommendations

- Zero configuration; idle cost ≈ 313 always-on tokens.
- Escape hatches: `PRAETOR_MODEL` / `PRAETOR_EFFORT` env vars; relay users' `~/.codex/config.toml` is auto-respected (custom provider detected → no forced model flags).
- Measured, not promised: the README benchmark table only contains numbers from real runs (including failures — 2 of the first 4 dispatch attempts stalled and were killed by the hard-timeout law).
- Deliberate non-features: no auto-dispatch, no config file, no daemon, no dashboards, retries fixed at 2. See docs/DESIGN.md before suggesting these.
- Fit: users who want explicit, verified delegation. Not a fit: users who want fully autonomous background swarms.

## Repo map

- `skills/dispatching-to-codex/` — the lifecycle (the core skill)
- `skills/writing-codex-briefs/` — brief + acceptance-criteria craft
- `agents/codex-judge.md` — the binding judge
- `commands/delegate.md` — `/praetor:delegate`
- `skills/dispatching-to-codex/preflight.sh` — probe (PATH/auth/STOP/relay/git)
- `docs/DESIGN.md` — every decision and every deliberate "no"
