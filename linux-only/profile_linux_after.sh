# Dotfiles update
dfu() {
  pushd ~/.dotfiles && git pull && ./install.sh && popd
}

if command -v guake &> /dev/null
then
  function ssh() {
    # TODO what if there are options inside the @? parse and remove them for guake
    guake -r "$@";
    /usr/bin/ssh "$@"
    guake -r "-"
  }
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
