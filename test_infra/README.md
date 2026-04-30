# Test infrastructure

Two-tier VM-based test bed for validating `bootstrap.sh` / `install.sh` changes without touching the workstation. Both VMs sit on the dev host and get driven from there.

## Architecture

| Tier                        | Purpose                                                                                                                                                             | Where it falls short                                                |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `df26` (Multipass headless) | Cheap structural validation of `install.sh`: dotbot exit codes, file placement, command structure. Bind-mounts the host repo for fast edit-and-rerun.               | No graphical session, so anything gated on `XDG_CURRENT_DESKTOP` or that needs a real login (tray icons, autostart, dconf/xfconf restore, GUI sign-in flows) silently skips or no-ops. |
| `gui26` (libvirt + Xubuntu) | Full graphical-session validation. Real Xubuntu desktop, `openssh-server`, host-pubkey-authorized SSH with agent forwarding. Snapshot-based reset for fast loops.   | Slower than headless. Hardware-bound features (mice, displays) still need the workstation. |
| Target workstation          | Final fidelity. Hardware-bound features.                                                                                                                            | Don't iterate here — only confirm.                                  |

Don't conflate "install.sh exits clean in `df26`" with "feature works." Always name the layer when reporting test results.

## Host packages

On the Ubuntu 24.04 dev host:

```bash
sudo apt install virt-manager qemu-utils multipass
```

`virt-manager` pulls libvirt-daemon-system, libvirt-clients, virtinst. `qemu-utils` provides `qemu-img` (used by `gui-vm.sh` to create the VM disk). Re-login (or `newgrp libvirt`) after install so the user's `libvirt` group membership takes effect — though `gui-vm.sh` runs under `qemu:///session` and doesn't actually need it.

## `df26` — Multipass headless

### One-time setup

```bash
multipass launch daily:26.04 -n df26 -c 4 -m 4G -d 20G
multipass mount /home/martu/dev/dotfiles df26:/home/ubuntu/dev/dotfiles
multipass snapshot df26 --name pristine
```

### Iteration loop

```bash
# reset to pristine (re-mount may be needed after restore)
multipass stop df26 && multipass restore df26.pristine && multipass start df26
multipass mount /home/martu/dev/dotfiles df26:/home/ubuntu/dev/dotfiles

# inside the VM
multipass shell df26
cd /home/ubuntu/dev/dotfiles
export UV_PROJECT_ENVIRONMENT=$HOME/uv-venvs/superpack/.venv  # 9p bind-mount workaround for uv (see Gotchas)
./dotbot/bin/dotbot -d "$(pwd)" -c conf_common.yaml
./dotbot/bin/dotbot -d "$(pwd)" -c conf_linux.yaml
```

## `gui26` — libvirt + Xubuntu desktop

`test_infra/gui-vm.sh` is the lifecycle CLI:

| Subcommand                       | What it does                                                                                              |
| -------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `setup`                          | virt-install Xubuntu 26.04, attach ISO, open viewer, then bake openssh + host pubkey, snapshot `pristine`. One-time, ~30 min interactive. |
| `start`                          | `virsh start` if not running; open `virt-viewer`.                                                         |
| `reset [name]`                   | Force-off, revert to snapshot (default `pristine`), start, open viewer. Iteration entry point.            |
| `snapshot [name] [--replace]`    | Capture current state. VM must be off (use `sudo poweroff` from inside).                                  |
| `ssh [...]`                      | SSH into VM as `martu` with `-A` (agent forwarding) baked in. Forwards your host's ssh-agent so in-VM `git@github.com:` works without copying private keys. |
| `status`                         | Show VM state, snapshots, disks.                                                                          |
| `teardown --yes`                 | Destroy + undefine + remove only the qcow2 disk (not the ISO). Safe to re-run `setup` after.              |

Runs under `qemu:///session` (qemu as `$USER`), so no libvirt-group ACL concerns. VM disk lands in `~/.local/share/libvirt/images/`.

### One-time setup

Download Xubuntu 26.04 desktop ISO and place it at `~/Downloads/xubuntu-26.04-desktop-amd64.iso` (the path is hard-coded in `gui-vm.sh`; change there for a different ISO).

```bash
./test_infra/gui-vm.sh setup
```

This:
1. Creates an empty 30 GB qcow2 disk.
2. Stages `bake-gui26.sh` and `~/.ssh/id_ed25519.pub` in a tmp dir, starts `python3 -m http.server` on `127.0.0.1:8000` serving them.
3. Defines a libvirt domain (slirp networking with `hostfwd=tcp:127.0.0.1:2222-:22` injected via `<qemu:commandline>`).
4. Starts the VM, opens the spice viewer.

In the spice viewer:
- Click through the Xubuntu installer: locale, keyboard, "Erase disk and install" (single qcow2). **Skip** updates and **skip** third-party software (keeps pristine clean). User: `martu`. Hostname: `gui26`. No encryption.
- After install reboots into Xubuntu and you log in, open Terminal Emulator and run:
  ```
  wget -qO- http://10.0.2.2:8000/bake | bash
  ```
  The bake script installs `openssh-server`, authorizes the host pubkey, pre-populates `~/.ssh/known_hosts` with GitHub, then `sudo poweroff`s the VM.
- The host script detects shutoff, snapshots `pristine`, kills the http server, and exits.

### Baking `bootstrapped`

`bootstrapped` captures the post-bootstrap.sh, pre-install.sh state — repo cloned at `~/dev/dotfiles` with submodules synced. The install.sh test loop resets to this snapshot rather than re-running bootstrap each time.

1. **Agent**: `./test_infra/gui-vm.sh reset` — back to `pristine`, viewer opens.
2. **User**: log in to Xubuntu in the viewer (the user from `setup`).
3. **User**: in another host terminal, `./test_infra/gui-vm.sh ssh`. (`-A` is built in.)
4. **User**: in the SSH session:
   ```
   bash <(wget -qO- https://github.com/martukas/dotfiles/raw/<branch>/bootstrap/bootstrap.sh)
   ```
   (Use `master` normally. Use a feature branch when testing changes to bootstrap.sh / config_ssh.sh themselves — and remember to revert any branch pins before merging.)
5. **User**: drive bootstrap's prompts:
   - First "Press any key to continue..." (intro banner) → press any key.
   - `[sudo] password for <user>:` → enter the password set during Xubuntu install.
   - **config_ssh.sh** prints the `g/G | a/A | *` menu and asks `Type y to confirm:` → answer `n` (any non-`g`/`a`) so it uses agent forwarding.
   - "Press any key to test ssh connection to GitHub." → press any key. You should see `Hi <github-user>! You've successfully authenticated…`. That's proof agent forwarding works.
   - "Press any key to clone the dotfiles repository and continue setup." → press any key. Clones `git@github.com:martukas/dotfiles.git` into `~/dev/dotfiles`.
   - "Press any key to continue" (config_ssh.sh exit, **no ellipsis**) → press any key. Returns to bootstrap.sh.
   - bootstrap.sh prints `Bootstrapping complete. We will now run the rest of the rest of the dotfiles-managed installation scripts.`, then **"Press any key to continue..." (with three dots)**. **Ctrl+C** here. The three-dot prompt is the bootstrap.sh exit point just before it would call `./install.sh` — exactly the state we want to snapshot.
6. **User**: `sudo poweroff` inside the SSH session. SSH disconnects.
7. **Agent**: `./test_infra/gui-vm.sh status` to confirm shut off, then `./test_infra/gui-vm.sh snapshot bootstrapped`.

### Iteration loop (install.sh)

```bash
# host: clean post-bootstrap state in ~10s
./test_infra/gui-vm.sh reset bootstrapped

# host: agent SSH for diagnostics, OR user SSH for driving install.sh
./test_infra/gui-vm.sh ssh
#   inside: cd ~/dev/dotfiles && git pull && ./install.sh
```

The user always drives `install.sh` (superpack TUI requires real input). Agent SSH access is for read-mostly investigation between cycles — see `CLAUDE.md` (repo root) for the full division of labor.

`bootstrapped` is re-baked rarely — only when `bootstrap.sh` / `config_ssh.sh` themselves change, or when the snapshot drifts so far from current code that pulls become unwieldy.

## Adapting to a new distro / version

Most install-time behavior already routes through `linux/_distro.sh` (`DISTRO_VERSION_MAJOR`, `DISTRO_CODENAME`), so the test bed itself is what needs adjusting:

- **df<version>** (Multipass): change the `daily:<version>` channel in `multipass launch`, rename the instance (`df<version>`), keep the snapshot name `pristine` for consistency.
- **gui<version>** (libvirt): download the matching desktop ISO, update `ISO` and `NAME` constants in `test_infra/gui-vm.sh`, update the apt prereqs in `test_infra/bake-gui26.sh` if a package has been renamed/dropped. Then run `gui-vm.sh setup` and re-bake `bootstrapped` per the steps above.
- **bootstrap branch refs**: `bootstrap/bootstrap.sh`, `bootstrap/bootstrap.ps1`, `bootstrap/config_ssh.sh` reference a branch (normally `master`) for raw fetches and submodule clones. Pin to a feature branch when testing bootstrap.sh changes themselves, and revert before merging.

`pristine` and `bootstrapped` snapshot names stay constant per VM — `gui-vm.sh reset bootstrapped` should always mean "post-bootstrap, pre-install" regardless of which distro you're targeting.

## Gotchas (stable / inherent)

### libvirt + `gui26`

- **`qemu:///session` is the right connection mode**. System mode would require granting `libvirt-qemu` ACL traversal of `$HOME` to access the ISO — broader than needed. Trade-off: networking is user-mode slirp, no LAN-visible IP. Fine for testing.
- **libvirt snapshots include the domain XML at snapshot time.** `snapshot-revert` restores both disk and config. If you change XML after the snapshot is taken, the change gets reverted on the next reset — re-snapshot to bake it in.
- **xfce4-power-manager intercepts ACPI shutdown** by default. `virsh shutdown` triggers a "Confirm shutdown" dialog inside the VM that the host can't auto-click. Use `sudo poweroff` inside the VM (or via SSH); `gui-vm.sh reset` uses `virsh destroy` (force-off) instead.
- **`virsh undefine --remove-all-storage` deletes EVERY attached storage volume**, including CDROM ISOs whose source is in `~/Downloads`. Footgun. `gui-vm.sh teardown` undefines without that flag and manually `rm`s only the qcow2 under `~/.local/share/libvirt/images/`, with a path-prefix safety check.
- **PCI slot conflicts when injecting devices via `<qemu:commandline>`**: libvirt auto-assigns slots for everything in `<devices>`; a qemu-cli-injected `virtio-net-pci` without an explicit slot collides. `gui-vm.sh` pins `addr=0x10` on the injected NIC for clear margin.
- **`passt 0.0~git20240220-1` (Ubuntu 24.04 main) segfaults under libvirt's invocation.** libvirt's `<portForward>` element requires passt; slirp doesn't support port forwarding via libvirt's native config. Workaround: bypass libvirt's `<interface>` and inject `-netdev user,...,hostfwd=...` plus `-device virtio-net-pci,...` via `<qemu:commandline>`. Slirp's hostfwd works fine.
- **Spice clipboard sharing is unreliable for multi-line pastes** (`\n` and indentation get mangled). Use a single-line `wget -qO- ... | bash` for any in-VM bake step.
- **Viewer caveat**: `gui-vm.sh start` and `reset` background `virt-viewer` with stderr suppressed and always print "viewer opened." Confirm visually before assuming the viewer actually came up — DISPLAY/X-auth issues silently fail.

### Multipass + `df26`

- **9p bind-mount blocks symlink creation INSIDE the mount.** Hit this with `uv sync` trying to create `.venv/bin/python -> /usr/bin/python3`. Workaround for testing: `export UV_PROJECT_ENVIRONMENT=$HOME/uv-venvs/superpack/.venv` (puts the venv outside the mount). NOT a real-machine issue.
- Symlinks in `$HOME` *pointing into* the bind mount work fine — different operation.
- 26.04 cloud images already have `git`, `curl`, `wget`, `ssh`, `snap` installed. `bootstrap.sh`'s apt install is redundant on cloud, still needed on the desktop ISO.
- `private/` submodule's SSH URL doesn't block VM testing — the host has it initialized, the bind mount surfaces the data without needing network access from the VM.
