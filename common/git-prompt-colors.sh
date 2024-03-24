# shellcheck disable=all

override_git_prompt_colors() {
  GIT_PROMPT_THEME_NAME="Custom"
  #  PathShort="\W"
  GIT_PROMPT_START_USER="${BrightBlack}$(date +%H:%M:%S)${ResetColor} ${Yellow}${PathShort}${ResetColor}"
  GIT_PROMPT_END="\n_LAST_COMMAND_INDICATOR_${BrightBlack}${CBC_PROMPT}${ResetColor} "
  GIT_PROMPT_STAGED="${Red}● "      # the number of staged files/directories
  GIT_PROMPT_CLEAN="${BoldGreen}✔ " # a colored flag indicating a "clean" repo
  GIT_PROMPT_COMMAND_OK=""
  GIT_PROMPT_COMMAND_FAIL="${Red}✘-_LAST_COMMAND_STATE_ "
}

reload_git_prompt_colors "Custom"
