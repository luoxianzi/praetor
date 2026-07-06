# Design — praetor

> The decisions, the reasons, and the things we deliberately said no to.
> Product owner: luoxianzi. Design finalized 2026-07-06 after two research rounds
> (official codex-plugin-cc internals, competitor workflows, viral-skill patterns, failure-mode analysis).

## Mission

Save the planner model's tokens by letting Claude (the brain) hand grunt work to the Codex CLI (the hands) — each model doing what it's best at — **without ever accepting unverified work**, and **without ever acting unasked**.

## The three product pillars

1. **Explicit, human-friendly invocation.** Delegation happens only when the user says so ("交给codex" / "send to codex" / `/delegate`). Claude may offer the option in one line when work looks Codex-shaped; it never dispatches on its own. *Rationale: users fear a tool that spends another vendor's quota uninvited. Owner decision 2026-07-06, overriding the researched "auto-by-default" option.*
2. **Zero configuration.** Install is the only user action. Preflight auto-detects the local Codex CLI and login state; defaults are baked in (gpt-5.5, xhigh, workspace-write sandbox, 2 retries, 1 dispatch at a time). Relay/中转站 users are auto-detected via their own `~/.codex/config.toml` and respected.
3. **Binding verification.** Acceptance criteria are frozen in git before Codex starts; a fresh-context judge (never the planner) runs them; a FAIL cannot be overridden. Measured basis: ~1/3 of unattended executor runs failed independent review in live testing.

## The lifecycle (10 states)

TRIAGE (worth-it check, explicit ask only) → PREFLIGHT → ISOLATE (throwaway branch) → FREEZE (`.codex/ACCEPTANCE.md` committed) → BRIEF (self-contained) → DISPATCH (read-only first; stock config gets `-m gpt-5.5 -c model_reasoning_effort="xhigh"`; custom config gets no flags) → EXECUTE (uncommitted; Codex never commits) → JUDGE (working tree, tamper check, real exit codes) → RESOLVE (PASS: planner commits · FAIL: ≤2 retries → loud takeover) → CLEANUP (branch + `.codex/ledger.jsonl`).

Kill switch: `STOP` file in repo root, checked by preflight before every dispatch.

## What we borrowed, and from whom

- **superpowers** (packaging): Iron Laws with no-exceptions clauses, excuse/reality Red Flags tables, "Use when..." trigger descriptions, tight hot-path skills. Standalone repo, ecosystem-compatible — not a superpowers PR (their contribution policy rejects domain skills).
- **openai/codex-plugin-cc** (mechanics): size-aware dispatch, model/effort flag pass-through, one-transport-retry-then-fallback. We deliberately did NOT copy its broker/daemon/background jobs for v0.1.
- **architect-loop** (discipline): frozen gates + fresh judge + planner-cannot-override, slimmed from a factory to a single-dispatch loop.

## Failure-mode → design answer

| Killer | Answer |
|---|---|
| Silent failure looking like success (#1) | Every failure path ends in loud takeover; judge runs real commands; "check couldn't run" = FAIL with diagnosis |
| Vendor CLI drift | Preflight probes version/auth per session; failure makes the plugin inert, never blocking |
| Retry loops draining both quotas | Retries hard-capped at 2; ledger makes cost visible |
| Weak acceptance checks (sneakiest) | writing-codex-briefs teaches red-before-green checks; judge also reviews diff-vs-GOAL, not just exit codes |
| Overhead on small tasks | Worth-it check speaks up before dispatching; benchmark table publishes the real overhead |
| Simplicity erosion via feature requests | The rejected list below is policy, pre-written |

## Deliberately rejected (do not re-open casually)

Config file (any) · model picker UI · per-project overrides · concurrency knob (fixed 1) · configurable retries (fixed 2) · background daemon/broker · session transfer · dashboards/telemetry · auto-dispatch mode · Cursor/Copilot ports before the Claude Code loop is proven.

Escape hatches kept (all three): user's own codex config.toml (auto-respected) · `PRAETOR_MODEL`/`PRAETOR_EFFORT` env vars · plain-language per-task control ("don't send this to codex" / "stop delegating for now").

## Launch plan (owner decision: GitHub only)

No HN, no launch campaign. Publish the repo with: polished bilingual README (zh-CN treats relay users as first-class), and a **measured** benchmark table — dispatch vs. Claude-solo across task classes (wall-clock, Claude tokens, verdicts), from repeated local runs. Claims ship with data or don't ship.

## Benchmark protocol (pre-registered, fills the README table)

- Task classes: (a) bulk mechanical edit across many files; (b) test scaffolding against a written spec; (c) wide read-and-report analysis; (d) a deliberately small task (expected result: dispatch is SLOWER — published honestly).
- Each class run both ways (Claude solo vs dispatched), ≥3 repetitions, medians reported.
- Metrics: wall-clock seconds · planner-side token consumption · judge verdict history · takeover count.
- Environment: stock Codex config, gpt-5.5 xhigh, same machine, same repo fixtures.
