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

git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive
git submodule update --init --recursive "${DOTBOT_DIR}"
git submodule update --init --recursive superpack
git submodule update --init --recursive private
git submodule update --init --recursive common/bash/plugins/dircolors-solarized
git submodule update --init --recursive common/bash-git-prompt

git submodule update

if [[ $OS == "GNU/Linux" ]]; then
	read -rp "[Linux] Do you want to run one-time installation scripts? " answer
	case ${answer:0:1} in
	y | Y)
		sudo apt --yes install aptitude snapd silversearcher-ag
		sudo apt -y purge parole

		# shellcheck disable=SC1091
		. /etc/lsb-release
		echo "DISTRIB_RELEASE = $DISTRIB_RELEASE"
		if [[ $DISTRIB_RELEASE == "23.04" ]]; then
			echo "[Ubuntu 23.04] installing global python packages via apt"
			sudo apt --yes install pipenv pre-commit thefuck
		else
			sudo python -m pip install --upgrade pip
			python -m pip install --upgrade pipenv thefuck pre-commit
		fi

		pushd superpack
		pipenv install
		pipenv run python ./superpack/superpack.py ../linux/packages.yml
		popd

		read -rp "[Linux] Do you want to install default desktop config? " answer
		case ${answer:0:1} in
		y | Y)
			echo "Left win key as toggle"
			echo -option altwin:meta_win >>~/.Xkbmap
			echo "Setting xfce dark theme"
			xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird-dark"
			echo "Copying various xfce settings"
			cp -ir ./linux/config/xfce4 ~/.config/xfce4
			echo "Enforcing guake settings"
			dconf load /apps/guake/ <linux/dconf-guake-dump.txt
			;;
		*) ;;
		esac

		read -n1 -srp $'Press any key to continue with dotbot config...\n' _
		;;
	*) ;;
	esac
else
	echo "No custom scripts to run for platform '$OS'."
fi

echo "Linking dotfiles for general bash use"
"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${CONFIG_COMMON}" "${@}"

if [[ $OS == "GNU/Linux" ]]; then
	echo "Linking Linux-specific dotfiles"
	"${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${CONFIG_LINUX}" "${@}"
fi
