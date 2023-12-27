# shellcheck disable=SC2034
COLOR_DEFAULT='\[\e[39m\]'
COLOR_BLACK='\[\e[30m\]'
COLOR_RED='\[\e[31m\]'
COLOR_GREEN='\[\e[32m\]'
COLOR_YELLOW='\[\e[33m\]'
COLOR_BLUE='\[\e[34m\]'
COLOR_MAGENTA='\[\e[35m\]'
COLOR_CYAN='\[\e[36m\]'
COLOR_LGRAY='\[\e[37m\]'
COLOR_DGRAY='\[\e[90m\]'
COLOR_LRED='\[\e[91m\]'
COLOR_LGREEN='\[\e[92m\]'
COLOR_LYELLOW='\[\e[93m\]'
COLOR_LBLUE='\[\e[94m\]'
COLOR_LMAGENTA='\[\e[95m\]'
COLOR_LCYAN='\[\e[96m\]'
COLOR_WHITE='\[\e[97m\]'

machine_name() {
  if [[ -f $HOME/.name ]]; then
    cat "$HOME"/.name
  else
    hostname
  fi
}

PROMPT_DIRTRIM=5
CBC_TIME=$COLOR_BLUE
CBC_STATIC=$COLOR_BLUE
CBC_USER=$COLOR_CYAN
CBC_PREP=$COLOR_DGRAY
CBC_PC=$COLOR_MAGENTA
CBC_DIR=$COLOR_YELLOW
CBC_ROOT=$COLOR_RED

# shellcheck disable=SC2143
if [[ $(grep -i Microsoft /proc/version) ]]; then
  GIT_PROMPT_THEME=Solarized_UserHost
  CBC_PREFIX="WSL"
else
  GIT_PROMPT_THEME=Minimal_UserHost
  CBC_PREFIX=""
fi

PS1="\n${CBC_TIME}\t${COLOR_DEFAULT} ${CBC_USER}\\u${COLOR_DEFAULT}${CBC_PREP}@${COLOR_DEFAULT}${CBC_PC}$(machine_name)${COLOR_DEFAULT} ${CBC_DIR}\w${COLOR_DEFAULT}\n\$(if [ \$? -ne 0 ]; then echo \"${CBC_ROOT}!${COLOR_DEFAULT} \"; fi)${CBC_STATIC}${CBC_PREFIX}>${COLOR_DEFAULT} "
PS2="${CBC_STATIC}${CBC_PREFIX}>${COLOR_DEFAULT} "

export PS4="$0.$LINENO+ "

export GIT_PROMPT_THEME
