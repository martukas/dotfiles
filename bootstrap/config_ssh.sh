#!/bin/bash

EXIT_FAILURE=1
EXIT_SUCCESS=0

# Fail if any command fails
set -e
set -o pipefail

START_BROWSER_CMD="$@"

KEY_TYPE="ed25519"
KEY_FILE="${HOME}/.ssh/id_${KEY_TYPE}"
PUB_KEY_FILE="${KEY_FILE}.pub"

copy_to_clipboard() {
  case "${OSTYPE}" in
    linux*)
      xclip ${PUB_KEY_FILE}
      xclip -o | xclip -sel clip
      echo "Key has been copied to clipboard"
      ;;
    msys*)
      clip <${PUB_KEY_FILE}
      echo "Key has been copied to clipboard"
      ;;
    darwin*)
      pbcopy <${PUB_KEY_FILE}
      echo "Key has been copied to clipboard"
      ;;
    *)
      echo "unknown OS: $OSTYPE"
      echo "Ok then. I will just print it out here for you to copy manually:"
      cat ${PUB_KEY_FILE}
      ;;
  esac
  read -n 1 -srp "Please add it to your keys in GitHub and press any key to continue"$'\n'
}

read -rp "Do you want to set up a local ssh key? " answer
case ${answer:0:1} in
  y | Y)
    read -rp "*** Press any key to to begin ssh key generation process ***"$'\n'
    ssh-keygen -t ${KEY_TYPE} -f ${KEY_FILE}
    eval "$(ssh-agent -s)"
    ssh-add ${KEY_FILE}
    echo "Key has been generated and registered with ssh-agent."
    echo

    read -rp "Do you want to open GitHub on this PC's web browser? " answer
    case ${answer:0:1} in
      y | Y)
		${START_BROWSER_CMD} "https://github.com/login"
        echo "Make sure you are logged into GitHub on this PC"
        read -n 1 -srp "*** Press any key to open the SSH key management page ***"$'\n'
        ${START_BROWSER_CMD} "https://github.com/settings/ssh/new"
        ;;
      *)
        echo "Ok then. Open a browser on your local system and go to https://github.com/settings/keys "
        ;;
    esac

    read -rp "Do you want the ssh public key copied to your clipboard right now? " answer
    case ${answer:0:1} in
      y | Y)
        copy_to_clipboard
        ;;
      *)
        echo "Ok then. I will just print it out here for you to copy manually:"
        cat ${PUB_KEY_FILE}
        read -n 1 -srp "Press any key to continue"$'\n'
        ;;
    esac
    ;;
  *)
    echo "Ok then. Let's assume you have already done it or you have ssh-agent forwarding working here."
    ;;
esac

echo "Assuming you have configured the public key correctly. We should be able to test the connection now."
read -n 1 -srp "Press any key to test ssh connection to GitHub."$'\n'
ssh -T git@github.com || true

echo "Assuming that went well...?"
read -n 1 -srp "Press any key to clone the dotfiles repository and continue setup."$'\n'

### Clone repository and go in
mkdir -p "${HOME}/dev"
cd "${HOME}/dev"
git config --global pull.ff only
git clone git@github.com:martukas/dotfiles.git
cd dotfiles

echo "SSH and GitHub config completed successfully. You will now return to your OS-specific installation scripts."
read -n 1 -srp "Press any key to continue"$'\n'

