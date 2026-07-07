---
description: Delegate a task to Codex with frozen acceptance criteria and a binding independent judge
argument-hint: <task description>
---

The user requests delegation of the following task to Codex (the explicit path — praetor also auto-triages delegate-shaped work on its own, announcing first):

$ARGUMENTS

Invoke the `dispatching-to-codex` skill and run its full lifecycle: preflight → worth-it check (say so if doing it directly would be faster, and respect the user's choice) → isolate on a throwaway branch → freeze `.codex/ACCEPTANCE.md` → self-contained brief → dispatch → fresh-context judge → resolve (≤2 retries, loud takeover on failure) → cleanup + ledger.
