# shellcheck disable=all

override_git_prompt_colors() {

  function prompt_callback {
    local PS1="$(gp_truncate_pwd)"
    gp_set_window_title "$PS1"
  }

  GIT_PROMPT_THEME_NAME="Custom"
  #  PathShort="\W"
  GIT_PROMPT_START_USER="${DimWhite}\D{%T}${ResetColor} ${Yellow}${PathShort}${ResetColor}"
  GIT_PROMPT_END="\n_LAST_COMMAND_INDICATOR_${DimWhite}${CBC_PROMPT}${ResetColor} "
  GIT_PROMPT_STAGED="${Red}● "      # the number of staged files/directories
  GIT_PROMPT_CLEAN="${BoldGreen}✔ " # a colored flag indicating a "clean" repo
  GIT_PROMPT_COMMAND_OK=""
  GIT_PROMPT_COMMAND_FAIL="${Red}✘-_LAST_COMMAND_STATE_ "
}

reload_git_prompt_colors "Custom"
