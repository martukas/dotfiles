#!/bin/bash

# shellcheck disable=SC2034
FAILURE=1
# shellcheck disable=SC2034
SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

# Silent pushd
pushd() {
	command pushd "$@" >/dev/null
}

# Silent popd
popd() {
	command popd >/dev/null
}

# Check if Linux
case "${OSTYPE}" in
linux*)
	pushd ~/.dotfiles || {
		echo "No dotfiles dir symlinked"
		exit $FAILURE
	}
	dconf dump /apps/guake/ >linux/dconf-guake-dump.txt
	# shellcheck disable=SC2164
	popd
	;;
*) ;;
esac
