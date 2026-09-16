# systemd units

Units here are generic. Everything host-specific lives in a config file under `/etc/`, which is deliberately not in this
repo.

## mc-backup-tier

Promotes Minecraft world backups out of the backup mod's own rotation into longer-lived tiers, and takes one conditional
backup after a server restart.

The mod keeps only the newest N backups, so a single long play session evicts every earlier session's history. This
promotes selected archives — by hardlink, so it costs no extra space at promotion time — into directories the mod does
not manage, giving one restore point per play-day and one per played week.

### Install

Run the installer from a checkout of this repo, as root:

```sh
sudo linux/bin/mc-backup-tier-install \
  --backup-dir /opt/minecraft/server/backups/world \
  --tier-root  /opt/minecraft/tiers \
  --rcon-bin   /opt/minecraft/tools/mcrcon/mcrcon
```

It installs the script to `/usr/local/bin`, the three units to `/etc/systemd/system`, writes `/etc/mc-backup-tier.conf`
at mode 600, and reloads systemd. The RCON password is **derived from the Minecraft unit's `ExecStop` line**, so it
never has to be typed or pasted; override with `--rcon-pass` if your setup differs.

`--dry-run` prints what it would do. `--prefix DIR` redirects every path under DIR, which is how the installer is tested
without root. `--help` lists the rest: `--mc-unit`, `--rcon-host`, `--rcon-port`, `--daily-keep`, `--weekly-keep`,
`--notify`, `--min-free-mb`.

Then activate:

```sh
sudo systemctl enable --now mc-backup-tier.timer
sudo systemctl enable mc-backup-tier-boot.service
```

The script is installed to `/usr/local/bin` rather than symlinked from a checkout, because systemd units should not
depend on a user's home directory being present and readable. This is why it does not follow the dotbot pattern used by
`kvm-display` and `redshift-launch`.

It runs as root because a server directory is typically not traversable by an ordinary account.

`TIER_ROOT` must be on the same filesystem as `BACKUP_DIR`, since promotion uses hardlinks. Keep it *outside* the backup
mod's own directory so the mod never scans it.

Optional config keys, with defaults, that the installer does not currently set:

```ini
RCON_WAIT_SECS=600   # how long --boot waits for the server to answer
RCON_POLL_SECS=5     # interval between those attempts
```

### Behaviour

`--promote`, hourly: promotes the oldest eligible backup of each UTC day into `$TIER_ROOT/daily`, the oldest of each ISO
week into `$TIER_ROOT/weekly`, prunes both, and reports any zero-byte artifact.

`--boot`, once per start: waits for the server to answer RCON, then triggers one backup **only if** someone played since
the newest existing backup. This is what provides a "before I started playing" restore point without taking a pointless
backup on nights nobody logged in.

A backup is eligible only if its `.backupinfo` is non-empty — the mod writes it on completion, so its presence means the
archive is finished rather than still being written.

Failures are mailed to `NOTIFY_ADDR` as a single message listing everything wrong. **Successful runs are silent**, so
mail from this means something needs attention.

### Tests

`bash linux/test_mc_backup_tier.sh` — runs unprivileged against a fixture tree in `mktemp -d`. No root, no server, no
network.
