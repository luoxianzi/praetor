# praetor tutorial — your first dispatch in 10 minutes

Everything below uses real artifacts from praetor's own benchmark runs — the same runs behind the README table. Nothing is mocked.

## 0. What you need

- [Claude Code](https://claude.com/claude-code) installed and signed in
- [Codex CLI](https://github.com/openai/codex): `npm i -g @openai/codex`, then `codex login`
- Verify both: `claude --version` and `codex --version` print versions; `codex login status` says logged in

That's the entire setup. praetor itself needs zero configuration. (Windows: everything runs under Git Bash or WSL, same as Claude Code itself.)

## 1. Install

```
/plugin marketplace add luoxianzi/praetor
/plugin install praetor@praetor
```

Check it landed: `/plugin` → praetor should list 3 skills (`delegate`, `dispatching-to-codex`, `writing-codex-briefs`) and 1 agent (`codex-judge`). Idle cost from here: ~313 tokens per session, nothing else until you dispatch.

## 2. Your first dispatch, end to end

Open Claude Code **in a git repository** (the lifecycle uses branches — that's your undo button). Pick something mechanical and checkable. Then just say it:

> **you:** send this to codex — rename `formatDate` to `formatISODate` across src/, new signature takes no format argument

Here is what praetor does, step by step, with the real artifacts from this exact task:

**① Preflight** — codex on PATH? logged in? no `STOP` file? relay config detected? Fails loudly if not ready ("run `codex login` once and I can dispatch"), and Claude does the work itself instead.

**② Worth-it check** — dispatch has ~2–5 min of overhead (branch + freeze + judge). For a tiny task Claude will tell you: *"doing this directly is faster — still want to dispatch?"* Respect the answer either way.

**③ Freeze the bar** — praetor creates a throwaway branch `codex/migrate-formatdate` and commits `.codex/ACCEPTANCE.md` **before Codex exists**. The real file from our run:

```markdown
GOAL: Rename formatDate to formatISODate across src/ — new signature
formatISODate(date) always returns YYYY-MM-DD; update utils.js and every call site.

CHECKS (all must pass):
- `node test.js` prints exactly "OK" and exits 0.

CONSTRAINTS:
- Only edit files in src/. Do not modify test.js or this file. Do not commit.
```

This is the whole trick: the definition of done is written down and committed *before* any work exists, so it can never quietly move to fit the result.

**④ Codex executes** — `codex exec` runs sandboxed (`workspace-write` at most, never full access), with a hard timeout, stderr suppressed so its reasoning never floods Claude's context. Codex edits files on the branch; it has no commit rights. In our run: 16 files in 2.6 minutes.

**⑤ The judge** — a *fresh* subagent that never saw the conversation gets only: the branch, the frozen bar, and the diff. It re-runs every check itself and reviews the diff for out-of-scope edits, weakened tests, and stubs. From the real verdict:

```
✓ Acceptance bar not tampered      ✓ node test.js → "OK", exit 0
✓ All changes in src/ only          ✓ Old function completely removed
✓ All 15 call sites updated         ✓ No stubs, fakes, or TODOs introduced
VERDICT: PASS
```

**⑥ Resolve** — on PASS, *Claude* commits (Codex never does) and reports in plain language with the receipts. You just review a one-page summary instead of reading 16 diffs.

## 3. When things fail — the part that makes this trustworthy

Real story from our benchmark day: a dispatch ran **29 minutes with zero file writes** — a genuine stall. The timeout law killed it, logged `A-TIMEOUT-KILLED`, reset the workspace, and retried. The retry finished in 2.6 minutes and passed the judge.

The failure ladder, in order:

1. **Check fails →** judge returns FAIL with evidence. Claude *cannot* override it — not with "the diff looks fine", not ever.
2. **Retry (max 2)** — Claude re-briefs Codex against the *same* frozen bar (`codex exec resume`), targeting the judge's reasons.
3. **Loud takeover** — retries exhausted (or codex is down/rate-limited): Claude does the work itself and says, in so many words, that delegation failed and why.

There is no path where a failure gets quietly presented as success. That's the product.

**Emergency stop:** create a file named `STOP` in the repo root. Every dispatch checks it first.

## 4. Writing acceptance criteria that actually protect you

The judge is only as strong as the bar you freeze. Rules of thumb (the `writing-codex-briefs` skill enforces these):

| Weak (false confidence) | Strong (real protection) |
|---|---|
| "code should work" | `node test.js` prints exactly "OK", exits 0 |
| "typecheck passes" (alone) | typecheck **and** the named tests for the touched area |
| no scope limits | "Only edit files in src/. Do not modify test.js or this file." |

If you can't write a concrete, runnable check — **don't dispatch that task**. That's not a workaround; it's the design.

## 5. Relay / custom model users (中转站)

Already routing Codex through a relay in `~/.codex/config.toml`? It just works — preflight detects a custom provider and drops praetor's default flags (`gpt-5.5`, `xhigh`) so your config wins. A weaker model simply means more takeovers, never silently bad merges.

```toml
# ~/.codex/config.toml — standard relay setup, nothing praetor-specific
model_provider = "myrelay"
[model_providers.myrelay]
base_url = "https://your-relay.example/v1"
env_key  = "MYRELAY_API_KEY"
```

Overrides without any config file: `PRAETOR_MODEL` and `PRAETOR_EFFORT` env vars. Official tested path remains **gpt-5.5 at xhigh**; everything else is supported, not certified.

## 6. Day-to-day controls — plain language, no settings

- "**don't send this to codex**" → this task stays with Claude
- "**send this to codex**" → force a dispatch (worth-it check still speaks up)
- "**stop delegating for now**" → session-wide pause
- `STOP` file in repo root → hard stop for everything

## 7. Troubleshooting

| Symptom | Cause → fix |
|---|---|
| "codex CLI not found" | Not on PATH → `npm i -g @openai/codex` |
| "codex not logged in" | Auth expired → `codex login` once |
| Dispatch killed by timeout | Stall (network/relay hiccup) → praetor already retried; if repeated, check relay/proxy |
| Judge FAIL: "check could not run" | Broken env (deps not installed) — a FAIL by design; install deps, re-dispatch |
| Relay returns 400 on model name | Your relay maps names differently → praetor already drops model flags on custom config; check `model` in your config.toml |
| Codex fails: `.git` is read-only | Working as designed — the sandbox (and praetor's law) keeps git state out of Codex's hands. If the task itself is git work (branch/pull/merge), don't dispatch it: that's Claude's own job. Never add `.git` to writable roots |
| Everything works but feels slow on small tasks | Working as intended — the worth-it check told you; small tasks are faster solo |

## 8. Contribute your numbers

The README table grows from n=1 to medians through reports like yours: [file a benchmark report](https://github.com/luoxianzi/praetor/issues/new?template=benchmark-report.yml) with timings and the verdict. Failures are as welcome as successes — that's the house style.
