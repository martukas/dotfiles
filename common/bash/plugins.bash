# dircolors
if [[ "$(tput colors)" == "256" ]]; then
  eval "$(dircolors ~/.bash/dircolors.256dark)"
fi
