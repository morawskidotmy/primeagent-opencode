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

```bash
prime-agent --mode json "Refactor the config module" 2>/dev/null \
  | jq -c 'select(.type == "message_end")'
```

First line is `{"type":"session",...}`; then `agent_start`, `tool_execution_start/end`,
`message_end`, `agent_end` events. Parse `agent_end` for the final messages. `jq` is
optional - without it, just `tail -n 50` the stream and read the tail.

## Sessions and background agents

```bash
prime-agent -c                     # continue most recent session
prime-agent -r <path|id>           # resume a saved session
prime-agent agents                 # list running, idle, saved sessions
prime-agent attach <agent>         # reattach to a running session (interactive)
prime-agent status                 # background service state
prime-agent doctor [--fix]         # inspect/repair background services
prime-agent shutdown [--force]     # stop all agents and services
```

Sessions keep running when the invoking terminal exits; poll `prime-agent agents` to check
progress instead of killing and restarting.

## Safety

- Prime Agent executes model-generated Python and shell commands with full user permissions.
  Its kernel/worker processes are **not** a security sandbox.
- Only delegate tasks in trusted repositories, and never paste secrets into prompts.
- Run `prime-agent shutdown` when finished with background work.
