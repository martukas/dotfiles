#!/usr/bin/env bash
# Test harness for mc-world-pull. Runs unprivileged against a fixture tree --
# the "server" is a local directory and the transfer is a cat.
set -uo pipefail

SCRIPT=$(dirname "$0")/bin/mc-world-pull
PASS=0
FAIL=0
ROOT=""

fixture() {
  ROOT=$(mktemp -d)
  mkdir -p "$ROOT/remote/daily" "$ROOT/dest"
  cat >"$ROOT/conf" <<EOF
REMOTE="fixture-host"
REMOTE_TIER_DIR="$ROOT/remote"
DEST="$ROOT/dest"
MIN_FREE_MB=1
REMOTE_RUN='eval "\$rcmd"'
REMOTE_CAT='cat "\$rfile"'
REMOTE_PRIME="touch $ROOT/primed"
EOF
}

# make_remote <YYYY-MM-DD--HH-MM> -- an archive and its sidecar on the "server"
make_remote() {
  local base="$ROOT/remote/daily/Backup--world--$1"
  echo "worlddata-$1" >"$base.zip"
  echo "statedata-$1" >"$base.state.tar.gz"
}

check() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  ok   $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $name"
    echo "        expected: $expected"
    echo "        actual:   $actual"
  fi
}

echo "== config and dispatch =="

fixture
MC_WORLD_PULL_CONFIG="$ROOT/nonexistent" "$SCRIPT" >/dev/null 2>&1
check "missing config is an error" "1" "$?"

fixture
make_remote "2026-09-17--08-42"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" --help >/dev/null 2>&1
check "--help exits clean" "0" "$?"

echo "== check mode =="

fixture
make_remote "2026-09-17--08-42"
OUT=$(MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" --check 2>&1)
check "--check names the newest archive" "1" \
  "$(echo "$OUT" | grep -c 'server newest : Backup--world--2026-09-17--08-42.zip')"
check "--check reports nothing held yet" "1" "$(echo "$OUT" | grep -c 'already held  : none')"
check "--check changes nothing" "0" "$(find "$ROOT/dest" -mindepth 1 | wc -l)"

echo "== pulling =="

fixture
make_remote "2026-09-17--08-42"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "a pull lands the archive" "1" \
  "$([ -f "$ROOT/dest/current/Backup--world--2026-09-17--08-42.zip" ] && echo 1 || echo 0)"
check "a pull lands the sidecar too" "1" \
  "$([ -f "$ROOT/dest/current/Backup--world--2026-09-17--08-42.state.tar.gz" ] && echo 1 || echo 0)"
check "a manifest records which archive this is" "1" \
  "$(grep -c '^archive=Backup--world--2026-09-17--08-42.zip' "$ROOT/dest/current/MANIFEST")"
check "no staging directory is left behind" "0" \
  "$([ -e "$ROOT/dest/.staging" ] && echo 1 || echo 0)"

# Re-pulling the same archive would burn ~6 minutes of transfer for nothing,
# and would push a good 'previous' out for a duplicate.
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "re-pulling the same archive is declined" "0" \
  "$([ -d "$ROOT/dest/previous" ] && echo 1 || echo 0)"

echo "== rotation =="

make_remote "2026-09-18--09-00"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "current holds the new archive" "1" \
  "$(grep -c '^archive=Backup--world--2026-09-18--09-00.zip' "$ROOT/dest/current/MANIFEST")"
check "previous holds the one before it" "1" \
  "$(grep -c '^archive=Backup--world--2026-09-17--08-42.zip' "$ROOT/dest/previous/MANIFEST")"

echo "== a corrupted transfer must not rotate =="

# The whole reason previous exists: a bad pull must not be able to destroy the
# last known-good copy.
fixture
make_remote "2026-09-17--08-42"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
make_remote "2026-09-18--09-00"
sed -i "s|^REMOTE_CAT=.*|REMOTE_CAT='{ cat \"\$rfile\"; echo corruption; }'|" "$ROOT/conf"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "a corrupt transfer exits non-zero" "1" "$?"
check "current still holds the good copy" "1" \
  "$(grep -c '^archive=Backup--world--2026-09-17--08-42.zip' "$ROOT/dest/current/MANIFEST")"
check "no previous was created by the failed pull" "0" \
  "$([ -d "$ROOT/dest/previous" ] && echo 1 || echo 0)"
check "the corrupt staging copy is discarded" "0" \
  "$([ -e "$ROOT/dest/.staging" ] && echo 1 || echo 0)"

echo "== sudo priming =="

# Priming unconditionally hangs a host that does not need it: 'sudo -v' prompts
# even where NOPASSWD rules apply, and the prompt was being sent to /dev/null.
fixture
make_remote "2026-09-17--08-42"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "a server that allows sudo already is not primed" "0" \
  "$([ -e "$ROOT/primed" ] && echo 1 || echo 0)"

fixture
make_remote "2026-09-17--08-42"
sed -i "s|^REMOTE_RUN=.*|REMOTE_RUN='false'|" "$ROOT/conf"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "a server that needs a password is primed" "1" \
  "$([ -e "$ROOT/primed" ] && echo 1 || echo 0)"

echo "== free space floor =="

fixture
make_remote "2026-09-17--08-42"
sed -i 's/^MIN_FREE_MB=.*/MIN_FREE_MB=999999999/' "$ROOT/conf"
MC_WORLD_PULL_CONFIG="$ROOT/conf" "$SCRIPT" >/dev/null 2>&1
check "too little free space refuses to pull" "1" "$?"
check "and nothing was written" "0" \
  "$([ -d "$ROOT/dest/current" ] && echo 1 || echo 0)"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
