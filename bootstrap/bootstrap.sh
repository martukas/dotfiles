#!/bin/bash

# shellcheck disable=SC2034
FAILURE=1
# shellcheck disable=SC2034
SUCCESS=0

# Check if Linux
case "${OSTYPE}" in
  linux*) ;;
  *)
    echo "Error: This script only supports linux. You have: $OSTYPE."
    exit $FAILURE
    ;;
esac

# Fail if any command fails
set -e
set -o pipefail

# Make sure we are not in sudo
if [ "${EUID}" -eq 0 ] && [ "$2" != "-f" ]; then
  echo "Please do not run this script with root privileges!"
  exit $FAILURE
fi

echo "==============================================================="
echo "============== MGS personal bootstrapper - Linux =============="
echo "==============================================================="
echo " "
echo "  -- installs essentials: git, ssh, python, xclip"
echo "  -- configures ssh & github credentials"
echo "  -- clones the dotfile repository"
echo " "
read -n1 -srp $'Press any key to continue...\n' _

### Install git-lfs
sudo apt update
sudo apt --yes install curl git-lfs ssh python3-pip python-is-python3 xclip

browser_call='echo [RUNNING HEADLESS] Please open this URL manually: '
if [ -n "$DISPLAY" ]; then
  echo "GUI Enabled"
  browser_call="python -m webbrowser"
fi

wget 'https://github.com/martukas/dotfiles/raw/master/bootstrap/config_ssh.sh'
chmod +x ./config_ssh.sh
./config_ssh.sh "$browser_call"
rm ./config_ssh.sh

echo "Bootstrapping complete. We will now run the rest of the rest of the dotfiles-managed installation scripts."
echo " "
read -n1 -srp $'Press any key to continue...\n' _

cd "${HOME}/dev/dotfiles/"
./install.sh
