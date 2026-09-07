#!/bin/sh
# Prime Agent for OpenCode - uninstaller.
#
#   curl -fsSL https://raw.githubusercontent.com/morawskidotmy/primeagent-opencode/main/uninstall.sh | sh
#
# Removes the OpenCode integration files (agent, command, skill) installed by
# install.sh, restoring any backups it created. The prime-agent CLI itself is
# kept unless --all is given.
#
# Flags:
#   --all       also stop background services and remove the prime-agent CLI
#               (volta/npm package, user-local binary, and state directories)
#   --project   remove from ./.opencode instead of ~/.config/opencode
#   --help      show this help

set -eu

SCOPE="global"
REMOVE_CLI=0
for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --all) REMOVE_CLI=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" 2>/dev/null || true
      exit 0 ;;
    *) echo "Unknown flag: $arg (try --help)" >&2; exit 1 ;;
  esac
done

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

failed=0

remove_cli() {
  if command -v prime-agent >/dev/null 2>&1; then
    log "Stopping prime-agent background services..."
    prime-agent shutdown --force >/dev/null 2>&1 || true
  fi

  if command -v volta >/dev/null 2>&1 \
    && volta list 2>/dev/null | grep -q "prime-agent"; then
    log "Removing prime-agent package (volta)..."
    if ! volta uninstall prime-agent; then
      warn "volta uninstall failed"
      failed=1
    fi
  elif command -v npm >/dev/null 2>&1 \
    && npm ls -g prime-agent >/dev/null 2>&1; then
    log "Removing prime-agent package (npm global)..."
    if ! npm uninstall -g prime-agent; then
      warn "npm uninstall failed"
      failed=1
    fi
  fi

  if command -v prime-agent >/dev/null 2>&1; then
    bin="$(command -v prime-agent)"
    case "$bin" in
      "$HOME"/*)
        if rm -f "$bin"; then
          log "removed $bin"
        else
          warn "could not remove $bin"
          failed=1
        fi
        ;;
      *)
        warn "prime-agent still installed at $bin - remove it manually"
        ;;
    esac
  fi

  for d in "$HOME/.prime-agent" \
    "$HOME/.config/prime-agent" \
    "$HOME/.local/share/prime-agent" \
    "$HOME/.local/state/prime-agent" \
    "$HOME/.cache/prime-agent"; do
    if [ -d "$d" ]; then
      if rm -rf "$d"; then
        log "removed $d"
      else
        warn "could not remove $d"
        failed=1
      fi
    fi
  done
}

if [ "$SCOPE" = "project" ]; then
  DEST=".opencode"
else
  DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
fi

FILES="agent/prime.md skills/primeagent/SKILL.md command/prime.md"
found=0
for f in $FILES; do
  if [ -f "$DEST/$f" ]; then
    found=1
    if [ -f "$DEST/$f.primeagent-opencode.bak" ]; then
      if mv "$DEST/$f.primeagent-opencode.bak" "$DEST/$f"; then
        echo "restored backup: $DEST/$f"
      else
        warn "could not restore $DEST/$f from its backup"
        failed=1
      fi
    elif rm "$DEST/$f" 2>/dev/null; then
      echo "removed: $DEST/$f"
    else
      warn "could not remove $DEST/$f"
      failed=1
    fi
  fi
done

# Clean up now-empty directories we may have created.
for d in "$DEST/command" "$DEST/skills/primeagent" "$DEST/skills" "$DEST/agent"; do
  rmdir "$d" 2>/dev/null || true
done

if [ "$REMOVE_CLI" -eq 1 ]; then
  remove_cli
fi

if [ "$found" -eq 0 ]; then
  echo "No OpenCode integration files found in $DEST."
fi
if [ "$found" -eq 1 ]; then
  echo "Restart OpenCode for changes to take effect."
fi
if [ "$REMOVE_CLI" -eq 1 ]; then
  echo "prime-agent CLI removed."
else
  echo "The prime-agent CLI was kept. Run this script again with --all to remove it."
fi
[ "$failed" -eq 0 ] || exit 1
