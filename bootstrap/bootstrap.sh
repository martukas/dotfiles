#!/bin/bash

FAILURE=1
SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

# Check if Linux
PLATFORM="$(uname -s)"
if [ "${PLATFORM}" != "Linux" ]; then
  echo "Error: This script only supports 'Linux'. You have $PLATFORM."
  exit $FAILURE
fi

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
read -n1 -srp $'Press any key to continue...\n' key

# \TODO: change to point to master before merging
wget https://github.com/martukas/dotfiles/raw/bootstrapping/bootstrap/config_ssh.sh
chmod +x ./config_ssh.sh
./config_ssh.sh "python -m webbrowser"
wget -qO - 'https://github.com/martukas/dotfiles/raw/bootstrapping/bootstrap/config_ssh.sh' | bash -s "python -m webbrowser"

exit $SUCCESS

### Install git-lfs
sudo apt --yes install curl git-lfs ssh python3-pip python-is-python3 xclip

./config_ssh.sh "python -m webbrowser"

echo "Bootstrapping complete. We will now run the rest of the rest of the dotfiles-managed installation scripts."
echo " "
read -n1 -srp $'Press any key to continue...\n' key
rm ./config_ssh.sh
exit $SUCCESS

cd "${HOME}/dev/dotfiles/"
./install.sh
