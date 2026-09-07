---
description: Delegate a task to Prime Agent (headless)
---

Load the `primeagent` skill, then delegate the following task to Prime Agent headless
(`prime-agent -p`) from the current working directory. Report its final output, a summary of
what changed (verify with `git status` / `git diff`), and how to resume the session. If
Prime Agent reports an authentication or login error, stop and tell the user to run
`prime-agent` interactively and complete `/login` - do not retry.

Task: $ARGUMENTS
