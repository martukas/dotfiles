#!/bin/bash
# shellcheck disable=SC2317

FAILURE=1
SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

#silent pushd
pushd() {
  command pushd "$@" >/dev/null
}

#silent popd
popd() {
  command popd >/dev/null
}

function prompt_exit() {
  echo " "
  read -n1 -srp $'Press any key to continue...\n' _
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

function install_powershell() {
  snap install powershell --classic
  brew install jandedobbeleer/oh-my-posh/oh-my-posh
  ../windows/packages.ps1 default-modules
}

function install_nerdfonts() {
  declare -a fonts=(
    Hack
    Meslo
  )

  version='2.1.0'
  fonts_dir="${HOME}/.local/share/fonts"

  if [[ ! -d $fonts_dir ]]; then
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
  sudo apt --yes install build-essential libssl-dev
  # shellcheck disable=SC1091
  export NVM_DIR="$HOME/.nvm" && (
    git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
    cd "$NVM_DIR"
    # shellcheck disable=SC2046
    # shellcheck disable=SC2006
    git checkout $(git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1))
  ) && \. "$NVM_DIR/nvm.sh"
}

function install_platformio() {
  python3 -c "$(curl -fsSL https://raw.githubusercontent.com/platformio/platformio/master/scripts/get-platformio.py)"
  ln -s "${HOME}/.platformio/penv/bin/platformio" "${HOME}/.local/bin/platformio"
  ln -s "${HOME}/.platformio/penv/bin/pio" "${HOME}/.local/bin/pio"
  ln -s "${HOME}/.platformio/penv/bin/piodebuggdb" "${HOME}/.local/bin/piodebuggdb"
  curl -fsSL https://raw.githubusercontent.com/platformio/platformio-core/develop/platformio/assets/system/99-platformio-udev.rules | sudo tee /etc/udev/rules.d/99-platformio-udev.rules
  sudo usermod -a -G dialout "$USER"
  sudo usermod -a -G plugdev "$USER"
  sudo service udev restart
}

function install_insync() {
  # see https://www.insynchq.com/downloads/linux
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
  # shellcheck disable=SC1091
  source /etc/lsb-release
  echo "deb http://apt.insync.io/ubuntu $DISTRIB_CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
  sudo apt update
  sudo apt install insync
}

function install_keepass_plugins() {
  pushd /usr/lib/keepass2/Plugins
  sudo wget https://github.com/xatupal/KeeTheme/releases/latest/download/KeeTheme.dll
  sudo wget https://github.com/xatupal/KeeTheme/releases/latest/download/KeeTheme.plgx
  sudo mkdir DarkenKP
  pushd DarkenKP
  sudo wget https://github.com/BradyThe/DarkenKP/releases/latest/download/KeeTheme.ini
}

function install_jetbrains() {
  #Adapted from https://github.com/nagygergo/jetbrains-toolbox-install

  echo -e " \e[94mInstalling Jetbrains Toolbox\e[39m"

  sudo apt --yes install libfuse2

  USER_AGENT=('User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36')

  URL=$(curl 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' -H 'Origin: https://www.jetbrains.com' -H 'Accept-Encoding: gzip, deflate, br' -H 'Accept-Language: en-US,en;q=0.8' -H "${USER_AGENT[@]}" -H 'Accept: application/json, text/javascript, */*; q=0.01' -H 'Referer: https://www.jetbrains.com/toolbox/download/' -H 'Connection: keep-alive' -H 'DNT: 1' --compressed | grep -Po '"linux":.*?[^\\]",' | awk -F ':' '{print $3,":"$4}' | sed 's/[", ]//g')
  echo "JetBrains download URL: $URL"

  FILE=$(basename "${URL}")
  DEST=$PWD/$FILE

  echo -e "\e[94mDownloading Toolbox files \e[39m"
  wget -cO "${DEST}" "${URL}" --read-timeout=5 --tries=0
  echo -e "\e[32mDownload complete!\e[39m"
  DIR="$PWD/jetbrains-toolbox"
  echo -e "\e[94mInstalling to $DIR\e[39m"
  mkdir "${DIR}"
  tar -xzf "${DEST}" -C "${DIR}" --strip-components=1

  chmod -R +rwx "${DIR}"
  "${DIR}"/jetbrains-toolbox --install
  rm -fr "${DIR}"

  rm "${DEST}"
  echo -e "\e[32mDone.\e[39m"
}

function install_brew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function install_nordvpn() {
  sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
  sudo usermod -aG nordvpn "$USER"
}

function install_docker() {
  sudo usermod -aG docker "${USER}"
}

function check_bing_wallpaper() {
  cron_entry="* */6 * * * ~/.dotfiles/linux/bin/bing-wallpaper >/dev/null 2>&1"
  if crontab -lu "$USER" | grep -F "$cron_entry"; then
    exit $SUCCESS
  else
    exit $FAILURE
  fi
}

function install_bing_wallpaper() {
  # @todo ask user to run crontab -e and save+exit
  cron_entry="* */6 * * * ~/.dotfiles/linux/bin/bing-wallpaper >/dev/null 2>&1"
  if ! crontab -lu "$USER" | grep -F "$cron_entry"; then
    echo "Creating CRON entry: $cron_entry"
    {
      crontab -lu "$USER"
      echo "$cron_entry"
    } | crontab -u "$USER" -
  fi
}

function install_touchpad_indicator() {
  sudo add-apt-repository ppa:atareao/atareao
  sudo apt update
  sudo apt install touchpad-indicator
}

function install_fake_webcam() {
  sudo apt install v4l-utils v4l2loopback-*
  v4l2-ctl --list-devices
  echo "Please identify the highest X where /dev/videoX and select the next lowest number X+1."
  read -rp "Enter number to use for fake cam device: " video_nr
  pushd "${HOME}/.dotfiles/linux/Linux-Fake-Background-Webcam"
  ./v4l2loopback-install.sh "$video_nr"
  poetry install
  popd
}

function install_ms_edge() {
  curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >microsoft.gpg
  sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
  rm microsoft.gpg
  sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge-dev.list'
  sudo apt update && sudo apt install microsoft-edge-stable
}

# Script will run in its own path no matter where it's called from.
pushd "$(dirname "$0")"

if [ "$1" == "test" ]; then
  echo "---=== TEST CLAUSE OR PLACEHOLDER ===---"
  echo "  Will not actually install anything."
  prompt_exit

elif [ "$1" == "install-logiops" ]; then
  install_logiops
  prompt_exit

elif [ "$1" == "install-powershell" ]; then
  install_powershell
  prompt_exit

elif [ "$1" == "install-nerdfonts" ]; then
  install_nerdfonts
  prompt_exit

elif [ "$1" == "install-rust" ]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  prompt_exit

elif [ "$1" == "install-nvm" ]; then
  install_nvm
  prompt_exit

elif [ "$1" == "check-nvm" ]; then
  if [[ $(command -v nvm) ]]; then
    echo "nvm present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-platformio" ]; then
  install_platformio
  prompt_exit

elif [ "$1" == "install-insync" ]; then
  install_insync
  prompt_exit

elif [ "$1" == "check-insync" ]; then
  if [[ $(command -v insync) ]]; then
    echo "insync present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-fake-webcam" ]; then
  OPT_FILE="/etc/modprobe.d/linux-fake-background.conf"
  if [[ -f ${OPT_FILE} ]]; then
    echo "fake webcam present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-keepass-plugins" ]; then
  install_keepass_plugins
  prompt_exit

elif [ "$1" == "install-jetbrains" ]; then
  install_jetbrains
  prompt_exit

elif [ "$1" == "install-brew" ]; then
  install_brew
  prompt_exit

elif [ "$1" == "install-nordvpn" ]; then
  install_nordvpn
  prompt_exit

elif [ "$1" == "install-docker" ]; then
  install_docker
  echo "CAUTION: You should log in anew for docker to work without sudo"
  prompt_exit

elif [ "$1" == "check-bing-wallpaper" ]; then
  check_bing_wallpaper

elif [ "$1" == "install-bing-wallpaper" ]; then
  install_bing_wallpaper
  prompt_exit

elif [ "$1" == "install-touchpad-indicator" ]; then
  install_touchpad_indicator
  prompt_exit

elif [ "$1" == "install-fake-webcam" ]; then
  install_fake_webcam
  prompt_exit

elif [ "$1" == "install-ms-edge" ]; then
  install_ms_edge
  prompt_exit

else
  echo "ERROR: Bad command or insufficient parameters!"
  echo " "
  exit $FAILURE
fi

popd
