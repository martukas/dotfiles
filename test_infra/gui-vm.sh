#!/usr/bin/env bash
# Lifecycle CLI for the GUI VM (Ubuntu 26.04 dotfiles testing — graphical-session features).
# Companion: bake-gui26.sh (runs once inside the VM during initial bake).
# Context:   .claude/ubuntu26-progress.md.
#
# Runs under qemu:///session (user-mode libvirt) — qemu runs as $USER. No system
# permissions or ACLs needed. VM disk lands in ~/.local/share/libvirt/qemu/.
#
# Usage: gui-vm.sh <subcommand>
#
#   setup             Build the VM end-to-end. Creates the qcow2, defines the domain,
#                     starts a host HTTP server serving the bake script + pubkey, opens
#                     the viewer for the interactive Xubuntu installer, waits for the
#                     in-VM bake to power off, then auto-snapshots `pristine`.
#                     Single host command. Only manual step is the Xubuntu installer
#                     itself + one curl-bash line in the VM after first reboot.
#   start             Boot the VM (no-op if already running) and open the spice viewer.
#   reset             Force-off if running, revert to `pristine`, start, open viewer.
#   ssh [cmd...]      SSH into the VM as martu (waits up to 60s for sshd). With cmd,
#                     runs it remotely; without, opens an interactive session.
#   snapshot          Re-capture `pristine` from a shut-off VM (rare — setup auto-snaps).
#                     Refuses to overwrite; pass --replace to delete existing first.
#   teardown --yes    Destroy + undefine + remove storage + remove snapshots. Destructive.
#   status            Show VM state, snapshots, and disk path.
#
# VM specs:
#   name=gui26  vCPU=4  RAM=4 GiB  disk=30 GiB
#   net=user-mode (slirp via qemu:commandline) with hostfwd 127.0.0.1:2222 → guest 22
#   graphics=spice  ssh-key authorized = $HOME/.ssh/id_ed25519.pub
#
# Host prereqs: virsh, virt-viewer, qemu-system-x86_64, qemu-img, python3.
#               (Apt: virt-manager pulls libvirt+virtinst; qemu-utils for qemu-img.)

set -euo pipefail

export LIBVIRT_DEFAULT_URI=qemu:///session

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAKE_SCRIPT="$SCRIPT_DIR/bake-gui26.sh"

NAME=gui26
VCPUS=4
RAM_MB=4096
DISK_GB=30
SNAPSHOT=pristine
ISO="$HOME/Downloads/xubuntu-26.04-desktop-amd64.iso"
DISK_PATH="$HOME/.local/share/libvirt/images/$NAME.qcow2"
SSH_PORT=2222
SSH_USER=martu
SSH_OPTS=(-p "$SSH_PORT" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
HOST_PUBKEY="$HOME/.ssh/id_ed25519.pub"
HTTP_PORT=8000
SETUP_TIMEOUT=3600  # seconds — covers Xubuntu install + bake

usage() {
    sed -n '/^# Usage:/,/^# Host prereqs/p' "$0" | sed 's/^# \?//' >&2
    exit 1
}

is_defined() { virsh dominfo "$NAME" >/dev/null 2>&1; }

require_defined() {
    is_defined || { echo "VM '$NAME' is not defined. Run: $0 setup" >&2; exit 1; }
}

domstate() { virsh domstate "$NAME" 2>/dev/null || echo "undefined"; }

snapshot_exists() { virsh snapshot-info "$NAME" "$SNAPSHOT" >/dev/null 2>&1; }

wait_for_shutoff() {
    local timeout=${1:-90} i=0
    while (( i < timeout )); do
        [[ "$(domstate)" == "shut off" ]] && return 0
        sleep 1
        i=$((i+1))
    done
    echo "Timed out waiting for $NAME to shut off after ${timeout}s." >&2
    return 1
}

wait_for_ssh() {
    local timeout=${1:-60} i=0
    while (( i < timeout )); do
        ssh "${SSH_OPTS[@]}" -o ConnectTimeout=2 -o BatchMode=yes \
            "$SSH_USER@localhost" true 2>/dev/null && return 0
        sleep 1
        i=$((i+1))
    done
    echo "Timed out waiting for sshd on $SSH_PORT after ${timeout}s." >&2
    return 1
}

open_viewer() {
    virt-viewer "$NAME" >/dev/null 2>&1 &
    disown
}

# Used by cmd_setup. Builds a fresh domain XML in $1 with hostfwd via qemu:commandline.
write_domain_xml() {
    local out=$1
    cat > "$out" <<EOF
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>$NAME</name>
  <memory unit='KiB'>$((RAM_MB * 1024))</memory>
  <vcpu placement='static'>$VCPUS</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='hd'/>
    <boot dev='cdrom'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none'/>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='$DISK_PATH'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='$ISO'/>
      <target dev='hdc' bus='ide'/>
      <readonly/>
    </disk>
    <controller type='usb' model='qemu-xhci' ports='15'/>
    <input type='tablet' bus='usb'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='spice' autoport='yes'>
      <listen type='address'/>
      <image compression='off'/>
    </graphics>
    <video>
      <model type='qxl' heads='1' primary='yes'/>
    </video>
    <sound model='ich9'/>
    <audio id='1' type='spice'/>
    <channel type='spicevmc'>
      <target type='virtio' name='com.redhat.spice.0'/>
    </channel>
    <serial type='pty'><target port='0'/></serial>
    <console type='pty'><target type='serial' port='0'/></console>
    <memballoon model='virtio'/>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
    </rng>
  </devices>
  <qemu:commandline>
    <qemu:arg value='-netdev'/>
    <qemu:arg value='user,id=hostnet0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22'/>
    <qemu:arg value='-device'/>
    <qemu:arg value='virtio-net-pci,netdev=hostnet0,bus=pci.0,addr=0x10'/>
  </qemu:commandline>
</domain>
EOF
}

cmd_start() {
    require_defined
    [[ "$(domstate)" == "running" ]] || virsh start "$NAME"
    open_viewer
    echo "VM '$NAME' is running; viewer opened."
}

cmd_setup() {
    [[ -f "$ISO" ]]              || { echo "ISO not found: $ISO" >&2; exit 1; }
    [[ -f "$HOST_PUBKEY" ]]      || { echo "Host pubkey not found: $HOST_PUBKEY" >&2; exit 1; }
    [[ -x "$BAKE_SCRIPT" ]]      || { echo "Bake script not found/executable: $BAKE_SCRIPT" >&2; exit 1; }
    command -v qemu-img >/dev/null || { echo "qemu-img not installed (apt: qemu-utils)" >&2; exit 1; }
    command -v python3  >/dev/null || { echo "python3 not installed" >&2; exit 1; }
    if is_defined; then
        echo "VM '$NAME' already defined. Use 'reset' or 'teardown --yes'." >&2
        exit 1
    fi
    if ss -tln 2>/dev/null | grep -qE "127\.0\.0\.1:$HTTP_PORT\b"; then
        echo "Host port $HTTP_PORT is already in use. Free it or change HTTP_PORT in $0." >&2
        exit 1
    fi
    [[ -e "$DISK_PATH" ]] && { echo "Disk already exists: $DISK_PATH" >&2; exit 1; }

    mkdir -p "$(dirname "$DISK_PATH")"
    qemu-img create -f qcow2 "$DISK_PATH" "${DISK_GB}G" >/dev/null

    # Hoisted out of `local` so the EXIT trap can still see them after a fail.
    SETUP_STAGE=$(mktemp -d /tmp/gui-vm-bake.XXXXXX)
    cp "$BAKE_SCRIPT" "$SETUP_STAGE/bake"
    cp "$HOST_PUBKEY" "$SETUP_STAGE/authorized_key"

    # Background HTTP server. Bound to loopback; reachable from VM via slirp gateway 10.0.2.2.
    (cd "$SETUP_STAGE" && exec python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1) \
        >"$SETUP_STAGE/http.log" 2>&1 &
    SETUP_HTTP_PID=$!

    cleanup() {
        [[ -n "${SETUP_HTTP_PID:-}" ]] && kill "$SETUP_HTTP_PID" 2>/dev/null || true
        [[ -n "${SETUP_STAGE:-}" ]] && rm -rf "$SETUP_STAGE"
    }
    trap cleanup EXIT

    write_domain_xml "$SETUP_STAGE/domain.xml"
    virsh define "$SETUP_STAGE/domain.xml" >/dev/null
    virsh start  "$NAME" >/dev/null
    open_viewer

    cat <<EOF
============================================================================
gui26 setup in progress. Spice viewer is opening.

Manual steps:
  1. Click through the Xubuntu installer:
       - locale, keyboard, "Erase disk and install" (single qcow2)
       - skip updates and third-party software
       - user: $SSH_USER   hostname: $NAME   no encryption
  2. After install reboots and you log in, open Terminal Emulator and run:

       wget -qO- http://10.0.2.2:$HTTP_PORT/bake | bash

The bake script will install openssh-server, authorize this host's pubkey,
and 'sudo poweroff' the VM. This script then snapshots 'pristine' and exits.

Waiting up to $((SETUP_TIMEOUT / 60)) min for the VM to shut off...
============================================================================
EOF

    local i=0
    while (( i < SETUP_TIMEOUT )); do
        [[ "$(domstate)" == "shut off" ]] && break
        sleep 5
        i=$((i+5))
    done

    if [[ "$(domstate)" != "shut off" ]]; then
        echo "Timed out (state='$(domstate)') after $((SETUP_TIMEOUT / 60)) min." >&2
        echo "If the VM is mid-install, run '$0 setup' again later, or run" >&2
        echo "  '$0 snapshot' once the VM is shut off." >&2
        exit 1
    fi

    echo "VM is shut off. Creating '$SNAPSHOT' snapshot..."
    virsh snapshot-create-as "$NAME" "$SNAPSHOT" "post-install pristine state" >/dev/null
    echo "Done. Smoke test:  $0 reset && $0 ssh hostname"
}

cmd_snapshot() {
    require_defined
    local replace="${1:-}"
    if snapshot_exists; then
        if [[ "$replace" == "--replace" ]]; then
            echo "Deleting existing '$SNAPSHOT' snapshot..."
            virsh snapshot-delete "$NAME" "$SNAPSHOT"
        else
            echo "Snapshot '$SNAPSHOT' already exists. Pass --replace to overwrite." >&2
            exit 1
        fi
    fi
    if [[ "$(domstate)" != "shut off" ]]; then
        echo "Shutting down $NAME ..."
        virsh shutdown "$NAME" >/dev/null
        wait_for_shutoff
    fi
    virsh snapshot-create-as "$NAME" "$SNAPSHOT" "post-install pristine state"
}

cmd_reset() {
    require_defined
    snapshot_exists || { echo "Snapshot '$SNAPSHOT' does not exist. Run: $0 setup" >&2; exit 1; }
    if [[ "$(domstate)" == "running" ]]; then
        virsh destroy "$NAME" >/dev/null
    fi
    virsh snapshot-revert "$NAME" "$SNAPSHOT"
    virsh start "$NAME"
    open_viewer
}

cmd_ssh() {
    require_defined
    [[ "$(domstate)" == "running" ]] || { echo "VM is not running. Use: $0 start or reset" >&2; exit 1; }
    wait_for_ssh || exit 1
    ssh "${SSH_OPTS[@]}" "$SSH_USER@localhost" "$@"
}

cmd_teardown() {
    if [[ "${1:-}" != "--yes" ]]; then
        echo "Refusing destructive teardown without --yes." >&2
        echo "Removes the VM, its qcow2 disk, and all snapshots. Leaves the ISO alone." >&2
        echo "Run: $0 teardown --yes" >&2
        exit 1
    fi
    # Safety: only delete a path under the user's libvirt images dir.
    local safe_prefix="$HOME/.local/share/libvirt/images/"
    if [[ -n "${DISK_PATH:-}" && "$DISK_PATH" != "$safe_prefix"* ]]; then
        echo "Refusing to delete DISK_PATH outside $safe_prefix: $DISK_PATH" >&2
        exit 1
    fi
    if is_defined; then
        if [[ "$(domstate)" == "running" ]]; then
            virsh destroy "$NAME" >/dev/null
        fi
        # NOT --remove-all-storage: that nukes EVERY attached volume, including
        # the CDROM ISO. We only want to remove the qcow2 disk we created.
        virsh undefine "$NAME" --snapshots-metadata
    fi
    [[ -e "$DISK_PATH" ]] && rm -f "$DISK_PATH"
}

cmd_status() {
    if ! is_defined; then
        echo "VM '$NAME' is not defined."
        return 0
    fi
    virsh dominfo "$NAME"
    echo
    echo "--- Snapshots ---"
    virsh snapshot-list "$NAME"
    echo
    echo "--- Disks ---"
    virsh domblklist "$NAME"
}

case "${1:-}" in
    setup)             cmd_setup ;;
    start)             cmd_start ;;
    snapshot)          cmd_snapshot "${2:-}" ;;
    reset)             cmd_reset ;;
    ssh)               cmd_ssh "${@:2}" ;;
    teardown)          cmd_teardown "${2:-}" ;;
    status)            cmd_status ;;
    -h|--help|help|"") usage ;;
    *)                 echo "Unknown subcommand: $1" >&2; usage ;;
esac
