# Enable Rust tools
if [ -f ${HOME}/.cargo/bin/rustup ]; then
    . "${HOME}/.cargo/env"
fi

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
