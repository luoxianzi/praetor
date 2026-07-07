# Contributing to praetor

Thanks for stopping by. This project has an unusual contribution policy, stated up front so nobody wastes an evening.

## What lands here

- **Benchmark runs.** Run the protocol in [docs/DESIGN.md](docs/DESIGN.md), post your numbers in an issue. Medians replace our n=1 table as repetitions accumulate — this is the single most valuable contribution right now.
- **Real-run transcripts.** A dispatch that went well, went sideways, or got saved by the judge — redacted terminal transcripts make the best documentation in this genre.
- **The hero GIF.** Storyboard lives in a comment at the top of [README.md](README.md). vhs script preferred.
- **Judge improvements.** Sharper diff review, better FAIL diagnostics (broken-env vs broken-work), tamper-check hardening.
- **Prompt/skill wording fixes.** The skills are the product. Tighter, clearer, shorter always wins.
- **Chinese docs parity.** README.zh-CN.md is a transcreation, not a translation — keep its register.

## What does not land here (policy, not oversight)

No config file. No model picker UI. No concurrency knobs. No configurable retry count. No background daemon. No dashboards. No auto-dispatch mode.

Every one of these was cut deliberately — the reasoning is in [docs/DESIGN.md](docs/DESIGN.md). PRs adding them will be closed with a link to this paragraph, with gratitude and without exception. (If real-world usage proves one of these wrong, open a Discussion with your ledger data — evidence moves us, votes don't.)

## Ground rules for changes

1. **The three iron laws are product law.** No edit may weaken: frozen bar before dispatch · binding judge · max-2-retries-then-loud-takeover.
2. **Benchmark claims come from measured runs only.** No "should", no "probably", no numbers without a transcript.
3. **READMEs stay in sync.** The EN benchmark table is the source of truth; zh mirrors it.
4. **Keep skills hot-path short.** Reference detail goes to docs/, not into SKILL.md.

## Testing a change

```
claude plugin marketplace add /path/to/your/clone
claude plugin install praetor@praetor
# then in a scratch git repo: "send this to codex — <some small mechanical task>"
```

A change is done when a real dispatch completes the full lifecycle: freeze → execute → judge → resolve.

## Response time

Issues and PRs get a reply within ~a day. If we're slower, ping the thread.
