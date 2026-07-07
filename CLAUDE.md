# CLAUDE.md — working on the praetor repo

This repo IS the product: markdown skills + one shell script. There is no build step.

Rules that override default instincts:

1. **The three iron laws are product law** — frozen bar before dispatch · binding judge (FAIL cannot be overridden) · max 2 retries then loud takeover. Never soften them in any edit, example, or doc.
2. **No config knobs.** The cut list in docs/DESIGN.md (config file, model picker, concurrency knob, retry knob, daemon, dashboards, **silent** dispatch) is policy. Do not add these even if asked casually — point to CONTRIBUTING.md. Consent model since v0.3 is **announce-then-act**: never weaken the one-line announcement or the standing brakes (plain-language veto, STOP file).
3. **Benchmark numbers only from real measured runs.** Never edit the README table without a transcript behind every number. EN table is the source of truth; README.zh-CN.md mirrors it.
4. **zh README is a transcreation.** Keep its register (e.g. "不吃人情的验收员", "实测，不吹牛"); don't flatten it into literal translation. Structural divergence is intentional: 中转站 section sits higher in zh.
5. **Skills stay short.** Hot-path SKILL.md files stay lean; heavy reference goes to docs/. Descriptions follow "Use when…" trigger style, third person.
6. **Test = real dispatch.** After changing a skill, install from local path and run one real delegation in a scratch git repo through the full lifecycle before claiming it works.

See AGENTS.md for the product summary, docs/DESIGN.md for every decision.
