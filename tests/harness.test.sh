#!/usr/bin/env bash
# praetor harness test suite — every law, live, against a fake codex shim.
# Run anywhere: ./tests/harness.test.sh   (CI runs it on every push)
set -u
BIN="$(cd "$(dirname "$0")/../bin" && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/praetor-harness.XXXXXX")"
trap 'rm -rf "$T"' EXIT
PASSN=0; FAILN=0
ok()   { PASSN=$((PASSN+1)); echo "  ok  - $1"; }
bad()  { FAILN=$((FAILN+1)); echo "  FAIL- $1"; }
check(){ # check <desc> <want_rc> <got_rc>
  if [ "$2" = "$3" ]; then ok "$1 (rc=$3)"; else bad "$1 (want rc=$2 got rc=$3)"; fi
}

# ---------- fixtures ----------
rm -rf "$T/repo" "$T/fakebin"
mkdir -p "$T/fakebin"
cat > "$T/fakebin/codex" <<'SHIM'
#!/usr/bin/env bash
echo "session id: FAKE-123" >&2
case "${FAKE_MODE:-ok}" in
  ok)    echo "did the work" ;;
  hang)  sleep 30 ;;
  fail)  echo "boom" >&2; exit 7 ;;
  write) echo dirty > polluted.txt ;;
esac
exit 0
SHIM
chmod +x "$T/fakebin/codex"
export PATH="$T/fakebin:$PATH"

mkdir -p "$T/repo" && cd "$T/repo"
git init -q -b main && git config user.name t && git config user.email t@t
echo hello > tracked.txt && mkdir -p src/alpha src/beta && echo a > src/alpha/a.js && echo b > src/beta/b.js
git add -A && git commit -qm init

echo "== praetor-dispatch =="
# 1. STOP at toplevel refuses
touch STOP
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1; check "STOP refuses dispatch" 3 $?
rm STOP
# 2. write mode off codex/* branch refuses
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1; check "write dispatch off codex/* refused" 4 $?
# 3. codex branch but bar not committed
git switch -qc codex/test
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1; check "no committed bar refused" 4 $?
# 4. frozen bar -> runs, session id captured, attempt 1
mkdir -p .codex && printf 'GOAL: x\nCHECK: true\n' > .codex/ACCEPTANCE.md
git add .codex/ACCEPTANCE.md && git commit -qm freeze
OUT=$(echo brief | "$BIN/praetor-dispatch" 2>/dev/null); RC=$?
check "frozen bar dispatch runs" 0 $RC
echo "$OUT" | grep -q 'session-id: FAKE-123' && ok "session id captured" || bad "session id captured"
echo "$OUT" | grep -q 'attempt: 1/3' && ok "attempt 1 recorded" || bad "attempt 1 recorded"
# 5. attempts 2,3 run; attempt 4 refused
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1; check "attempt 4 refused (Law 3 in code)" 5 $?
# 6. amended bar -> refused even with attempts left
git switch -q main && git switch -qc codex/amend
printf 'GOAL: y\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1   # attempt 1, records blob
printf 'GOAL: weakened\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -q --amend -m freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1; check "amended bar refused at dispatch (D4)" 4 $?
# 7. timeout kills a hung executor
git switch -q main && git switch -qc codex/hang
printf 'GOAL: z\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
S=$(date +%s); echo brief | PRAETOR_TIMEOUT=2 FAKE_MODE=hang "$BIN/praetor-dispatch" >/dev/null 2>&1; RC=$?; E=$(( $(date +%s) - S ))
check "timeout kill" 124 $RC
[ $E -le 10 ] && ok "killed fast (${E}s)" || bad "killed fast (${E}s)"
# 8. analysis mode: reports only NEW paths, never user WIP
git switch -q main
echo wip > userwip.txt                      # user's pre-existing untracked WIP
echo change >> tracked.txt                  # user's pre-existing dirty tracked file
ERR=$(echo brief | FAKE_MODE=write "$BIN/praetor-dispatch" --analysis 2>&1 >/dev/null)
echo "$ERR" | grep -q 'polluted.txt' && ok "analysis alert lists the run's new file" || bad "analysis alert lists the run's new file"
echo "$ERR" | grep -q 'userwip.txt' && bad "user WIP untouched by alert" || ok "user WIP untouched by alert"
git checkout -q -- tracked.txt && rm -f userwip.txt polluted.txt
# 9. empty brief refused
printf '' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1; check "empty brief refused" 64 $?

echo "== praetor-verdict =="
# 10. fresh dispatch on its own branch, then PASS on the intact bar
git switch -q main && git switch -qc codex/judgetest
printf 'GOAL: j\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1
"$BIN/praetor-verdict" PASS "all green" >/dev/null 2>&1; check "verdict PASS recorded" 0 $?
grep -q '"verdict":"PASS"' .codex/state.json && ok "state holds PASS" || bad "state holds PASS"
# 11. bar tampered after dispatch -> TAMPERED, never PASS
printf 'GOAL: weakened\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm "innocent fix"
"$BIN/praetor-verdict" PASS "trust me" >/dev/null 2>&1; check "tampered bar -> TAMPERED (rc 66)" 66 $?
grep -q '"verdict":"TAMPERED"' .codex/state.json && ok "state holds TAMPERED" || bad "state holds TAMPERED"
# 11b. foreign/stale state (wrong slug or analysis mode) -> refused, never blessed
printf '{"slug":"detached","mode":"analysis","bar_blob":"","attempts":1,"verdict":null,"updated_at":"t"}\n' > .codex/state.json
"$BIN/praetor-verdict" PASS "wrong state" >/dev/null 2>&1; check "foreign state refused (rc 65)" 65 $?

echo "== praetor-gate =="
gate() { printf '{"cwd":"%s","tool_input":{"command":"%s"}}' "$PWD" "$1" | "$BIN/praetor-gate" >/dev/null 2>&1; }
# 12. unrelated command passes instantly
gate "ls -la"; check "unrelated command allowed" 0 $?
# 13. commit real work without PASS -> blocked
git switch -q main && git switch -qc codex/gatetest
printf 'GOAL: g\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1        # attempt 1, verdict null
echo work > feature.txt && git add feature.txt
gate "git commit -m done"; check "commit without PASS blocked (Law 2 in code)" 2 $?
# 14. after judge PASS -> allowed
"$BIN/praetor-verdict" PASS "green" >/dev/null 2>&1
gate "git commit -m done"; check "commit with PASS allowed" 0 $?
# 15. bar moved after PASS -> blocked
python3 - <<'PY'
import json,io
s=json.load(open('.codex/state.json')); s['bar_blob']='deadbeef'; json.dump(s,open('.codex/state.json','w'))
PY
gate "git commit -m done"; check "moved bar voids its PASS" 2 $?
git commit -qm done --no-verify 2>/dev/null || git commit -qm done >/dev/null 2>&1 || true
# 16. freeze commit (.codex only, no state) allowed
git switch -q main && git switch -qc codex/freshfreeze
rm -f .codex/state.json
printf 'GOAL: f\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md
gate "git commit -m freeze"; check "freeze commit allowed pre-dispatch" 0 $?
git commit -qm freeze
# 17. merge gate
git switch -q main
rm -f .codex/state.json
gate "git merge codex/nostate"; check "merge of unknown codex/* blocked" 2 $?
printf '{"slug":"codex/gatetest","mode":"write","bar_blob":"x","attempts":1,"verdict":"FAIL","updated_at":"t"}\n' > .codex/state.json
gate "git merge codex/gatetest"; check "merge with FAIL verdict blocked" 2 $?
printf '{"slug":"codex/gatetest","mode":"write","bar_blob":"x","attempts":1,"verdict":"PASS","updated_at":"t"}\n' > .codex/state.json
gate "git merge codex/gatetest"; check "merge with PASS allowed" 0 $?
gate "git merge --abort"; check "merge --abort never barred" 0 $?
# 18. --amend after dispatch blocked
git switch -q codex/gatetest
printf '{"slug":"codex/gatetest","mode":"write","bar_blob":"x","attempts":1,"verdict":null,"updated_at":"t"}\n' > .codex/state.json
gate "git commit --amend -m rewrite"; check "--amend after dispatch blocked" 2 $?

echo "== adversarial-review regressions =="
# A. `git commit -am` (nothing staged at hook time) must NOT bypass the gate
echo tweak >> tracked.txt
gate "git commit -am wip"; check "commit -am bypass closed" 2 $?
git checkout -q -- tracked.txt
# B. `git -C <path> commit` driven from OUTSIDE the repo is still gated
OUTSIDE="$(mktemp -d "${TMPDIR:-/tmp}/praetor-outside.XXXXXX")"
echo tweak >> tracked.txt
printf '{"cwd":"%s","tool_input":{"command":"git -C %s commit -am wip"}}' "$OUTSIDE" "$PWD" | "$BIN/praetor-gate" >/dev/null 2>&1
check "git -C from outside still gated" 2 $?
git checkout -q -- tracked.txt; rm -rf "$OUTSIDE"
# C. a commit MESSAGE quoting 'git merge codex/x' must not trip the gate (run on main)
git switch -q main
gate "git commit -m 'docs: how to git merge codex/x'"; check "message-substring false block fixed" 0 $?
# D. read-only git commands on a mid-dispatch branch are not blocked
git switch -q codex/gatetest
gate "git log --grep commit"; check "git log --grep commit allowed" 0 $?
# E. `git pull` of a codex/* ref obeys the merge gate
git switch -q main
printf '{"slug":"codex/gatetest","mode":"write","bar_blob":"x","attempts":1,"verdict":"FAIL","updated_at":"t"}\n' > .codex/state.json
gate "git pull origin codex/gatetest"; check "pull of FAILed codex/* blocked" 2 $?
rm -f .codex/state.json
# F. freeze check survives a prior merged dispatch (the self-brick bug)
git switch -q main && git switch -qc codex/m1
printf 'GOAL: m1\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1
"$BIN/praetor-verdict" PASS "green" >/dev/null 2>&1
echo m1work > m1.txt && git add m1.txt && git commit -qm work
git rm -q .codex/ACCEPTANCE.md && git commit -qm "drop bar"
git switch -q main && git merge -q codex/m1 >/dev/null 2>&1
git switch -qc codex/m2
printf 'GOAL: m2\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1; check "second dispatch after merged history runs (self-brick fixed)" 0 $?
# G. an analysis dispatch must not clobber a write dispatch's recorded verdict
"$BIN/praetor-verdict" PASS "green" >/dev/null 2>&1
echo 'look around' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1
grep -q '"verdict":"PASS"' .codex/state.json && ok "analysis leaves write verdict intact" || bad "analysis leaves write verdict intact"
# H. analysis retry budget is per-brief, not global
rm -f .codex/state-analysis.json
echo 'same brief' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1
echo 'same brief' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1
echo 'same brief' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1
echo 'same brief' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1; check "4th try of the SAME analysis brief refused" 5 $?
echo 'different brief' | "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1; check "a NEW analysis brief gets a fresh budget" 0 $?
# I. verdict with NO summary still records TAMPERED (the set -u crash)
git switch -q main && git switch -qc codex/crashtest
printf 'GOAL: c\nCHECK: true\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm freeze
echo brief | "$BIN/praetor-dispatch" >/dev/null 2>&1
printf 'GOAL: weakened\n' > .codex/ACCEPTANCE.md && git add .codex/ACCEPTANCE.md && git commit -qm "innocent"
"$BIN/praetor-verdict" PASS >/dev/null 2>&1; check "no-summary tamper records TAMPERED (rc 66)" 66 $?
grep -q '"verdict":"TAMPERED"' .codex/state.json && ok "TAMPERED written without summary" || bad "TAMPERED written without summary"
# J. garbage PRAETOR_TIMEOUT falls back instead of disabling the watchdog
git switch -q main
echo brief | PRAETOR_TIMEOUT=10m "$BIN/praetor-dispatch" --analysis >/dev/null 2>&1; check "non-numeric PRAETOR_TIMEOUT tolerated" 0 $?
# K. mid-filename wildcard overlap caught statically
printf 'one src/api*.js\ntwo src/api-v2*.js\n' > "$T"/mf-mid.txt
"$BIN/praetor-manifest-check" "$T"/mf-mid.txt >/dev/null 2>&1; check "api* vs api-v2* caught (static)" 1 $?

echo "== praetor-manifest-check =="
cd "$T/repo" && git switch -q main
# 19. disjoint
printf 'alpha src/alpha/**\nbeta src/beta/**\n' > "$T"/mf-ok.txt
"$BIN/praetor-manifest-check" "$T"/mf-ok.txt >/dev/null 2>&1; check "disjoint manifests pass" 0 $?
# 20. static containment
printf 'alpha src/**\nbeta src/beta/**\n' > "$T"/mf-static.txt
"$BIN/praetor-manifest-check" "$T"/mf-static.txt >/dev/null 2>&1; check "src/** vs src/beta/** caught (static)" 1 $?
# 21. file-level overlap
printf 'alpha src/alpha/a.js\nbeta src/*/a.js\n' > "$T"/mf-file.txt
"$BIN/praetor-manifest-check" "$T"/mf-file.txt >/dev/null 2>&1; check "same file in two lanes caught" 1 $?
# 22. src/a vs src/ab is NOT an overlap (boundary-aware)
mkdir -p src/a src/ab && echo x > src/a/x.js && echo y > src/ab/y.js && git add src/a src/ab && git commit -qm more
printf 'one src/a/**\ntwo src/ab/**\n' > "$T"/mf-bound.txt
"$BIN/praetor-manifest-check" "$T"/mf-bound.txt >/dev/null 2>&1; check "src/a vs src/ab boundary-safe" 0 $?

echo
echo "RESULT: ${PASSN} ok, ${FAILN} failed"
[ ${FAILN} -eq 0 ]
