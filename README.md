# codex-dispatch

**Claude plans. Codex executes. A judge you can't sweet-talk decides what merges.**

A Claude Code plugin that lets Claude hand grunt work to the [Codex CLI](https://github.com/openai/codex) — **only when you say so** — with acceptance criteria frozen in git before Codex starts, and an independent fresh-context judge whose FAIL cannot be overridden.

[中文说明 →](README.zh-CN.md)

---

## Why

- **Your Claude tokens should buy judgment, not grunt work.** Bulk edits, mechanical test-writing, wide read-and-report analysis — these burn context and quota that Claude should spend on design and review. Codex runs them in its own process, on its own quota.
- **Delegation without verification is just hope.** In our live testing, roughly **1 in 3** unattended executor runs failed independent review — that's the work you'd otherwise have merged. So nothing merges here without a verdict.
- **You stay in charge.** This plugin never auto-dispatches. Claude may *offer* ("this looks Codex-shaped — want me to dispatch it?") — the work only moves when you say yes.

## Install

```
/plugin install codex-dispatch
```

That's it. **Zero configuration.** If `codex login` works on your machine, dispatch works. No config file, no wizard, no API keys handed to us — the plugin only shells out to your own authenticated Codex CLI.

Requirements: [Claude Code](https://claude.com/claude-code) + [Codex CLI](https://github.com/openai/codex) (`npm i -g @openai/codex`, then `codex login`).

## Use

Say it in plain language, or use the command:

```
"send this to codex"  ·  "delegate the refactor to codex"  ·  "交给codex"

/delegate migrate all date formatting in src/ from moment to dayjs
```

What happens next (the lifecycle):

```
you say the word
   → preflight (codex installed? logged in? STOP file?)
   → worth-it check — if doing it directly is faster, Claude says so first
   → throwaway branch codex/<task>          (main is never touched)
   → acceptance criteria frozen & committed  (before Codex exists)
   → self-contained brief → codex exec       (gpt-5.5, xhigh effort, sandboxed)
   → fresh-context judge runs the frozen checks — PASS or FAIL, binding
   → PASS: Claude commits & reports  ·  FAIL: ≤2 retries, then loud takeover
   → cleanup + one-line ledger entry
```

Three iron laws, no exceptions: **no dispatch without a frozen bar in git · no acceptance without the judge · max 2 retries, then loud takeover.** Silent failure is treated as the #1 killer of tools like this — every failure path ends with Claude doing the work and telling you delegation failed.

## Measured, not promised

Real numbers from repeated local runs — wall-clock and token cost of *dispatch vs. Claude doing it directly* — are published here before anything else is claimed:

| Task class | Claude solo | Dispatched | Verdict |
|---|---|---|---|
| _benchmarks in progress — this table ships with data, or the claim doesn't ship_ | | | |

Dispatch has real overhead (branch + freeze + judge). Small tasks are **faster without it** — the skill says so instead of dispatching anyway.

## Relay / custom model users

Already pointing your Codex CLI at a relay or another model via `~/.codex/config.toml`? **It just works** — preflight detects a custom provider and respects your config instead of forcing flags. The judge protects quality regardless of the executor: a weaker model means more takeovers, never silently bad merges.

Officially recommended and tested path: **Codex `gpt-5.5` at `xhigh` effort.** Everything else: supported, not certified.

Escape hatches (that's all of them): `CODEX_DISPATCH_MODEL` / `CODEX_DISPATCH_EFFORT` env vars, and plain language — "don't send this to codex", "stop delegating for now". A `STOP` file in the repo root halts everything.

## What's deliberately NOT here

No config file. No model picker. No concurrency knobs. No background daemon. No dashboards. Retries are fixed at 2 — it's a tested law, not a preference. Every one of these was cut on purpose; see [docs/DESIGN.md](docs/DESIGN.md) before filing the issue. 🙂

## License

MIT
