#!/bin/bash

# Use colors in coreutils utilities output
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# ls aliases
alias l='ls -AF --group-directories-first'
alias ll='ls -lF --group-directories-first'
alias la='ls -AlF --group-directories-first'

# Aliases to protect against overwriting
alias cp='cp -i'
alias mv='mv -i'

alias mx='chmod -R 755'
alias mw='chmod -R 644'

alias sudo='sudo '
alias own='sudo -R chown $(id -un):$(id -gn)'

# cmake aliases
alias dmake='cmake -DCMAKE_BUILD_TYPE=Debug'
alias rmake='cmake -DCMAKE_BUILD_TYPE=Release'

# git related aliases
alias gag='git exec ag'

# git new branch
function gnb() {
  git checkout -b "$1"
  git push --set-upstream origin "$1"
}

#create new issue branch
function missue() {
  gnb issue_"$1"
}

function commit-push() {
  message="$*"
  git add -A
  git commit -m "${message}"
  git push
}

# commit-push, appending an "updates #issue" to one-line commit message
function issue() {
  BRANCH="$(git symbolic-ref --short HEAD)"
  # shellcheck disable=SC2001
  NUMBER=$(echo "$BRANCH" | sed 's@^[^0-9]*\([0-9]\+\).*@\1@')

  if [[ $BRANCH == *"issue"* ]] && [ -n "${NUMBER}" ]; then
    message="$*; updates #$NUMBER"
    commit-push "${message}"
  else
    echo "not an issue branch!"
    return 1
  fi
}

function git-rm-submodule() {
  # Remove the submodule entry from .git/config
  git submodule deinit -f "$1"
  # Remove the submodule directory from the super-project's .git/modules directory
  rm -rf .git/modules/"$1"
  # Remove the entry in .gitmodules and remove the submodule directory located at path/to/submodule
  git rm -f "$1"
}


# Dotfiles upgrade submodules
df-upgrade() {
  pushd ~/.dotfiles || { echo "Could not go to .dotfiles"; exit 1; }
  git submodule update --remote private
  git submodule update --remote dotbot
  git submodule update --remote superpack
  git submodule update --remote common/bash-git-prompt
  git submodule update --remote linux-only/logiops
  git submodule update --remote linux-only/gdb/qt5printers
  # shellcheck disable=SC2164
  popd
}

# Use pip without requiring virtualenv
syspip() {
    PIP_REQUIRE_VIRTUALENV="" pip "$@"
}

syspip2() {
    PIP_REQUIRE_VIRTUALENV="" pip2 "$@"
}

syspip3() {
    PIP_REQUIRE_VIRTUALENV="" pip3 "$@"
}

upd() {
  upd.sh "$@"
}

# cd to git root directory
cdgr() {
  cd "$(git root)"  || { echo "Could not jump to git root"; exit 1; }
}

# Create a directory and cd into it
mcd() {
    mkdir "${1}"
    cd "${1}" || { echo "Could not enter directory: ${1}"; exit 1; }
}

# Jump to directory containing file
jump() {
    cd "$(dirname "${1}")" || { echo "Cannot jump to dir containing ${1}"; exit 1; }
}

# Go up [n] directories
up()
{
    local cdir
    cdir="$(pwd)"
    if [[ "${1}" == "" ]]; then
        cdir="$(dirname "${cdir}")"
    elif ! [[ "${1}" =~ ^[0-9]+$ ]]; then
        echo "Error: argument must be a number"
    elif ! [[ "${1}" -gt "0" ]]; then
        echo "Error: argument must be positive"
    else
        for ((i=0; i<${1}; i++)); do
            local ncdir
            ncdir="$(dirname "${cdir}")"
            if [[ "${cdir}" == "${ncdir}" ]]; then
                break
            else
                cdir="${ncdir}"
            fi
        done
    fi
    cd "${cdir}" || { echo "Could not go up ${1} dirs"; exit 1; }
}
