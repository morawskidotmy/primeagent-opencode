#!/bin/sh
# Prime Agent for OpenCode - one-click installer.
#
#   curl -fsSL https://raw.githubusercontent.com/morawskidotmy/primeagent-opencode/main/install.sh | sh
#
# Installs:
#   1. The prime-agent CLI (PrimeIntellect's official installer), unless present.
#   2. The `prime` subagent, `/prime` command, and `primeagent` skill into OpenCode.
#
# Flags:
#   --project     install into ./.opencode instead of ~/.config/opencode
#   --skip-prime  do not install/update the prime-agent CLI
#   --help        show this help

set -eu

REPO_TARBALL="https://codeload.github.com/morawskidotmy/primeagent-opencode/tar.gz/refs/heads/main"
OFFICIAL_INSTALLER="https://app.primeintellect.ai/prime-agent/install.sh"

SCOPE="global"
SKIP_PRIME=0
for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --skip-prime) SKIP_PRIME=1 ;;
    -h|--help)
      cat <<'USAGE'
Prime Agent for OpenCode installer.

Usage: install.sh [--project] [--skip-prime]

  --project     install into ./.opencode of the current directory
                instead of the global ~/.config/opencode
  --skip-prime  install only the OpenCode integration files,
                skip the prime-agent CLI
  --help        show this help
USAGE
      exit 0 ;;
    *) echo "Unknown flag: $arg (try --help)" >&2; exit 1 ;;
  esac
done

if [ -t 1 ] && [ -t 2 ]; then
  log() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
  warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
  die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
else
  log() { printf '==> %s\n' "$*"; }
  warn() { printf 'warning: %s\n' "$*" >&2; }
  die() { printf 'error: %s\n' "$*" >&2; exit 1; }
fi

# ---------------------------------------------------------------------------
# Locate source files: a local checkout, or a fresh tarball (curl | sh case).
# ---------------------------------------------------------------------------
SRC=""
if [ -f "$0" ] && [ -f "$(dirname "$0")/.opencode/agent/prime.md" ]; then
  SRC="$(cd "$(dirname "$0")" && pwd)"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT INT TERM
  log "Fetching primeagent-opencode from GitHub..."
  curl -fsSL "$REPO_TARBALL" -o "$TMP/repo.tar.gz" \
    || die "could not download $REPO_TARBALL"
  tar -xzf "$TMP/repo.tar.gz" -C "$TMP"
  SRC="$TMP/primeagent-opencode-main"
fi
[ -f "$SRC/.opencode/agent/prime.md" ] || die "integration files missing from $SRC"

# ---------------------------------------------------------------------------
# 1. prime-agent CLI
# ---------------------------------------------------------------------------
if [ "$SKIP_PRIME" -eq 0 ]; then
  if command -v prime-agent >/dev/null 2>&1; then
    log "prime-agent CLI already installed: $(prime-agent --version 2>&1 || echo 'unknown version')"
  else
    log "Installing prime-agent CLI (PrimeIntellect official installer)..."
    curl -fsSL "$OFFICIAL_INSTALLER" | sh \
      || die "prime-agent CLI installation failed; retry manually: curl -fsSL $OFFICIAL_INSTALLER | sh"
    if ! command -v prime-agent >/dev/null 2>&1; then
      warn "prime-agent not on PATH yet - open a new shell, or add the installer's PATH line to your profile."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2. OpenCode integration files
# ---------------------------------------------------------------------------
if [ "$SCOPE" = "project" ]; then
  DEST=".opencode"
else
  DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
fi
if ! mkdir -p "$DEST" 2>/dev/null || ! touch "$DEST/.primeagent-write-test" 2>/dev/null; then
  rm -f "$DEST/.primeagent-write-test" 2>/dev/null || true
  die "cannot write to $DEST - check permissions, or use --project to install into the current directory"
fi
rm -f "$DEST/.primeagent-write-test"
log "Installing OpenCode integration ($SCOPE): $DEST"

install_file() {
  src="$1"
  dest="$2"
  if [ "$src" -ef "$dest" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    if [ ! -f "$dest.primeagent-opencode.bak" ]; then
      if ! cp "$dest" "$dest.primeagent-opencode.bak.tmp.$$"; then
        rm -f "$dest.primeagent-opencode.bak.tmp.$$"
        die "could not write $dest.primeagent-opencode.bak"
      fi
      mv "$dest.primeagent-opencode.bak.tmp.$$" "$dest.primeagent-opencode.bak"
      warn "backed up existing $dest to $dest.primeagent-opencode.bak"
    elif ! cmp -s "$dest" "$src"; then
      warn "$dest has local changes that will be overwritten; pre-install backup kept at $dest.primeagent-opencode.bak"
    fi
  fi
  if ! cp "$src" "$dest.tmp.$$"; then
    rm -f "$dest.tmp.$$"
    die "could not write $dest"
  fi
  mv "$dest.tmp.$$" "$dest"
}

install_file "$SRC/.opencode/agent/prime.md"             "$DEST/agent/prime.md"
install_file "$SRC/.opencode/skills/primeagent/SKILL.md" "$DEST/skills/primeagent/SKILL.md"
install_file "$SRC/.opencode/command/prime.md"           "$DEST/command/prime.md"

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
for f in agent/prime.md skills/primeagent/SKILL.md command/prime.md; do
  [ -f "$DEST/$f" ] || die "verification failed: $DEST/$f missing"
done
log "OpenCode integration files installed and verified."

cat <<'EOF'

Done. Next steps:
  1. Quit and restart OpenCode so the new agent, command, and skill load.
  2. In any project, ask OpenCode to "delegate this task to prime agent",
     run /prime <task>, or spawn the `prime` subagent.
  3. First interactive launch of the CLI itself: run `prime-agent`, then /login.

Uninstall: curl -fsSL https://raw.githubusercontent.com/morawskidotmy/primeagent-opencode/main/uninstall.sh | sh
EOF
