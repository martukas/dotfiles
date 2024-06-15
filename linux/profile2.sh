#!/bin/bash

if [[ $(command -v thefuck) ]]; then
  eval "$(thefuck --alias)"
fi

if grep -qi Microsoft /proc/version; then
  echo "Starting bash in WSL"
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add -t 0 .ssh/id_ed25519
fi

osinfo() {
  uname -a
  cat /etc/*-release
}

sysinfo() {
  # shellcheck disable=SC2024
  sudo lshw -html >"${HOME}/Documents/system-info.html"
  python -m webbrowser "${HOME}/Documents/system-info.html"
}

reset-wifi() {
  sudo /etc/init.d/network-manager stop
  sudo rm /var/lib/NetworkManager/NetworkManager.state
  sudo /etc/init.d/network-manager start
}

reset-bt() {
  sudo service bluetooth restart
}

mouse-tweak() {
  sudo systemctl enable --now logid
}

mouse-untweak() {
  sudo systemctl disable --now logid
}

keychron-fn() {
  echo 0 | sudo tee /sys/module/hid_apple/parameters/fnmode
  #  TODO: follow this to make persistent https://www.reddit.com/r/Keychron/comments/gptnpt/k1_no_access_to_fkeys_in_linux_help/
}

create-user() {
  echo "---------========= ACHTUNG =========---------"
  echo "This will create a user on this system."
  echo "With a home directory 'n shit..."
  echo "... with SUDO powers!!!"
  echo " "
  echo " You better have their public ssh key ready!"
  echo " "
  read -rp "Yes-go or no-go? " answer
  case ${answer:0:1} in
    y | Y)
      read -rp "Enter username: " user
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
    *) ;;
  esac
}

function rm-ext() {
  ext=$1
  find . -name "*.${ext}" -type f
  read -rp "Will delete the above files. Continue? " answer
  case ${answer:0:1} in
    y | Y)
      find . -name "*.${ext}" -type f -delete
      ;;
    *)
      echo "Aborting"
      ;;
  esac
}
