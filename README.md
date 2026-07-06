# praetor

**Claude plans. Codex executes. A judge you can't sweet-talk decides what merges.**

*The Roman praetor held both imperium — the power to command the legions — and the judgment seat. So does this plugin: command the legion, judge the work.*

A Claude Code plugin that lets Claude hand grunt work to the [Codex CLI](https://github.com/openai/codex) — **only when you say so** — with acceptance criteria frozen in git before Codex starts, and an independent fresh-context judge whose FAIL cannot be overridden.

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE) [![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-blueviolet)](https://claude.com/claude-code) [![中文说明](https://img.shields.io/badge/文档-中文-red)](README.zh-CN.md)

---

<!-- HERO-GIF slot (pre-launch asset): vhs terminal recording, ~30s, two acts —
     Act 1 happy path: "send this to codex" → freeze → codex → JUDGE: PASS → merge.
     Act 2 the differentiator: JUDGE: FAIL (red) → retry → FAIL → loud TAKEOVER.
     A PASS-only demo looks like every other delegation plugin; the FAIL act is mandatory. -->

## Why

- **Your Claude tokens should buy judgment, not grunt work.** Bulk edits, mechanical test-writing, wide read-and-report analysis — these burn context and quota that Claude should spend on design and review. Codex runs them in its own process, on its own quota.
- **Delegation without verification is just hope.** In our live testing, roughly **1 in 3 unattended executor runs failed independent review** — that's the work you'd otherwise have merged. So nothing merges here without a verdict.
- **You stay in charge.** This plugin never auto-dispatches. Claude may *offer* ("this looks Codex-shaped — want me to dispatch it?") — the work only moves when you say yes.

## Install

```
/plugin install praetor
```

That's it. **Zero configuration.** Idle footprint: **~313 always-on tokens** — that is the entire cost until the moment you dispatch. If `codex login` works on your machine, dispatch works. No config file, no wizard, no API keys handed to us — the plugin only shells out to your own authenticated Codex CLI.

Requirements: [Claude Code](https://claude.com/claude-code) + [Codex CLI](https://github.com/openai/codex) (`npm i -g @openai/codex`, then `codex login`).

## Use

Say it in plain language, or use the command:

```
"send this to codex"  ·  "delegate the refactor to codex"  ·  "交给codex"

/praetor:delegate migrate all date formatting in src/ from moment to dayjs
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

**Three iron laws — no exceptions:**

1. **No dispatch without a frozen bar in git.**
2. **No acceptance without the judge.** A FAIL cannot be overridden — not by Claude, not by a persuasive diff.
3. **Max 2 retries, then loud takeover.** Every failure path ends with Claude doing the work and telling you delegation failed.

Silent failure is treated as the #1 killer of tools like this. It has no path here.

## Measured, not promised

Real numbers from repeated local runs are published here before anything else is claimed. Each row: one task class, wall-clock and token cost of *dispatch vs. Claude doing it directly*, and the judge's first-pass verdict rate:

| Task class | Claude solo | Dispatched | Verdict |
|---|---|---|---|
| Bulk mechanical edit — API rename across 16 files | ~1 min | ~4 min (2.6 min Codex + 1.4 min judge) | **Judge: PASS first try** (12-point review) — merged without reading the diff |
| Tiny task — one-line function | seconds | 1.7 min — and the 1st attempt died at the 4-min timeout | **Don't dispatch small tasks.** The skill says so before you waste the minutes |
| Unplanned bonus: transient stall | — | one 29-min zero-write hang → killed by the timeout law → retry succeeded in 2.6 min | **Loud takeover, never silent failure** — the law fired in real life |

First published runs — n=1 per arm, synthetic fixtures, one machine; medians replace these as repetitions accumulate. Full honesty: **2 of 4 dispatch attempts stalled** on our test machine and were killed by the hard timeout; both retries succeeded, and the judge passed delivered work on the first review. Wall-clock favors solo on small fixtures — dispatch pays in **quota shift and verified merges**, not raw speed.

Dispatch has real overhead (branch + freeze + judge). Small tasks are **faster without it** — the skill says so instead of dispatching anyway.

## How praetor differs

Other Claude↔Codex bridges exist and are good at what they do. The factual difference:

| | Who decides to dispatch | What verifies the output | Config required |
|---|---|---|---|
| **praetor** | You, explicitly — never auto | Fresh-context judge; FAIL is binding | None (~313 tokens idle) |
| [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | You, via /codex commands | You read the result | Codex CLI auth |
| [skill-codex](https://github.com/skills-directory/skill-codex) | Claude, when the skill triggers | You read the result | Codex CLI + model prompts |
| [architect-loop](https://github.com/DanMcInerney/architect-loop) | Automatic within the loop | Gates + review inside the loop | Installer + orchestration setup |

## Relay / custom model users

Already pointing your Codex CLI at a relay or another model via `~/.codex/config.toml`? **It just works** — preflight detects a custom provider and respects your config instead of forcing flags. The judge protects quality regardless of the executor: a weaker model means more takeovers, never silently bad merges.

Officially recommended and tested path: **Codex `gpt-5.5` at `xhigh` effort.** Everything else: supported, not certified.

Escape hatches (that's all of them): `PRAETOR_MODEL` / `PRAETOR_EFFORT` env vars, and plain language — "don't send this to codex", "stop delegating for now". A `STOP` file in the repo root halts everything.

## FAQ

**What leaves my machine, and what do you see?** Nothing comes to us. The plugin shells out to your own authenticated Codex CLI — your keys, your relay, your quota.

**What happens when Codex fails?** ≤2 retries against the frozen criteria, then Claude loudly takes over and does the work itself. There is no silent-failure path.

**Can I (or Claude) override a FAIL?** No. That is the product. If you want an overridable judge, [docs/DESIGN.md](docs/DESIGN.md) explains why we won't build one.

**Will it ever dispatch without me asking?** Never. Claude may offer; the work moves only when you say yes.

## What's deliberately NOT here

No config file. No model picker. No concurrency knobs. No background daemon. No dashboards. Retries are fixed at 2 — it's a tested law, not a preference. Every one of these was cut on purpose; see [docs/DESIGN.md](docs/DESIGN.md) before filing the issue. 🙂

## License

MIT
