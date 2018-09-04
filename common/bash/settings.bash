# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
#HISTCONTROL=ignoreboth
# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
#HISTFILESIZE=2000


HISTSIZE=1048576
HISTFILE="$HOME/.bash_history"
SAVEHIST=$HISTSIZE
shopt -s histappend # append to history file

export EDITOR=mousepad
