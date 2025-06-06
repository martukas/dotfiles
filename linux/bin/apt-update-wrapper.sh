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

# Print each command as it executes
if [ -n "$VERBOSE" ]; then
  set -o xtrace
fi

print_help() {
  cat <<EOF
Update system

The following options are available:
  a           Automatically update with apt and snap, autoremove and clean cache after
  f           Force install of held back packages
  ff          Fast-forward, i.e. update the distribution
  help/-h     Display this help info
EOF
}

########
# HELP #
########

if [ "$1" == "help" ] || [ "$1" == "-h" ]; then
  print_help
  exit $SUCCESS

#########
# FORCE #
#########
elif [ "$1" == "f" ]; then
  sudo aptitude safe-upgrade
  exit $SUCCESS

elif [ "$1" == "ff" ]; then
  sudo sudo do-release-upgrade
  exit $SUCCESS

########
# AUTO #
########
elif [ "$1" == "a" ]; then
  sudo systemctl daemon-reload
  sudo apt update
  sudo apt upgrade
  sudo apt autoremove
  sudo apt autoclean

  sudo snap refresh
  # shellcheck disable=SC2162
  LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' \
    | while read snapname revision; do
      sudo snap remove "$snapname" --revision="$revision"
    done

  if [ -d /home/linuxbrew ]; then
    brew update
    brew upgrade
    brew cleanup
  fi
  exit $SUCCESS

################
# ERROR & HELP #
################
else
  echo "ERROR: Bad command or insufficient parameters!"
  echo
  print_help
  exit $FAILURE
fi
