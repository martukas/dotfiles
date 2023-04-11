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

git submodule update

if [[ $OS == "GNU/Linux" ]]; then
	read -rp "[Linux] Do you want to run one-time installation scripts? " answer
	case ${answer:0:1} in
	y | Y)
		sudo apt --yes install aptitude snapd silversearcher-ag
		sudo apt -y purge parole
		sudo python -m pip install --upgrade pip
		python -m pip install --upgrade pipenv thefuck pre-commit

		pushd superpack
		pipenv install
		pipenv run python ./superpack/superpack.py ../linux/packages.yml
		popd
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
