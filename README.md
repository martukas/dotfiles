# One ring to rule them all

[![bash](https://img.shields.io/badge/GNU-Bash-4eaa25?logo=gnubash)](https://www.gnu.org/software/bash/)
[![PowerShell](https://img.shields.io/badge/PowerShell-7-26405f?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Windows10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows)](https://www.microsoft.com/en-us/software-download/windows10%20)
[![Info](https://img.shields.io/badge/Xubuntu-20.10-0044aa?style=flat-square&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI2NCIgaGVpZ2h0PSI2NCI+PGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTUwMS4zMTIgLTQ5NC4wMzIpIj48Y2lyY2xlIGN4PSI1MzMuMzEyIiBjeT0iNTI2LjAzMiIgcj0iMzIiIHN0eWxlPSJmaWxsOiMwNGE7ZmlsbC1vcGFjaXR5OjE7c3Ryb2tlOm5vbmUiLz48cGF0aCBkPSJNNTI0LjAxMyA1MTEuNzU0Yy0uNDYyIDIuMjk2LjIwMiA0LjkyMyAxLjEzMSA4LjEuMDU3LjE5Mi0uMDUyLjQzNy0uMTUuNDY2LS40MjIuMTIzLTEuMTQ1LS4wMDgtMS4yODUtLjI5Ni0uNzI0LTEuNDg2LTEuMDY5LTMuMDA2LTEuOTE0LTQuNDctLjU4NS0xLjAxMi0xLjE5LTEuOTc4LTEuOTExLTIuNjMxLS44NzYtLjc5My0xLjU2Mi0uOTUtMi40OTktLjU1OC0xLjE4Mi40OTQtMS44OTYgMS42NzgtMi4xNCAyLjc0LS4yNDkgMS4wNzYtLjE0NSAyLjMyLjA1IDMuNC4yMjggMS4yNy41MiAyLjI3Mi44OTQgMy40Ni0uMjg2Ljg0NC0yLjAwNCA1LjQ3Ny0yLjQyIDguNjktLjUzMyA0LjEyMi0yLjAzMyAxNi41OTggMTEuNzE0IDE1LjIxIDUuMDctLjUxIDkuMjAyLTIuMjg4IDEzLjExMS00LjExIDEuNzkyLS44MzYgNC4wNC0xLjkxNCA2LjItMy4xIDIuMTYyLTEuMTg4IDQuMTY4LTIuNDU0IDUuNy0zLjggMS41MzYtMS4zNSAyLjY1NC0yLjgyOCAyLjQ1LTQuMy0uMzI4LTIuMzc0LTEuOTAyLTQuMTM4LTQtNS41LTIuMTA1LTEuMzY4LTUuNzAxLTIuNjQtOC4zLTMuMzk5LTMuNDEtLjk5Ni02LjA1LTEuMzgzLTkuMjUtMS41NTctLjE3OS0zLjI0Mi4yNTMtNy41MS0xLjgtOS45OTUtLjQ3NS0uNTc1LTEuMTY4LS45NDEtMi0xLTEuMzM2LjA1NC0zLjE1MS41Mi0zLjU4IDIuNjV6IiBzdHlsZT0ib3BhY2l0eToxO2ZpbGw6I2ZmZjtmaWxsLW9wYWNpdHk6MTtzdHJva2U6bm9uZSIvPjxwYXRoIGQ9Ik01NDAuMTU4IDUxNy41NTFjLS4wMzQuNzk5LjEzMyAyLjUyMSAxLjE4IDIuNjU0IDEuMjQ3LjE0NyAxLjY0Ny0uODggMS43ODMtMS42ODMuNDMzLTIuNTU1LjU1My0zLjMxOS43Ny01LjYzNC4yNTQtMi43MjguOTI1LTcuMzMxLS4yNDctNi45MDItMS4xODcuNDM1LTIuMTMgNC4xMTEtMi40MzggNS42NTItLjI0IDEuMi0uOTg5IDQuNTQyLTEuMDQ4IDUuOTEzek01NDUuNjIzIDUxOC4xM2MtLjY4MyAxLjU5Ni0xLjAwNyAyLjk3NC0uMDYyIDMuNDQyIDEuMTI1LjU1NyAyLjA5OC0uNTIzIDIuNDE1LTEuMjczLjk1NC0yLjI2MiAxLjQ4My0zLjYzMiAyLjIyLTUuMzQzIDEuMDgzLTIuNTE3IDMuNzg3LTcuMzUyIDIuMDAzLTcuMDk2LTEuMjUyLjE4LTIuOTM0IDMuMzU4LTMuNzQyIDQuNzA2LTEuMDQgMS43MzItMS44NSAzLjI2Ny0yLjgzNCA1LjU2NXoiIHN0eWxlPSJvcGFjaXR5OjE7ZmlsbDojZmZmO2ZpbGwtb3BhY2l0eToxO3N0cm9rZTpub25lIi8+PC9nPjwvc3ZnPg==)](https://xubuntu.org/)

These are my dotfiles and bootstrap scripts for Linux and Windows systems. The git/bash/ssh parts should work for Mac as well.

If on Windows, before doing anything else:
* Run `Set-ExecutionPolicy RemoteSigned` for PS1 scripts to work
* Prevent OneDrive from taking over your home directories as described [here](https://answers.microsoft.com/en-us/windows/forum/all/taking-back-control-of-your-folders-from-onedrive/7b7ad05e-8b05-4bcd-9772-9e4eee880346):
  * Open 'gpedit' from the Start menu
  * Follow `Administrative Templates`>`Windows Components`>`OneDrive`
  * Edit and enable `Prevent the usage of OneDrive for file storage`.
* Might need to run some of the scripts with Admin privileges, particularly for symlinks to work.

## Bootstrapping

Let's make as few assumptions as possible about what's available on the machine - no git, no Python, nothing...

In this case, download the files in the [bootstrap](bootstrap) directory.

Then run either `bootstrap.ps1` or `bootsrtap.sh` as per OS type.

This will also set up ssh credentials for me and clone this repo with privileges. Follow the steps, and after a potential reboot, run either `install.ps1` or `install.sh` as per shell type to set up initial symlinks. These will also run [SuperPack](https://github.com/martukas/superpack) to offer you installation of packages appropriate for your system.

## Routine use:

To update locally, there are convenience [aliases](common/shell/aliases.sh):
* `dfu` - dotfiles update, pulls and runs appropriate install script
* `df-upgrade` - upgrades all submodules to latest versions in remote repos

Updating repo:
* The usual add-commit-push ritual, or the `commit-push` alias
* symlinked files will stay up to date
* on Xubuntu, occasionally run `df-save` to extract and save settings for guake
* `dirty` state in `private` part will be ignored by git. Commit changes to that submodule separately, before you commit in parent dir

## Manual installation for now...

* [InSync](https://www.insynchq.com/downloads/linux)
* [Jetbrains remote](https://www.jetbrains.com/help/idea/remote-development-overview.html)
* [CLion + PlatformIO integration](https://docs.platformio.org/en/latest/integration/ide/clion.html)

## TODO

* include .profile?
* install [thefuck](https://github.com/nvbn/thefuck)
* install [conan](https://docs.conan.io/2/installation.html)
* clementine remote config & script
* wget bootstrap files now that repo is public
* Linux gui links optional
* Code style links optional
* Dark mode for Keepass [1](https://github.com/xatupal/KeeTheme) [2](https://github.com/BradyThe/DarkenKP)
* Linux:
  * change terminal name via ssh
  * Xubuntu dark mode
  * NPM
  * synaptic
  * baobab
  * circleci
  * libreoffice
* Windows:
  * TuneIn
  * steam
  * discord
  * dotnet
  * jdk
  * google drive
  * configure night light
  * optional sshd and remote-desktop config
  * issue-related git aliases for pwsh
* Configure rustup shell completion [here](https://rust-lang.github.io/rustup/installation/index.html)
* Try out [oh-my-fish](https://github.com/oh-my-fish/oh-my-fish)
* Set up conditional GPG things in `.gitconfig_local` or some such
* Adopt https://github.com/pop-os/shell ?
* Migrate to https://www.chezmoi.io/ ?
