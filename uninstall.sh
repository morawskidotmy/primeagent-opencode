#!/bin/sh
# Prime Agent for OpenCode - uninstaller.
# Removes the OpenCode integration files installed by install.sh.
# The prime-agent CLI itself is left untouched.

set -eu

SCOPE="global"
for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [ "$SCOPE" = "project" ]; then
  DEST=".opencode"
else
  DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
fi

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }

FILES="agent/prime.md skills/primeagent/SKILL.md command/prime.md"
found=0
failed=0
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

if [ "$found" -eq 0 ]; then
  echo "Nothing to uninstall in $DEST."
fi
if [ "$found" -eq 1 ]; then
  echo "Restart OpenCode for changes to take effect."
fi
echo "The prime-agent CLI was kept. To remove it, see https://github.com/PrimeIntellect-ai/prime-agent"
[ "$failed" -eq 0 ] || exit 1
