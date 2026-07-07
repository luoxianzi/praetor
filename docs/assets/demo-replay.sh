#!/bin/bash
printf "\033c"; sleep 0.3
G='\033[32m'; R='\033[31m'; Y='\033[33m'; C='\033[36m'; B='\033[1m'; D2='\033[2m'; N='\033[0m'
say(){ printf "$1\n"; sleep "$2"; }
say "${D2}# Claude Code session — praetor installed (replay of real runs; numbers = README table)${N}" 1.2
say "" 0.1
say "${B}you>${N} send this to codex — rename formatDate → formatISODate across src/ (16 files)" 1.6
say "" 0.2
say "${C}praetor${N} preflight ✓ codex 0.142.5 · auth ✓ · no STOP file" 1.0
say "${C}praetor${N} triage: mechanical + checkable → dispatch" 0.9
say "${C}praetor${N} branch ${Y}codex/migrate-formatdate${N} · ACCEPTANCE.md ${B}frozen & committed${N}" 1.2
say "${D2}codex exec gpt-5.5 xhigh --sandbox workspace-write …  (2.6 min — cut)${N}" 1.6
say "${C}judge${N} (fresh context — never saw the plan)" 0.9
say "${C}judge${N} tamper check ✓ · node test.js → ${G}OK exit 0${N} · diff: 16 files, all in scope" 1.4
say "${G}${B}JUDGE: PASS${N} ${D2}(12-point review)${N} → planner commits · ledger +1" 2.2
say "" 0.3
say "${D2}────────────────────────── and the day the law fired ──────────────────────────${N}" 1.4
say "${D2}dispatch attempt #1 … 29 min, zero writes${N}" 1.2
say "${R}${B}⏱ HARD-TIMEOUT LAW: KILLED${N} · logged A-TIMEOUT-KILLED · workspace reset" 1.6
say "${C}praetor${N} retry 1/2 → codex done in 2.6 min → ${G}${B}JUDGE: PASS${N}" 1.6
say "" 0.2
say "and when our own benchmark harness mis-read the rules?" 1.2
say "${R}${B}JUDGE: FAIL${N} — binding. ${B}We fixed the harness, not the verdict.${N}" 2.4
say "" 0.3
say "${B}praetor${N} — command the legion, judge the work.  ${D2}github.com/luoxianzi/praetor${N}" 2.5
