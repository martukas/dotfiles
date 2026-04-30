#!/usr/bin/env bash
# Run inside the gui26 VM ONCE after Xubuntu install completes and you log in.
# Fetched from the host via gui-vm.sh setup's temporary HTTP server, see
# .claude/ubuntu26-progress.md.
#
# What it does:
#   - installs and starts openssh-server
#   - authorizes the host's pubkey for SSH
#   - shuts down the VM (the host snapshots `pristine` afterward)
#
# Don't run this directly on a real machine. It's only meant for the gui26 bake.

set -euo pipefail

HTTP_HOST=${HTTP_HOST:-10.0.2.2}
HTTP_PORT=${HTTP_PORT:-8000}
HTTP_BASE="http://${HTTP_HOST}:${HTTP_PORT}"

echo "[bake] apt update + install openssh-server"
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

echo "[bake] enabling + starting ssh"
sudo systemctl enable --now ssh

echo "[bake] authorizing host pubkey from ${HTTP_BASE}/authorized_key"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
wget -qO ~/.ssh/authorized_keys "${HTTP_BASE}/authorized_key"
chmod 600 ~/.ssh/authorized_keys

echo "[bake] done. powering off so host can snapshot."
sudo poweroff
