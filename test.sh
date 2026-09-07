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
for f in $FILES; do
  [ -f "$tmp/proj/.opencode/$f" ] || fail "uninstall did not restore $f"
done
[ ! -f "$tmp/proj/.opencode/agent/prime.md.primeagent-opencode.bak" ] || fail "backup not consumed by uninstall"

step "project uninstall (plain removal)"
( cd "$tmp/proj" && sh "$REPO/uninstall.sh" --project >/dev/null )
for f in $FILES; do
  [ ! -f "$tmp/proj/.opencode/$f" ] || fail "plain uninstall left $f behind"
done
[ ! -d "$tmp/proj/.opencode/agent" ] || fail "plain uninstall left empty agent dir"
[ ! -d "$tmp/proj/.opencode/command" ] || fail "plain uninstall left empty command dir"
[ ! -d "$tmp/proj/.opencode/skills/primeagent" ] || fail "plain uninstall left empty skills/primeagent dir"
[ ! -d "$tmp/proj/.opencode/skills" ] || fail "plain uninstall left empty skills dir"

step "reinstall warns on locally modified files"
mkdir -p "$tmp/edit"
( cd "$tmp/edit" && sh "$REPO/install.sh" --project --skip-prime >/dev/null )
( cd "$tmp/edit" && sh "$REPO/install.sh" --project --skip-prime >/dev/null )
printf '\n# local edit\n' >> "$tmp/edit/.opencode/agent/prime.md"
out="$( cd "$tmp/edit" && sh "$REPO/install.sh" --project --skip-prime 2>&1 )"
case "$out" in
  *"local changes"*) : ;;
  *) fail "expected local-changes warning on modified reinstall" ;;
esac

step "failed copy leaves no temp litter"
mkdir -p "$tmp/litter"
if ( cd "$tmp/litter" && ulimit -f 0 && sh "$REPO/install.sh" --project --skip-prime >/dev/null 2>&1 ); then
  fail "expected install to fail under ulimit -f 0"
fi
[ -z "$(find "$tmp/litter" -name '*.tmp.*' 2>/dev/null)" ] || fail "temp litter left behind"

step "global install (fake XDG_CONFIG_HOME)"
mkdir -p "$tmp/home/.config"
( XDG_CONFIG_HOME="$tmp/home/.config" sh "$REPO/install.sh" --skip-prime >/dev/null )
[ -f "$tmp/home/.config/opencode/agent/prime.md" ] || fail "global install missing agent file"

step "global install aborts on read-only target"
if [ "$(id -u)" -eq 0 ]; then
  echo "   skipped: running as root"
else
  mkdir -p "$tmp/rohome/.config/opencode"
  chmod 555 "$tmp/rohome/.config/opencode"
  if XDG_CONFIG_HOME="$tmp/rohome/.config" sh "$REPO/install.sh" --skip-prime >/dev/null 2>&1; then
    fail "expected read-only global target to abort"
  fi
  chmod 755 "$tmp/rohome/.config/opencode"
fi

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
