#!/bin/bash
# shellcheck disable=SC1090

# autostart ssh agent as explained here:
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases

env=~/.ssh/agent.env

agent_load_env() { test -f "$env" && . "$env" >|/dev/null; }

agent_start() {
	(
		umask 077
		ssh-agent >|"$env"
	)
	. "$env" >|/dev/null
}

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2= agent not running
agent_run_state=$(
	ssh-add -l >|/dev/null 2>&1
	echo $?
)

if [ ! "$SSH_AUTH_SOCK" ] || [ "$agent_run_state" = 2 ]; then
	agent_start
	ssh-add
elif [ "$SSH_AUTH_SOCK" ] && [ "$agent_run_state" = 1 ]; then
	ssh-add
fi

unset env

# \todo reenable this when package resolves python3.12 problem
#eval "$(thefuck --alias)"
