# Dotfiles update
dfu() {
  pushd ~/.dotfiles && git pull && ./install.sh && popd
}

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

mouse-untweak() {
  sudo systemctl disable --now logid
}

create-user() {
  echo "---------========= ACHTUNG =========---------"
  echo "This will create a user on this system."
  echo "With a home directory 'n shit..."
  echo " "
  echo " You better have their public ssh key ready!"
  echo " "
  read -rp "Yes-go or no-go? " answer
  case ${answer:0:1} in
    y | Y)
      read -p "Enter username: " user
      sudo useradd -m -d "/home/${user}" -s /bin/bash "${user}"
      sudo passwd "${user}"
      sudo passwd -e "${user}"
      sudo mkdir "/home/${user}/.ssh"
      sudo touch "/home/${user}/.ssh/authorized_keys"
      sudo chown -R "${user}:${user}" "/home/${user}/.ssh"
      sudo chmod 700 "/home/${user}/.ssh"
      sudo chmod 600 "/home/${user}/.ssh/authorized_keys"
      sudo usermod -aG sudo "${user}"
      sudo nano "/home/${user}/.ssh/authorized_keys"
      ;;
    *)
      ;;
  esac
}

df-save() {
  pushd ~/.dotfiles
  dconf dump /apps/guake/ > linux-only/dconf-guake-dump.txt
  popd
}
