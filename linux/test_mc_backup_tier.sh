#!/usr/bin/env bash
# Test harness for mc-backup-tier. Runs unprivileged against a fixture tree.
set -uo pipefail

SCRIPT=$(dirname "$0")/bin/mc-backup-tier
INSTALLER=$(dirname "$0")/bin/mc-backup-tier-install
PASS=0
FAIL=0
ROOT=""

fixture() {
  ROOT=$(mktemp -d)
  mkdir -p "$ROOT/backups/world" "$ROOT/tiers"
  cat >"$ROOT/conf" <<EOF
BACKUP_DIR="$ROOT/backups/world"
TIER_ROOT="$ROOT/tiers"
DAILY_KEEP=7
WEEKLY_KEEP=4
RCON_BIN="/bin/true"
RCON_HOST="127.0.0.1"
RCON_PORT="25575"
RCON_PASS="x"
MC_UNIT="minecraft.service"
NOTIFY_ADDR="root"
MIN_FREE_MB=100
RCON_WAIT_SECS=1
RCON_POLL_SECS=1
MAIL_CMD="cat >>$ROOT/mail.out"
JOURNAL_CMD='printf "%s" "\$since" >$ROOT/since.seen; cat $ROOT/journal.txt'
EOF
  : >"$ROOT/journal.txt"
  : >"$ROOT/mail.out"
}

# make_backup <YYYY-MM-DD--HH-MM> [zero|ok]
make_backup() {
  local stamp=$1 kind=${2:-ok}
  local base="$ROOT/backups/world/Backup--world--$stamp"
  echo "zipdata" >"$base.zip"
  if [ "$kind" = zero ]; then
    : >"$base.backupinfo"
  else
    echo "info" >"$base.backupinfo"
  fi
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

echo "== task 1: config and dispatch =="

fixture
MC_BACKUP_TIER_CONFIG="$ROOT/nonexistent" "$SCRIPT" --promote >/dev/null 2>&1
check "missing config is an error" "1" "$?"

fixture
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "a valid config sources cleanly" "0" "$?"

fixture
sed -i '/^TIER_ROOT=/d' "$ROOT/conf"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "incomplete config is an error" "1" "$?"

echo "== task 2: eligibility and daily promotion =="

fixture
make_backup "2026-09-14--10-00"
make_backup "2026-09-14--10-15"
make_backup "2026-09-15--09-00"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "one daily entry per day" "2" "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"
check "promotes the OLDEST of a day" "1" \
  "$(find "$ROOT/tiers/daily" -name 'Backup--world--2026-09-14--10-00.zip' 2>/dev/null | wc -l)"
check "does not promote the newer one" "0" \
  "$(find "$ROOT/tiers/daily" -name 'Backup--world--2026-09-14--10-15.zip' 2>/dev/null | wc -l)"

fixture
make_backup "2026-09-14--10-00" zero
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "zero-byte backupinfo blocks promotion" "0" \
  "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"

fixture
make_backup "2026-09-14--10-00"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
# original + daily link + weekly link: the only backup is the oldest of both its day and its week
check "promotion is a hardlink, not a copy" "3" \
  "$(stat -c %h "$ROOT/backups/world/Backup--world--2026-09-14--10-00.zip")"
check "one file on disk, not three" "1" \
  "$(find "$ROOT" -name 'Backup--world--2026-09-14--10-00.zip' -printf '%i\n' | sort -u | wc -l)"
rm -f "$ROOT/backups/world/Backup--world--2026-09-14--10-00.zip"
check "tier copy survives the mod deleting its own" "1" \
  "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"

fixture
make_backup "2026-09-14--10-00"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "second run is idempotent" "1" "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"

echo "== task 3: weekly promotion and pruning =="

fixture
make_backup "2026-09-14--10-00"
make_backup "2026-09-16--10-00"
make_backup "2026-09-23--10-00"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "three daily entries" "3" "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"
check "two weekly entries (W38, W39)" "2" "$(find "$ROOT/tiers/weekly" -name '*.zip' 2>/dev/null | wc -l)"
check "weekly takes the oldest of its week" "1" \
  "$(find "$ROOT/tiers/weekly" -name 'Backup--world--2026-09-14--10-00.zip' 2>/dev/null | wc -l)"
check "weekly does not take the later day in the same week" "0" \
  "$(find "$ROOT/tiers/weekly" -name 'Backup--world--2026-09-16--10-00.zip' 2>/dev/null | wc -l)"

fixture
for d in 01 02 03 04 05 06 07 08 09; do make_backup "2026-09-$d--10-00"; done
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "daily tier pruned to DAILY_KEEP" "7" "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"
check "pruning keeps the newest" "1" \
  "$(find "$ROOT/tiers/daily" -name 'Backup--world--2026-09-09--10-00.zip' 2>/dev/null | wc -l)"
check "pruning drops the oldest" "0" \
  "$(find "$ROOT/tiers/daily" -name 'Backup--world--2026-09-01--10-00.zip' 2>/dev/null | wc -l)"
check "data survives daily pruning via the weekly link" "1" \
  "$(find "$ROOT/tiers/weekly" -name 'Backup--world--2026-09-01--10-00.zip' 2>/dev/null | wc -l)"

fixture
for d in 01 08 15 22 29; do make_backup "2026-06-$d--10-00"; done
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "weekly tier pruned to WEEKLY_KEEP" "4" "$(find "$ROOT/tiers/weekly" -name '*.zip' 2>/dev/null | wc -l)"

echo "== task 4: reporting =="

fixture
make_backup "2026-09-14--10-00" zero
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "zero-byte artifact is reported" "1" "$(grep -c 'zero-byte' "$ROOT/mail.out")"

fixture
make_backup "2026-09-14--10-00"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "healthy run sends no mail at all" "0" "$(wc -c <"$ROOT/mail.out" | tr -d ' ')"

fixture
make_backup "2026-09-14--10-00" zero
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "a run with failures exits non-zero" "1" "$?"

fixture
sed -i 's/^MIN_FREE_MB=.*/MIN_FREE_MB=999999999/' "$ROOT/conf"
make_backup "2026-09-14--10-00"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --promote >/dev/null 2>&1
check "low free space is reported" "1" "$(grep -c 'free space' "$ROOT/mail.out")"
check "low free space does not block promotion" "1" \
  "$(find "$ROOT/tiers/daily" -name '*.zip' 2>/dev/null | wc -l)"

echo "== task 5: boot mode =="

# stub_rcon <output> <exitcode> -- point RCON_BIN at a fake mcrcon
stub_rcon() {
  cat >"$ROOT/rcon" <<EOF
#!/bin/sh
echo '$1'
exit $2
EOF
  chmod +x "$ROOT/rcon"
  sed -i "s|^RCON_BIN=.*|RCON_BIN=\"$ROOT/rcon\"|" "$ROOT/conf"
}

fixture
make_backup "2026-09-14--10-00"
: >"$ROOT/journal.txt"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >"$ROOT/boot.out" 2>&1
check "no play since last backup -> declines" "1" "$(grep -c 'not triggering' "$ROOT/boot.out")"
check "no play since last backup -> does not trigger" "0" \
  "$(grep -c 'triggering a backup' "$ROOT/boot.out")"

fixture
make_backup "2026-09-14--10-00"
echo "Steve joined the game" >"$ROOT/journal.txt"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >"$ROOT/boot.out" 2>&1
check "play since last backup -> triggers" "1" \
  "$(grep -c 'triggering a backup' "$ROOT/boot.out")"

fixture
: >"$ROOT/journal.txt"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >/dev/null 2>&1
check "no backups at all -> no crash" "0" "$?"

fixture
make_backup "2026-09-14--10-00"
echo "Steve joined the game" >"$ROOT/journal.txt"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >/dev/null 2>&1
check "journal query is time-bounded to the newest backup" "2026-09-14 10:00:00" \
  "$(cat "$ROOT/since.seen" 2>/dev/null)"

fixture
make_backup "2026-09-14--10-00"
echo "Steve joined the game" >"$ROOT/journal.txt"
stub_rcon "A backup is already running." 0
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >/dev/null 2>&1
check "'already running' is not a failure" "0" "$(wc -c <"$ROOT/mail.out" | tr -d ' ')"

fixture
make_backup "2026-09-14--10-00"
echo "Steve joined the game" >"$ROOT/journal.txt"
stub_rcon "Connection refused" 1
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >/dev/null 2>&1
check "a failed rcon trigger is reported" "1" "$(grep -c 'rcon' "$ROOT/mail.out")"

echo "== task 6a: waiting for the server to be ready =="

fixture
make_backup "2026-09-14--10-00"
echo "Steve joined the game" >"$ROOT/journal.txt"
stub_rcon "Connection refused" 1
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >"$ROOT/boot.out" 2>&1
check "rcon never answers -> reported" "1" "$(grep -c 'did not answer' "$ROOT/mail.out")"
check "rcon never answers -> no trigger attempted" "0" \
  "$(grep -c 'triggering a backup' "$ROOT/boot.out")"

fixture
make_backup "2026-09-14--10-00"
echo "Steve joined the game" >"$ROOT/journal.txt"
stub_rcon "ok" 0
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >"$ROOT/boot.out" 2>&1
check "rcon answers -> proceeds to trigger" "1" \
  "$(grep -c 'triggering a backup' "$ROOT/boot.out")"

echo "== task 6b: installer =="

T=$(mktemp -d)
mkdir -p "$T/etc/systemd/system"
printf 'ExecStop=/x/mcrcon -H 127.0.0.1 -P 25575 -p derivedsecret stop\n' \
  >"$T/etc/systemd/system/minecraft.service"
"$INSTALLER" --prefix "$T" --backup-dir /b --tier-root /t --rcon-bin /x/mcrcon >/dev/null 2>&1
check "config is mode 600" "600" "$(stat -c %a "$T/etc/mc-backup-tier.conf")"
check "rcon password derived from the unit" "1" \
  "$(grep -c 'derivedsecret' "$T/etc/mc-backup-tier.conf")"
check "installed config is loadable by the script" "0" \
  "$(
    MC_BACKUP_TIER_CONFIG="$T/etc/mc-backup-tier.conf" "$SCRIPT" --help >/dev/null 2>&1
    echo $?
  )"
rm -rf "$T"

echo "== task 7: play that continues past the last backup =="

# The case a join-only check misses: joined before the newest backup, kept
# playing after it, so only the leave event is newer than the backup.
fixture
make_backup "2026-09-16--23-45"
echo "Steve left the game" >"$ROOT/journal.txt"
MC_BACKUP_TIER_CONFIG="$ROOT/conf" "$SCRIPT" --boot >"$ROOT/boot.out" 2>&1
check "a leave after the newest backup triggers" "1" \
  "$(grep -c 'triggering a backup' "$ROOT/boot.out")"

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
