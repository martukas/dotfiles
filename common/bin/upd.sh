#!/bin/bash

# Fail if any command fails
set -e
set -o pipefail

# Print each command as it executes
if [ -n "$VERBOSE" ]; then
	set -o xtrace
fi

FAILURE=1
SUCCESS=0

print_help() {
	cat <<EOF
Update system

The following options are available:
  a           Automatically update with apt and snap, autoremove and clean cache after
  f           Force install of held back packages
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

########
# AUTO #
########
elif [ "$1" == "a" ]; then
	sudo apt update
	sudo apt upgrade
	sudo snap refresh
	sudo apt autoremove
	sudo apt autoclean
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
