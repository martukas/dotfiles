# Enable Rust tools
if [ -f ${HOME}/.cargo/bin/rustup ]; then
    . "${HOME}/.cargo/env"
fi

# Enable Node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


osinfo() {
  uname -a
  cat /etc/*-release
}

sysinfo() {
  sudo lshw -html > "${HOME}/Documents/system-info.html"
  python -m webbrowser "${HOME}/Documents/system-info.html"
}

reset-wifi() {
  sudo /etc/init.d/network-manager stop
  sudo rm /var/lib/NetworkManager/NetworkManager.state
  sudo /etc/init.d/network-manager start
}

mouse-tweak() {
  sudo systemctl enable --now logid
}

mouse_untweak() {
  sudo systemctl disable --now logid
}
