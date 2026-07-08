#!/usr/bin/env bash
# codex-dispatch preflight — is delegation possible right now?
# stdout: one line. exit 0 = ready; non-zero = not ready (message says why).
# Never blocks, never prompts, never writes anything.
set -u

# Kill switch: a STOP file halts all dispatching. The documented promise is
# "repo root", so resolve the git toplevel (the shell may sit in a subdir or
# a lane worktree); a STOP in the cwd is honored too, as a courtesy.
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ -f "${TOPLEVEL}/STOP" ] || [ -f "STOP" ]; then
  echo "not-ready reason=STOP-file (delete ${TOPLEVEL}/STOP to resume dispatching)"
  exit 3
fi

# Codex CLI on PATH?
if ! command -v codex >/dev/null 2>&1; then
  echo "not-ready reason=codex-not-installed (npm i -g @openai/codex)"
  exit 1
fi

VERSION="$(codex --version 2>/dev/null | head -1 | tr -d '\n')"

# Relay / custom provider sniff (read-only) — BEFORE the login gate: relay
# users authenticate through config.toml (env_key etc.), not `codex login`,
# and must not be bounced into an OAuth they cannot complete (live finding).
# Only an ACTIVE TOP-LEVEL `model_provider = ...` counts — the same line
# inside any [section] (an unactivated profile/provider table) means the
# official default still runs (real-machine false-positive, fixed twice now).
CONFIG="stock"
if [ -f "${HOME}/.codex/config.toml" ] \
   && awk '/^[[:space:]]*\[/{exit} /^[[:space:]]*model_provider[[:space:]]*=/{found=1; exit} END{exit !found}' \
       "${HOME}/.codex/config.toml" 2>/dev/null; then
  CONFIG="custom"
fi

# Logged in? Prefer the CLI's own answer; fall back to auth file presence.
# Skipped when config=custom: a relay carries its own auth in config.toml,
# and `codex login status` legitimately fails there while `codex exec` works.
if [ "${CONFIG}" = "stock" ] && ! codex login status >/dev/null 2>&1; then
  if [ ! -f "${HOME}/.codex/auth.json" ]; then
    echo "not-ready reason=not-logged-in (run: codex login)"
    exit 2
  fi
fi

# Git probe (non-fatal): write dispatches need git for branch isolation +
# the frozen acceptance commit; analysis-only dispatches work without it.
GIT="yes"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || GIT="no"

# Legion support (worktrees) + stale-state sweep (read-only; no cleanup here):
# a crashed/killed session can strand a legion dir, a praetor stash, or leave
# the tree parked on a codex/* branch — report so the planner offers recovery.
WORKTREE="no"; git worktree list >/dev/null 2>&1 && WORKTREE="yes"
STALE=""
if [ "${GIT}" = "yes" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
  LEG="$(dirname "${ROOT}")/$(basename "${ROOT}")-legion"
  [ -d "${LEG}" ] && STALE=" stale-legion=${LEG}"
  git stash list 2>/dev/null | grep -q 'praetor-' && STALE="${STALE} stranded-stash=praetor"
  CURBRANCH="$(git branch --show-current 2>/dev/null)"
  case "${CURBRANCH}" in codex/*) STALE="${STALE} on-codex-branch=${CURBRANCH}" ;; esac
fi

echo "ready version=${VERSION} config=${CONFIG} git=${GIT} worktree=${WORKTREE}${STALE}"
exit 0
