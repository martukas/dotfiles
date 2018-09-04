#!/bin/bash

EXIT_FAILURE=1
EXIT_SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

# Check if Linux
PLATFORM="$(uname -s)"
if [ "${PLATFORM}" != "Linux" ]; then
  echo "Error: This script only supports 'Linux'. You have $PLATFORM."
  exit $EXIT_FAILURE
fi

# Make sure we are not in sudo
if [ "${EUID}" -eq 0 ] && [ "$2" != "-f" ]; then
  echo "Please do not run this script with root privileges!"
  exit $EXIT_FAILURE
fi

# This script should work no matter where you call it from.
cd "$(dirname "$0")"

echo "==============================================================="
echo "============== MGS personal bootstrapper - Linux =============="
echo "==============================================================="
echo " "
echo "  -- installs essentials: git, ssh, python, xclip"
echo "  -- configures ssh & github credentials"
echo "  -- clones the dotfile repository"
echo " "
read -n1 -srp $'Press any key to continue...\n' key

### Install git-lfs
sudo apt --install-suggests install git-lfs ssh python3-pip python-is-python3 xclip

./config_ssh.sh "python -m webbrowser"

echo "Bootstrapping complete. We will now run the rest of the rest of the dotfiles-managed installation scripts."
echo " "
read -n1 -srp $'Press any key to continue...\n' key

cd "${HOME}/dev/dotfiles/"
./install.sh
