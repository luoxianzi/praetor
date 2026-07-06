#!/usr/bin/env bash
# codex-dispatch preflight — is delegation possible right now?
# stdout: one line. exit 0 = ready; non-zero = not ready (message says why).
# Never blocks, never prompts, never writes anything.
set -u

# Kill switch: a STOP file in the repo root halts all dispatching.
if [ -f "STOP" ]; then
  echo "not-ready reason=STOP-file (delete ./STOP to resume dispatching)"
  exit 3
fi

# Codex CLI on PATH?
if ! command -v codex >/dev/null 2>&1; then
  echo "not-ready reason=codex-not-installed (npm i -g @openai/codex)"
  exit 1
fi

VERSION="$(codex --version 2>/dev/null | head -1 | tr -d '\n')"

# Logged in? Prefer the CLI's own answer; fall back to auth file presence.
if ! codex login status >/dev/null 2>&1; then
  if [ ! -f "${HOME}/.codex/auth.json" ]; then
    echo "not-ready reason=not-logged-in (run: codex login)"
    exit 2
  fi
fi

# Dispatch needs git for branch isolation + the frozen acceptance commit.
# (Analysis-only dispatches don't, but write dispatches are the risky path.)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not-ready reason=not-a-git-repo (write dispatches need git; analysis-only is still fine)"
  exit 4
fi

# Relay / custom provider sniff (read-only): only an ACTIVE top-level
# `model_provider = ...` counts — a defined-but-unactivated [model_providers.x]
# table means the user still runs the official default (real-machine bug, fixed).
CONFIG="stock"
if [ -f "${HOME}/.codex/config.toml" ] \
   && grep -qE '^[[:space:]]*model_provider[[:space:]]*=' "${HOME}/.codex/config.toml" 2>/dev/null; then
  CONFIG="custom"
fi

echo "ready version=${VERSION} config=${CONFIG}"
exit 0
