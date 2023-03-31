#!/bin/bash

FAILURE=1
SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

function exit_success() {
  echo " "
  read -n1 -srp $'Press any key to continue...\n' key
  exit $SUCCESS
}

function install_logiops() {
  sudo apt install build-essential cmake libevdev-dev libudev-dev libconfig++-dev
  mkdir -p logiops/build
  pushd logiops/build
  cmake .. && make && sudo make install
  popd
  sudo /usr/bin/cp -fr logid.cfg /etc/logid.cfg
}

function install_nerdfonts() {
  declare -a fonts=(
      Hack
      Meslo
  )

  version='2.1.0'
  fonts_dir="${HOME}/.local/share/fonts"

  if [[ ! -d "$fonts_dir" ]]; then
      mkdir -p "$fonts_dir"
  fi

  for font in "${fonts[@]}"; do
      zip_file="${font}.zip"
      download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${zip_file}"
      echo "Downloading $download_url"
      wget "$download_url"
      sudo unzip "$zip_file" -d "$fonts_dir"
      rm "$zip_file"
  done

  sudo find "$fonts_dir" -name '*Windows Compatible*' -delete

  fc-cache -fv
}

function install_nvm() {
  sudo apt --install-suggests install build-essential libssl-dev
  export NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
  ) && \. "$NVM_DIR/nvm.sh"
}

function install_platformio() {
  python3 -c "$(curl -fsSL https://raw.githubusercontent.com/platformio/platformio/master/scripts/get-platformio.py)"
  ln -s ~/.platformio/penv/bin/platformio ~/.local/bin/platformio
  ln -s ~/.platformio/penv/bin/pio ~/.local/bin/pio
  ln -s ~/.platformio/penv/bin/piodebuggdb ~/.local/bin/piodebuggdb
  curl -fsSL https://raw.githubusercontent.com/platformio/platformio-core/develop/platformio/assets/system/99-platformio-udev.rules | sudo tee /etc/udev/rules.d/99-platformio-udev.rules
  sudo usermod -a -G dialout $USER
  sudo usermod -a -G plugdev $USER
  sudo service udev restart
}

# Script will run in its own path no matter where it's called from.
pushd "$(dirname "$0")"

if [ "$1" == "test" ]; then
  echo "---=== TEST CLAUSE OR PLACEHOLDER ===---"
  echo "  Will not actually install anything."
  exit_success

elif [ "$1" == "install-logiops" ]; then
  install_logiops
  exit_success

elif [ "$1" == "install-nerdfonts" ]; then
  install_logiops
  exit_success

elif [ "$1" == "install-rust" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  exit_success

elif [ "$1" == "install-nvm" ]; then
  install_nvm
  exit_success

elif [ "$1" == "check-nvm" ]; then
  if [[ $(command -v nvm) ]]; then
    echo "nvm present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-platformio" ]; then
  install_platformio
  exit_success

else
  echo "ERROR: Bad command or insufficient parameters!"
  echo " "
  exit $FAILURE
fi

popd