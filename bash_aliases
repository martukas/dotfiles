# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias l='ls -AF --group-directories-first'
alias ll='ls -lF --group-directories-first'
alias la='ls -AlF --group-directories-first'

alias mx='chmod -R 755'
alias mw='chmod -R 644'

#alias python=/usr/bin/python3
alias sudo='sudo '
alias own='sudo -R chown $(id -un):$(id -gn)'
alias dmake='cmake -DCMAKE_BUILD_TYPE=Debug'
alias rmake='cmake -DCMAKE_BUILD_TYPE=Release'
alias issue='$HOME/push_issue.sh'
alias missue='$HOME/create_issue.sh'
