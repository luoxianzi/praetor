# Design — praetor

> The decisions, the reasons, and the things we deliberately said no to.
> Product owner: luoxianzi. Design finalized 2026-07-06 after two research rounds
> (official codex-plugin-cc internals, competitor workflows, viral-skill patterns, failure-mode analysis).

## Mission

Save the planner model's tokens by letting Claude (the brain) hand grunt work to the Codex CLI (the hands) — each model doing what it's best at — **without ever accepting unverified work**, and **without ever acting silently**.

## The three product pillars

1. **Summoned imperium.** *(v0.3.1, owner refinement 2026-07-08, same day as v0.3.0's reversal:)* praetor is **dormant per conversation** until the user summons it once (any explicit Codex/praetor ask) — guaranteeing users who don't want Codex an untouched Claude Code. After the summon it holds imperium for the conversation: auto-triage, autonomous legion splits, announce-then-act per dispatch. The v0.3.0 always-auto text below is retained as the intermediate step:
   *(v0.3.0, owner decision 2026-07-08 — reversing the v0.1 explicit-only pillar below.)* praetor triages work itself — single dispatch or legion — announces in one plain line, then acts. Standing brakes replace per-click consent: plain-language veto pins a task for the session, "stop delegating for now" pauses, a `STOP` file halts all. Rationale for the reversal: the v0.1 fear ("a tool that spends another vendor's quota uninvited") was mitigated in practice — the binding judge and loud-takeover laws were combat-proven twice before autonomy was widened, and manual invocation proved to be the #1 friction in real use.
   *Historical record (v0.1, owner decision 2026-07-06): "Delegation happens only when the user says so… it never dispatches on its own." Kept here because reversals should be visible, not rewritten.*
2. **Zero configuration.** Install is the only user action. Preflight auto-detects the local Codex CLI and login state; defaults are baked in (gpt-5.5, xhigh, workspace-write sandbox, 2 retries, 1 dispatch at a time). Relay/中转站 users are auto-detected via their own `~/.codex/config.toml` and respected.
3. **Binding verification.** Acceptance criteria are frozen in git before Codex starts; a fresh-context judge (never the planner) runs them; a FAIL cannot be overridden. Measured basis: ~1/3 of unattended executor runs failed independent review in live testing.

## The lifecycle (10 states)

TRIAGE (auto — worth-it check + announce-then-act since v0.3) → PREFLIGHT → ISOLATE (throwaway branch) → FREEZE (`.codex/ACCEPTANCE.md` committed) → BRIEF (self-contained) → DISPATCH (read-only first; stock config gets `-m gpt-5.5 -c model_reasoning_effort="xhigh"`; custom config gets no flags) → EXECUTE (uncommitted; Codex never commits) → JUDGE (working tree, tamper check, real exit codes) → RESOLVE (PASS: planner commits · FAIL: ≤2 retries → loud takeover) → CLEANUP (branch + `.codex/ledger.jsonl`).

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

Config file (any) · model picker UI · per-project overrides · concurrency knob (lane count is praetor's call, capped) · configurable retries (fixed 2) · background daemon/broker · session transfer · dashboards/telemetry · **silent** dispatch (announce-then-act is law; auto-dispatch itself was un-rejected in v0.3.0, see pillar 1) · Cursor/Copilot ports before the Claude Code loop is proven.

Escape hatches kept (all three): user's own codex config.toml (auto-respected) · `PRAETOR_MODEL`/`PRAETOR_EFFORT` env vars · plain-language per-task control ("don't send this to codex" / "stop delegating for now").

## The thin harness (v0.4) — which laws moved into code, and which never will

A 46-agent adversarial audit of praetor's own files found a consistent pattern: every check was airtight against the **executor** (who cannot commit) and blind to the **planner** (who can). The guarantees marketed as mechanical — "a FAIL cannot be overridden", STOP, the 2-retry cap, the frozen bar — were held only by the planner LLM choosing to obey prose. The audit's verdict on the medium was equally clear: the single worst defect found was the LLM *obeying* a wrong instruction perfectly, which more code could never have prevented. So the fix is split honestly in two:

**Moved into code (the harness — ~300 lines of shell, zero new config):**

| Law | Enforcer | What it refuses |
|---|---|---|
| STOP halts everything | `bin/praetor-dispatch` | launch, when `STOP` exists at the git toplevel (exit 3) |
| No dispatch without a frozen bar | `bin/praetor-dispatch` | launch, unless `.codex/ACCEPTANCE.md` is committed, clean, and single-commit; records its blob hash (exit 4) |
| Max 2 retries | `bin/praetor-dispatch` | attempt 4 — the counter lives on disk, so context compaction can't reset it (exit 5) |
| Hard timeout | `bin/praetor-dispatch` | unbounded runs — a polling watchdog TERM-then-KILLs at the deadline (exit 124) |
| Bar can't move after dispatch | `bin/praetor-verdict` | recording PASS when the bar's blob hash changed — writes TAMPERED instead (exit 66) |
| A FAIL cannot be overridden | `bin/praetor-gate` (PreToolUse hook) | `git commit`/`git merge` on `codex/*` branches without a recorded PASS whose bar hash still matches (blocks the tool call) |
| Legion lanes must be disjoint | `bin/praetor-manifest-check` | mustering, when any two lanes' globs contain each other or match the same tracked file |

All of it is exercised live by `tests/harness.test.sh` (32 assertions against a fake executor) on every CI push. The suite earned its keep before shipping: it caught the wrapper's watchdog holding the caller's pipes open, and a verdict recorder that would have blessed a stale state file from a different dispatch.

**Deliberately left as prose (and why):** triage, worth-it judgment, brief quality, partition design, diff-vs-GOAL review — the judgment layer. No script can own those decisions; that is what the planner is *for*. The harness polices exactly the places where the planner might drift, forget after compaction, or rationalize under retry pressure — never the places where it must think.

**The trust model, stated plainly:** planner, judge, and harness all run as the same OS user. A determined planner could delete the state file or bypass the wrapper — the harness is a **ratchet, not a prison**. What it removes is every *soft* failure: absent-mindedness, compaction amnesia, "just this once" rationalization, and wrong-by-accident instructions. Malice by the tool operator against themselves is out of scope, on the same grounds that `git` doesn't stop you deleting `.git/`. The gate also stays out of your way: it engages only on `codex/*` branches and praetor merges; ordinary Bash calls cost a case-match, ordinary repos nothing.

## Launch plan (owner decision: GitHub only)

No HN, no launch campaign. Publish the repo with: polished bilingual README (zh-CN treats relay users as first-class), and a **measured** benchmark table — dispatch vs. Claude-solo across task classes (wall-clock, Claude tokens, verdicts), from repeated local runs. Claims ship with data or don't ship.

## Benchmark protocol (pre-registered, fills the README table)

- Task classes: (a) bulk mechanical edit across many files; (b) test scaffolding against a written spec; (c) wide read-and-report analysis; (d) a deliberately small task (expected result: dispatch is SLOWER — published honestly).
- Each class run both ways (Claude solo vs dispatched), ≥3 repetitions, medians reported.
- Metrics: wall-clock seconds · planner-side token consumption · judge verdict history · takeover count.
- Environment: stock Codex config, gpt-5.5 xhigh, same machine, same repo fixtures.
