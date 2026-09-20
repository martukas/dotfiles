#!/usr/bin/env bash
# Make sysstat record power/thermal data alongside its default CPU, memory and
# disk metrics, and keep a month of it rather than a week.
#
# sysstat is already present on Ubuntu -- ubuntu-standard depends on it -- but
# collects only DISK beyond the defaults and rotates after 7 days. Adding POWER
# captures temperature, fan speed, CPU clock, voltage, USB and battery, which is
# what makes "was this machine running hot last Tuesday?" answerable after the
# fact rather than only while it is happening.
#
# Deliberately no `set -e`: install.sh runs under it, and a machine with no
# thermal sensors -- or no sysstat at all -- must not abort the whole install.
# Problems here are reported and tolerated.

set -uo pipefail

CONF=/etc/sysstat/sysstat
DEFAULTS=/etc/default/sysstat
SA_DIR=/var/log/sysstat

# Set key=value in a shell-style config file, replacing an existing assignment
# or appending one if the key is absent. Exits 0 when the file was changed,
# 1 when it already held the wanted value.
set_kv() {
  local file=$1 key=$2 value=$3 current
  current=$(grep -E "^${key}=" "$file" 2>/dev/null | tail -1)
  if [[ $current == "${key}=${value}" ]]; then
    return 1
  fi
  if [[ -n $current ]]; then
    sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" | sudo tee -a "$file" >/dev/null
  fi
  return 0
}

if [[ ! -f $CONF ]]; then
  echo "sysstat: $CONF not found, skipping thermal logging setup"
  exit 0
fi

echo "Configuring sysstat (power/thermal logging, 30-day history)"

opts_changed=0
set_kv "$CONF" SADC_OPTIONS '"-S DISK,POWER"' && opts_changed=1
set_kv "$CONF" HISTORY 30 && echo "  history set to 30 days"

# The systemd units refuse to collect unless this is true; on some images it
# ships false.
if [[ -f $DEFAULTS ]]; then
  set_kv "$DEFAULTS" ENABLED '"true"' && echo "  collection enabled"
fi

# Each daily file records its activity set in the header. Appending POWER data
# to a file created without it does not error -- sadc writes happily and the
# file grows -- but `sar -m TEMP` then reports "Requested activities not
# available" for the rest of the day. Move today's file aside so the new set
# takes effect immediately instead of at midnight.
if [[ $opts_changed -eq 1 ]]; then
  echo "  recording: temperature, fan speed, CPU MHz, voltage, USB, battery"
  # sa1 switches from sa<DD> to sa<YYYYMMDD> once HISTORY exceeds 28, so the
  # file written before this run may carry either name. Rotate whichever exists.
  for today in "$SA_DIR/sa$(date +%d)" "$SA_DIR/sa$(date +%Y%m%d)"; do
    if [[ -f $today ]]; then
      sudo mv "$today" "$today.preexisting"
      echo "  rotated $(basename "$today") aside (was written without POWER)"
    fi
  done
fi

sudo systemctl enable --now sysstat.service sysstat-collect.timer \
  sysstat-rotate.timer >/dev/null 2>&1 \
  || echo "  warning: could not enable sysstat timers"

# Prime two samples so there is something to read back immediately.
sudo systemctl start sysstat-collect.service 2>/dev/null
sleep 2
sudo systemctl start sysstat-collect.service 2>/dev/null

if LC_ALL=C sar -m TEMP 2>/dev/null | grep -qE "^[0-9]"; then
  sensors_found=$(LC_ALL=C sar -m TEMP 2>/dev/null | grep -cE "^[0-9]")
  fans_found=$(LC_ALL=C sar -m FAN 2>/dev/null | grep -cE "^[0-9]")
  echo "  verified: $sensors_found temperature readings, $fans_found fan readings"
else
  echo "  note: no thermal sensors exposed on this machine; CPU/memory/disk still recorded"
fi

# Note: -m FREQ is a separate activity that POWER does not cover; CPU clock
# speed comes from -m CPU.
echo "  query later with: sar -m TEMP|FAN|CPU|BAT  (add -f $SA_DIR/<file> for past days)"
exit 0
