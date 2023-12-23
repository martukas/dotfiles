# shellcheck disable=SC1090
# shellcheck disable=SC1091

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# OS-specific before - for interactive only
case "$OSTYPE" in
  darwin*) echo "Running OSX: no custom dotfile scripts for this OS" ;;
  linux*) source ~/.dotfiles/linux/profile1.sh ;;
  msys*) source ~/.dotfiles/windows/profile1.sh ;;
  cygwin*) source ~/.dotfiles/windows/profile1.sh ;;
  *) echo "Unknown OS: $OSTYPE" ;;
esac

# Allow local customizations in the ~/.bashrc_local_before file
if [ -f ~/.bashrc_local_before ]; then
  source ~/.bashrc_local_before
fi

# Settings
source ~/.bash/settings.bash

# Aliases
source ~/.bash/aliases.sh

if [ -f ~/.dotfiles/private/common/private_profile.sh ]; then
  source ~/.dotfiles/private/common/private_profile.sh
fi

# Custom prompt
source ~/.bash/prompt.bash

# Plugins
source ~/.bash/plugins.bash

# If not running interactively, don't do anything
case $- in
  *i*) ;;
  *) return ;;
esac

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

GPG_TTY="$(tty)"
export GPG_TTY

GIT_PROMPT_ONLY_IN_REPO=1
export GIT_PROMPT_ONLY_IN_REPO
source ~/.bash-git-prompt/gitprompt.sh

# Allow local customizations in the ~/.bashrc_local_after file
if [ -f ~/.bashrc_local_after ]; then
  source ~/.bashrc_local_after
fi

# OS-specific after - for interactive only
case "$OSTYPE" in
  darwin*) echo "Running OSX: no custom dotfile scripts for this OS" ;;
  linux*) source ~/.dotfiles/linux/profile2.sh ;;
  msys*) source ~/.dotfiles/windows/profile2.sh ;;
  cygwin*) source ~/.dotfiles/windows/profile2.sh ;;
  *) echo "Unknown OS: $OSTYPE" ;;
esac
