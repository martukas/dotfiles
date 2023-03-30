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
alias issue='git-issue-push'
alias missue='git-issue-create'
alias commit-push='git-commit-push'
alias git-rm-submodule='git-remove-submodule'

# python BS in windows
if [[ "$OSTYPE" == "msys" ]]; then
	alias python='winpty python.exe'
fi

# Dotfiles update
dfu() {
  if [[ "$OSTYPE" == "msys" ]]; then
    pushd ~/.dotfiles && git pull && ./install.ps1 && popd
  else
    pushd ~/.dotfiles && git pull && ./install.sh && popd
  fi
}

# Dotfiles upgrade submodules
df-upgrade() {
  pushd ~/.dotfiles
  git submodule update --remote private
  git submodule update --remote dotbot
  git submodule update --remote superpack
  git submodule update --remote common/bash-git-prompt
  git submodule update --remote linux-only/logiops
  git submodule update --remote linux-only/gdb/qt5printers
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

# cd to git root directory
alias cdgr='cd "$(git root)"'

# Create a directory and cd into it
mcd() {
    mkdir "${1}" && cd "${1}"
}

# Jump to directory containing file
jump() {
    cd "$(dirname ${1})"
}

# cd replacement for screen to track cwd (like tmux)
scr_cd()
{
    builtin cd $1
    screen -X chdir "$PWD"
}

if [[ -n $STY ]]; then
    alias cd=scr_cd
fi

# Go up [n] directories
up()
{
    local cdir="$(pwd)"
    if [[ "${1}" == "" ]]; then
        cdir="$(dirname "${cdir}")"
    elif ! [[ "${1}" =~ ^[0-9]+$ ]]; then
        echo "Error: argument must be a number"
    elif ! [[ "${1}" -gt "0" ]]; then
        echo "Error: argument must be positive"
    else
        for ((i=0; i<${1}; i++)); do
            local ncdir="$(dirname "${cdir}")"
            if [[ "${cdir}" == "${ncdir}" ]]; then
                break
            else
                cdir="${ncdir}"
            fi
        done
    fi
    cd "${cdir}"
}

