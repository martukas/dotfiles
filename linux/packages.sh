#!/bin/bash
# shellcheck disable=SC2317

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/_distro.sh"

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
  sudo apt install -y logiops
  sudo ln -sf "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logid.cfg" /etc/logid.cfg
  sudo systemctl restart logid
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

  local version='3.4.0'
  local fonts_dir="${HOME}/.local/share/fonts"
  mkdir -p "$fonts_dir"

  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  for font in "${fonts[@]}"; do
    local zip_file="$tmp/${font}.zip"
    local extract_dir="$tmp/${font}"
    local download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${version}/${font}.zip"
    echo "Downloading $download_url"
    wget -O "$zip_file" "$download_url"
    unzip -oq "$zip_file" -d "$extract_dir"
    find "$extract_dir" -type f \( -iname '*.ttf' -o -iname '*.otf' \) ! -iname '*Windows Compatible*' \
      -exec cp -f {} "$fonts_dir/" \;
  done

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
  sudo apt install python3-venv
  curl -fsSL -o get-platformio.py https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py
  python3 ./get-platformio.py
  rm ./get-platformio.py
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
  local version='3.9.8.60034'
  local url="https://cdn.insynchq.com/builds/linux/${version}/insync_${version}-${DISTRO_CODENAME}_amd64.deb"

  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  wget -O "$tmp/insync.deb" "$url"
  sudo apt --yes install "$tmp/insync.deb"
}

function install_keepass_plugins() {
  local plugins_dir=/usr/lib/keepass2/Plugins
  local keetheme_url='https://github.com/xatupal/KeeTheme/releases/latest/download'
  local darkenkp_url='https://github.com/BradyThe/DarkenKP/releases/latest/download'

  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  echo "Downloading KeeTheme plugin"
  wget -O "$tmp/KeeTheme.dll" "$keetheme_url/KeeTheme.dll"
  wget -O "$tmp/KeeTheme.plgx" "$keetheme_url/KeeTheme.plgx"
  echo "Downloading DarkenKP theme"
  wget -O "$tmp/KeeTheme.ini" "$darkenkp_url/KeeTheme.ini"

  sudo install -d -m 755 "$plugins_dir/DarkenKP"
  sudo install -m 644 "$tmp/KeeTheme.dll" "$plugins_dir/"
  sudo install -m 644 "$tmp/KeeTheme.plgx" "$plugins_dir/"
  sudo install -m 644 "$tmp/KeeTheme.ini" "$plugins_dir/DarkenKP/"
}

function install_jetbrains() {
  #Adapted from https://github.com/nagygergo/jetbrains-toolbox-install

  echo -e " \e[94mInstalling Jetbrains Toolbox\e[39m"

  sudo apt --yes install libfuse2

  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  local url
  url=$(curl -sSfILw "%{url_effective}" -o /dev/null \
    "https://data.services.jetbrains.com/products/download?code=TBA&platform=linux")
  echo "JetBrains Toolbox URL: $url"

  local tarball="$tmp/$(basename "$url")"
  echo -e "\e[94mDownloading\e[39m"
  wget -O "$tarball" "$url"

  echo -e "\e[94mVerifying SHA-256\e[39m"
  local expected actual
  expected=$(curl -sSfL "${url}.sha256" | awk '{print $1}')
  actual=$(sha256sum "$tarball" | awk '{print $1}')
  [ "$expected" = "$actual" ] || {
    echo "Checksum mismatch: expected $expected, got $actual"
    return 1
  }

  local dir="$tmp/toolbox"
  echo -e "\e[94mExtracting to $dir\e[39m"
  mkdir -p "$dir"
  tar -xzf "$tarball" -C "$dir" --strip-components=1

  chmod -R +rwx "$dir"
  "$dir"/bin/jetbrains-toolbox --install
}

function install_brew() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function install_nordvpn() {
  sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
  sudo usermod -aG nordvpn "$USER"
  nordvpn set autoconnect off
}

function install_docker() {
  sudo apt-get install -y ca-certificates curl
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  if [ "$(getent group docker)" ]; then
    echo "docker group already exists, skipping GID assignment"
  else
    sudo groupadd -g 1001 docker
  fi
  sudo usermod -aG docker "${USER}"
  sudo apt-get install -y docker-ce
}

function check_bing_wallpaper() {
  if systemctl --user is-enabled bing-wallpaper.timer >/dev/null 2>&1; then
    echo "bing-wallpaper.timer enabled"
    exit $SUCCESS
  else
    exit $FAILURE
  fi
}

function install_bing_wallpaper() {
  local repo_root
  repo_root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
  local user_units="$HOME/.config/systemd/user"
  mkdir -p "$user_units"

  cat >"$user_units/bing-wallpaper.service" <<EOF
[Unit]
Description=Microsoft Bing wallpaper updater
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=oneshot
ExecStart=$repo_root/linux/bin/bing-wallpaper
EOF

  cat >"$user_units/bing-wallpaper.timer" <<'EOF'
[Unit]
Description=Run Bing wallpaper updater four times a day

[Timer]
OnCalendar=00,06,12,18:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now bing-wallpaper.timer
  systemctl --user start bing-wallpaper.service
}

function install_touchpad_indicator() {
  sudo add-apt-repository ppa:atareao/atareao
  sudo apt update
  sudo apt install touchpad-indicator
}

function install_zoom() {
  flatpak install -y flathub us.zoom.Zoom
  flatpak override --user us.zoom.Zoom --filesystem="$HOME/Pictures:ro"
}

function install_zapzap() {
  flatpak install -y flathub com.rtosta.zapzap
  flatpak override --user --filesystem=home com.rtosta.zapzap
  flatpak override --user --env=QTWEBENGINE_CHROMIUM_FLAGS="--disable-gpu" com.rtosta.zapzap
}

function install_chrome() {
  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  wget -O "$tmp/chrome.deb" 'https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb'
  sudo apt --yes install "$tmp/chrome.deb"
}

function install_slack() {
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packagecloud.io/slacktechnologies/slack/gpgkey \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/slack.gpg >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/slack.gpg] https://packagecloud.io/slacktechnologies/slack/debian/ jessie main" \
    | sudo tee /etc/apt/sources.list.d/slack.list >/dev/null
  sudo apt update && sudo apt --yes install slack-desktop
}

function install_signal() {
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/signal-desktop-keyring.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" \
    | sudo tee /etc/apt/sources.list.d/signal-xenial.list >/dev/null
  sudo apt update && sudo apt --yes install signal-desktop
}

function install_discord() {
  local tmp
  tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" RETURN

  wget -O "$tmp/discord.deb" 'https://discord.com/api/download?platform=linux&format=deb'
  sudo apt --yes install "$tmp/discord.deb"
}

function install_strawberry() {
  flatpak install -y flathub org.strawberrymusicplayer.strawberry
}

function install_prism_launcher() {
  flatpak install -y flathub org.prismlauncher.PrismLauncher
  local insync_account
  insync_account=$(find "$HOME/Insync" -maxdepth 1 -type d -name "*@*" 2>/dev/null | head -1)
  local mc_config="$insync_account/Google Drive/fun/MC/shared_config"
  if [ -d "$mc_config" ]; then
    flatpak override --user --filesystem="$mc_config:rw" org.prismlauncher.PrismLauncher
  fi
}

function install_ms_edge() {
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/microsoft-edge.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main" \
    | sudo tee /etc/apt/sources.list.d/microsoft-edge.list >/dev/null
  sudo apt update && sudo apt --yes install microsoft-edge-stable
}

function install_claude_code() {
  export NVM_DIR="$HOME/.nvm"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    echo "nvm not installed; install nvm first via superpack"
    exit $FAILURE
  fi
  # shellcheck disable=SC1091
  \. "$NVM_DIR/nvm.sh"
  if ! command -v npm >/dev/null 2>&1; then
    nvm install --lts
    nvm use --lts
  fi
  npm install -g @anthropic-ai/claude-code
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
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
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

elif [ "$1" == "check-zoom" ]; then
  if flatpak info us.zoom.Zoom >/dev/null 2>&1; then
    echo "zoom present"
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

elif [ "$1" == "install-zoom" ]; then
  install_zoom
  prompt_exit

elif [ "$1" == "check-zapzap" ]; then
  if flatpak info com.rtosta.zapzap >/dev/null 2>&1; then
    echo "zapzap present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-zapzap" ]; then
  install_zapzap
  prompt_exit

elif [ "$1" == "install-chrome" ]; then
  install_chrome
  prompt_exit

elif [ "$1" == "install-slack" ]; then
  install_slack
  prompt_exit

elif [ "$1" == "install-signal" ]; then
  install_signal
  prompt_exit

elif [ "$1" == "install-discord" ]; then
  install_discord
  prompt_exit

elif [ "$1" == "check-strawberry" ]; then
  if flatpak info org.strawberrymusicplayer.strawberry >/dev/null 2>&1; then
    echo "strawberry present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-strawberry" ]; then
  install_strawberry
  prompt_exit

elif [ "$1" == "check-prism-launcher" ]; then
  if flatpak info org.prismlauncher.PrismLauncher >/dev/null 2>&1; then
    echo "prism-launcher present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-prism-launcher" ]; then
  install_prism_launcher
  prompt_exit

elif [ "$1" == "install-ms-edge" ]; then
  install_ms_edge
  prompt_exit

elif [ "$1" == "check-claude-code" ]; then
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  if command -v claude >/dev/null 2>&1; then
    echo "claude present"
    exit $SUCCESS
  else
    exit $FAILURE
  fi

elif [ "$1" == "install-claude-code" ]; then
  install_claude_code
  prompt_exit

else
  echo "ERROR: Bad command or insufficient parameters!"
  echo " "
  exit $FAILURE
fi

popd
