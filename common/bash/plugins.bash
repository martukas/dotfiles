# dircolors
if [[ "$(tput colors)" == "256" ]]; then
	eval "$(dircolors ~/.bash/plugins/dircolors-solarized/dircolors.256dark)"
fi
