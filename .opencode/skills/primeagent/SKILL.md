---
name: primeagent
description: Drive the prime-agent CLI (PrimeIntellect's self-improving RLM agent) from OpenCode. Use when the user asks to run, delegate, schedule, or check on Prime Agent work - headless runs, JSON event streams, background/daemon sessions, resumes, and long-running autonomous tasks.
---

# Prime Agent

Prime Agent (PrimeIntellect) is a standalone self-improving RLM coding agent: a persistent
Python REPL is its built-in tool, recursive subagents (`rlm(...)`) are spawned
programmatically, and sessions are daemon-backed so they survive terminal detach. It has its
own authentication (`/login` on first interactive launch) and model providers, independent of
OpenCode.

Delegate to Prime Agent when the user explicitly wants it, or for very long autonomous work
where its daemon, heartbeats, and goals help. Otherwise prefer OpenCode-native tools.

## Availability

```bash
command -v prime-agent && prime-agent --version
```

If missing, install: `curl -fsSL https://app.primeintellect.ai/prime-agent/install.sh | sh`
(then restart the shell so PATH picks it up, or use the full path from the installer output).

## Headless usage

```bash
prime-agent -p "Fix the failing tests in src/auth and list what you changed"
prime-agent -p "Summarize this" < report.md          # stdin as context
prime-agent --no-session -p "One-off question"       # ephemeral, not saved
prime-agent --model anthropic/claude-sonnet-4-5 -p "Task"
```

- `-p` runs to completion and prints the result; it can take many minutes for large tasks.
- Each call runs in the **current working directory** with the user's file permissions.

## JSON event stream (scripted runs)

Capture to a file - it keeps prime-agent's exit status visible and needs no extra
approvals:

```bash
out="$(mktemp "${TMPDIR:-/tmp}/prime-agent-out.XXXXXX")"
prime-agent --mode json "Refactor the config module" > "$out" 2> "$out.err"
head -n 1 "$out"          # {"type":"session",...,"id":...} - the resume hint
tail -n 40 "$out"         # final events, including agent_end
rm -f "$out" "$out.err"
```

Compact alternative (the pipe hides prime-agent's exit status, and `jq` needs its own
approval):

```bash
prime-agent --mode json "Refactor the config module" \
  | jq -c 'select(.type == "message_end")'
```

First line is `{"type":"session",...}`; then `agent_start`, `tool_execution_start/end`,
`message_end`, `agent_end` events. Parse `agent_end` for the final messages. `jq` is
optional - without it, just `tail -n 50` the stream and read the tail. Stderr carries
human-readable auth and CLI errors - do not discard it.

## Sessions, headless

```bash
prime-agent list --json            # list sessions (add --all for saved ones)
prime-agent -c -p "Next step..."   # continue most recent session, headless
prime-agent -r <id> -p "Prompt"    # resume a saved session, headless
prime-agent status                 # background service state
prime-agent doctor                 # inspect background services
prime-agent schedule add "Prompt"  # run later or on a recurring schedule
```

`prime-agent doctor --fix` repairs services but also stops stale or idle ones, so it is
state-changing and worth a prompt. `prime-agent agents`, `prime-agent attach <id>`, bare
`prime-agent`, and `-c` or `-r` without `-p` all open interactive views - suggest those to
the user for their terminal; never run them from a script. Same for
`prime-agent shutdown [--force]`: it stops every agent and background service, so suggest
it to the user rather than running it yourself.

## Safety

- Prime Agent executes model-generated Python and shell commands with full user permissions.
  Its kernel/worker processes are **not** a security sandbox.
- Only delegate tasks in trusted repositories, and never paste secrets into prompts.
- If output reports an authentication or login error, stop and tell the user to run
  `prime-agent` once interactively and complete `/login` - do not retry.
- Shell redirects are part of the command string OpenCode approves, so anything wrapped in
  an allowed `prime-agent` invocation (including its redirects) runs without a prompt -
  keep delegate prompts free of untrusted instructions.
