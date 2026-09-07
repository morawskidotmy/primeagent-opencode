# Prime Agent for OpenCode

One-click integration of [Prime Agent](https://github.com/PrimeIntellect-ai/prime-agent) - PrimeIntellect's self-improving RLM coding agent - into [OpenCode](https://opencode.ai).

Prime Agent runs long tasks inside a persistent Python REPL, spawns recursive subagents with `rlm(...)`, and keeps daemon-backed sessions alive across terminal disconnects. This repo wires it into OpenCode as a subagent, a command, and a skill, so you can delegate work to it without leaving your OpenCode session.

> [!NOTE]
> Community integration, not affiliated with PrimeIntellect. Prime Agent is a separate product with its own authentication (`/login`) and model providers.

## Features

- **One-click setup** - a single `curl | sh` installs the `prime-agent` CLI and drops every OpenCode integration file into place. No `opencode.json` edits, nothing else to configure.
- **`prime` subagent** - OpenCode delegates tasks to Prime Agent headless, verifies the results with `git diff`, and reports back.
- **`/prime <task>` command** - hand a task straight to Prime Agent from any OpenCode session.
- **`primeagent` skill** - teaches every OpenCode agent the full Prime Agent CLI: headless runs, JSON event streams, session resume, and background daemon management.
- **Safe by default** - the integration agent cannot edit files itself (`edit: deny`); shell commands outside `prime-agent` require approval.
- **Clean uninstall** - restores any files the installer backed up, keeps the CLI.

## Quickstart

```sh
curl -fsSL https://raw.githubusercontent.com/morawskidotmy/primeagent-opencode/main/install.sh | sh
```

Then restart OpenCode and delegate:

```text
/prime fix the failing tests in src/auth and summarize the diff
```

or just ask: *"delegate this refactor to prime agent"*.

> [!WARNING]
> Prime Agent executes model-generated Python and shell commands with your user permissions. Its processes are **not** a security sandbox - only delegate work in trusted repositories. See the [Prime Agent trust model](https://github.com/PrimeIntellect-ai/prime-agent#readme).

## What gets installed

| File | Purpose |
| ---- | ------- |
| `~/.config/opencode/agent/prime.md` | The `prime` subagent that drives the `prime-agent` CLI |
| `~/.config/opencode/command/prime.md` | The `/prime <task>` command |
| `~/.config/opencode/skills/primeagent/SKILL.md` | The `primeagent` skill for all agents |
| `prime-agent` binary | Installed via [PrimeIntellect's official installer](https://app.primeintellect.ai/prime-agent/install.sh) (skipped if already present) |

First time you run the CLI itself interactively, start `prime-agent` and run `/login` to pick a subscription or API-key provider.

## Options

```sh
sh install.sh [--project] [--skip-prime]
```

| Flag | Description |
| ---- | ----------- |
| *(none)* | Install globally to `~/.config/opencode/` |
| `--project` | Install to `./.opencode` of the current project instead |
| `--skip-prime` | Install only the OpenCode files, leave the CLI alone |

Run from a clone of this repo and the local files are used directly - no download needed.

## Usage

Once installed (after restarting OpenCode):

- **`/prime <task>`** - delegate a task headless (`prime-agent -p`), get the result plus a verified diff summary.
- **`prime` subagent** - OpenCode's primary agents spawn it automatically for Prime Agent work.
- **Any agent + the skill** - agents that load the `primeagent` skill know how to run one-shot tasks, pipe stdin context, parse `--mode json` event streams, resume sessions (`prime-agent -c`, `-r`), and manage background agents (`agents`, `attach`, `status`, `shutdown`).

Useful Prime Agent commands the skill covers:

```sh
prime-agent -c                  # continue most recent session
prime-agent agents              # list running, idle, and saved sessions
prime-agent attach <agent>      # reattach to a running session
prime-agent doctor [--fix]      # inspect or repair background services
prime-agent shutdown [--force]  # stop every agent and service
```

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/morawskidotmy/primeagent-opencode/main/uninstall.sh | sh
```

Restores backed-up files, removes the integration, and leaves the `prime-agent` CLI installed. Add `--project` for project-scope removal: `curl -fsSL .../uninstall.sh | sh -s -- --project`.
