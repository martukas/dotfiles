#!/usr/bin/env bash

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

CONFIG_COMMON="conf_common.yaml"
CONFIG_LINUX="conf_linux.yaml"
DOTBOT_DIR="dotbot"

DOTBOT_BIN="bin/dotbot"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OS="$(uname -o)"

# This script should work no matter where you call it from.
cd "${BASEDIR}"

if [[ $OS == "GNU/Linux" ]]; then
  # shellcheck disable=SC1091
  . "${BASEDIR}/linux/_distro.sh"
  echo "Detected: ${DISTRO_ID} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
fi

pipx_ensure() {
  local pkg="$1"
  if pipx list --short 2>/dev/null | awk '{print $1}' | grep -qx "$pkg"; then
    pipx upgrade "$pkg"
  else
    pipx install "$pkg"
  fi
}

export PATH="${HOME}/.local/bin:${PATH}"

read -rp "Sync submodules? " answer
case ${answer:0:1} in
  y | Y)
    git submodule update --init --recursive
    ;;
  *) ;;
esac

if [[ $OS == "GNU/Linux" ]]; then
  read -rp "[Linux] Install base packages (apt + pipx)? " answer
  case ${answer:0:1} in
    y | Y)
      sudo apt --yes install aptitude snapd silversearcher-ag ubuntu-advantage-tools pipx
      # @todo run:   sudo pro attach
      sudo apt -y purge parole

      pipx_ensure poetry
      pipx_ensure pre-commit
      pipx_ensure ruff
      pipx_ensure compiledb
      pipx_ensure uv
      ;;
    *) ;;
  esac

  read -rp "[Linux] Run superpack? " answer
  case ${answer:0:1} in
    y | Y)
      pushd superpack
      uv sync
      uv run python ./superpack/superpack.py ../linux/packages.yml
      popd
      ;;
    *) ;;
  esac

  read -rp "[Linux] Apply desktop config (xfce + guake)? " answer
  case ${answer:0:1} in
    y | Y)
      echo "Left win key as toggle"
      grep -qxF -- '-option altwin:meta_win' ~/.Xkbmap 2>/dev/null || echo -option altwin:meta_win >>~/.Xkbmap
      echo "Setting xfce dark theme"
      xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird-dark"
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark
      echo "Applying xfce settings"
      "$BASEDIR/linux/xfconf.py" pull
      if gsettings list-schemas | grep -qE "^(org\.)?guake$"; then
        echo "Enforcing guake settings"
        dconf load /org/guake/ <linux/dconf-guake-dump.txt
      fi
      ;;
    *) ;;
  esac
fi

read -rp "Link dotfiles (dotbot)? " answer
case ${answer:0:1} in
  y | Y)
    echo "Linking dotfiles for general bash use"
    "${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${CONFIG_COMMON}" -v

    if [[ $OS == "GNU/Linux" ]]; then
      echo "Linking Linux-specific dotfiles"
      "${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${CONFIG_LINUX}" -v
    fi
    ;;
  *) ;;
esac
