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

FILES="agent/prime.md skills/primeagent/SKILL.md command/prime.md"
removed=0
for f in $FILES; do
  if [ -f "$DEST/$f" ]; then
    if [ -f "$DEST/$f.primeagent-opencode.bak" ]; then
      mv "$DEST/$f.primeagent-opencode.bak" "$DEST/$f"
      echo "restored backup: $DEST/$f"
    else
      rm "$DEST/$f"
      echo "removed: $DEST/$f"
    fi
    removed=1
  fi
done

# Clean up now-empty directories we may have created.
for d in "$DEST/command" "$DEST/skills/primeagent" "$DEST/skills" "$DEST/agent"; do
  rmdir "$d" 2>/dev/null || true
done

if [ "$removed" -eq 0 ]; then
  echo "Nothing to uninstall in $DEST."
fi

echo "Restart OpenCode for changes to take effect."
echo "The prime-agent CLI was kept. To remove it, see https://github.com/PrimeIntellect-ai/prime-agent"
