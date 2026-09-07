#!/bin/sh
# Verification suite for primeagent-opencode. Run from anywhere: ./test.sh
set -eu
cd "$(dirname "$0")"
REPO="$PWD"
FILES="agent/prime.md skills/primeagent/SKILL.md command/prime.md"

fail() { printf '\033[1;31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }
step() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

step "syntax checks"
sh -n install.sh || fail "install.sh syntax"
sh -n uninstall.sh || fail "uninstall.sh syntax"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT INT TERM

step "project install (fresh)"
mkdir -p "$tmp/proj"
( cd "$tmp/proj" && sh "$REPO/install.sh" --project --skip-prime >/dev/null )
for f in $FILES; do
  [ -f "$tmp/proj/.opencode/$f" ] || fail "missing .opencode/$f after project install"
done

step "project reinstall (backup path)"
( cd "$tmp/proj" && sh "$REPO/install.sh" --project --skip-prime >/dev/null )
[ -f "$tmp/proj/.opencode/agent/prime.md.primeagent-opencode.bak" ] || fail "no backup created on reinstall"

step "project uninstall (restore backup)"
( cd "$tmp/proj" && sh "$REPO/uninstall.sh" --project >/dev/null )
[ -f "$tmp/proj/.opencode/agent/prime.md" ] || fail "uninstall removed file without restoring backup"
[ ! -f "$tmp/proj/.opencode/agent/prime.md.primeagent-opencode.bak" ] || fail "backup not consumed by uninstall"

step "global install (fake XDG_CONFIG_HOME)"
mkdir -p "$tmp/home/.config"
( XDG_CONFIG_HOME="$tmp/home/.config" sh "$REPO/install.sh" --skip-prime >/dev/null )
[ -f "$tmp/home/.config/opencode/agent/prime.md" ] || fail "global install missing agent file"

step "global install aborts on read-only target"
mkdir -p "$tmp/rohome/.config/opencode"
chmod 555 "$tmp/rohome/.config/opencode"
if XDG_CONFIG_HOME="$tmp/rohome/.config" sh "$REPO/install.sh" --skip-prime >/dev/null 2>&1; then
  fail "expected read-only global target to abort"
fi
chmod 755 "$tmp/rohome/.config/opencode"

step "self-install is a clean no-op"
sh "$REPO/install.sh" --project --skip-prime >/dev/null
[ ! -f .opencode/agent/prime.md.primeagent-opencode.bak ] || fail "self-install created a stray backup"

step "tarball layout matches installer expectations"
if git ls-files --error-unmatch .opencode/agent/prime.md >/dev/null 2>&1; then
  git archive --format=tar.gz --prefix=primeagent-opencode-main/ -o "$tmp/repo.tar.gz" HEAD
  mkdir -p "$tmp/x"
  tar -xzf "$tmp/repo.tar.gz" -C "$tmp/x"
  ( cd "$tmp/x/primeagent-opencode-main" && sh install.sh --project --skip-prime >/dev/null )
  for f in $FILES; do
    [ -f "$tmp/x/primeagent-opencode-main/.opencode/$f" ] || fail "tarball flow missing $f"
  done
else
  echo "   skipped: integration files not committed yet"
fi

echo "all tests passed"
