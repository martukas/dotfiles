COLOR_DEFAULT='\[\e[39m\]'
COLOR_RED='\[\e[31m\]'
COLOR_GREEN='\[\e[32m\]'
COLOR_YELLOW='\[\e[33m\]'
COLOR_BLUE='\[\e[34m\]'
COLOR_MAGENTA='\[\e[35m\]'
COLOR_CYAN='\[\e[36m\]'

machine_name() {
  if [[ -f $HOME/.name ]]; then
    cat "$HOME"/.name
  else
    hostname
  fi
}

PROMPT_DIRTRIM=3

# shellcheck disable=SC2143
if [[ $(grep -i WSL /proc/version) ]]; then
  echo "Bash is running on WSL"
  PS1="\n${COLOR_RED}#${COLOR_DEFAULT} ${COLOR_MAGENTA}\\u${COLOR_DEFAULT} ${COLOR_YELLOW}at${COLOR_DEFAULT} ${COLOR_CYAN}$(machine_name)${COLOR_DEFAULT} ${COLOR_YELLOW}in${COLOR_DEFAULT} ${COLOR_GREEN}\w${COLOR_DEFAULT}\n\$(if [ \$? -ne 0 ]; then echo \"${COLOR_BLUE}!${COLOR_DEFAULT} \"; fi)${COLOR_RED}>${COLOR_DEFAULT} "
  PS2="${COLOR_RED}>${COLOR_DEFAULT} "
else
  PS1="\n${COLOR_BLUE}#${COLOR_DEFAULT} ${COLOR_CYAN}\\u${COLOR_DEFAULT} ${COLOR_GREEN}at${COLOR_DEFAULT} ${COLOR_MAGENTA}$(machine_name)${COLOR_DEFAULT} ${COLOR_GREEN}in${COLOR_DEFAULT} ${COLOR_YELLOW}\w${COLOR_DEFAULT}\n\$(if [ \$? -ne 0 ]; then echo \"${COLOR_RED}!${COLOR_DEFAULT} \"; fi)${COLOR_BLUE}>${COLOR_DEFAULT} "
  PS2="${COLOR_BLUE}>${COLOR_DEFAULT} "
fi
