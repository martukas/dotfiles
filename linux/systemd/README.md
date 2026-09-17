# systemd units

Units here are generic. Everything host-specific lives in a config file under `/etc/`, deliberately not in this repo.

## mc-backup-tier

Rescues Minecraft world backups out of the backup mod's own rotation, by hardlink, into tiers it does not manage: one
restore point per play-day and one per played week. Also takes one backup after a server restart, but only if someone
played since the newest existing backup.

### Install

```sh
sudo linux/bin/mc-backup-tier-install \
  --backup-dir  /opt/minecraft/server/backups/world \
  --tier-root   /opt/minecraft/tiers \
  --rcon-bin    /opt/minecraft/tools/mcrcon/mcrcon \
  --state-paths "server.properties ops.json whitelist.json usercache.json \
usernamecache.json banned-players.json banned-ips.json prestige \
local/local_mercurius.cfg astralsorcery/gatewayFilter/worldFilter.dat"

sudo systemctl enable --now mc-backup-tier.timer
sudo systemctl enable mc-backup-tier-boot.service
```

The RCON password is derived from the Minecraft unit's `ExecStop` line, so it never has to be typed. `--dry-run`,
`--prefix DIR` and `--help` cover the rest.

Two things the installer cannot check for you:

- `TIER_ROOT` must be on the same filesystem as `BACKUP_DIR` — promotion uses hardlinks — and **outside** the mod's own
  directory, so the mod never scans it.
- Optional keys it does not set: `RCON_WAIT_SECS` (default 600, how long `--boot` waits for the server to answer) and
  `RCON_POLL_SECS` (default 5).
- `--state-paths` defaults to the vanilla server-level files only. Anything a pack keeps outside `world/` has to be
  named explicitly, as above; paths that do not exist are skipped rather than reported.

### Behaviour

`--promote` runs hourly: promotes the oldest eligible backup of each UTC day and each ISO week, prunes both tiers, and
reports any zero-byte artifact. A backup is eligible only once its `.backupinfo` is non-empty, which is how a
half-written archive is excluded.

Each promoted archive gets a `.state.tar.gz` sidecar beside it, holding the `STATE_PATHS` from `SERVER_DIR`. The mod
archives `world/` and nothing else, but a world is not restorable without the server-level state describing its players.
Daily builds the sidecar; weekly hardlinks the daily one, so both entries describe the same moment. Pruning removes a
sidecar with its archive. That state is only rewritten at server start and stop, so a snapshot taken at promotion time
is internally consistent.

Failures are mailed to `NOTIFY_ADDR` as one message. **Successful runs are silent**, so mail from this means something
needs attention.

### Tests

`bash linux/test_mc_backup_tier.sh` — unprivileged, against a fixture tree in `mktemp -d`. No root, no server, no
network.
