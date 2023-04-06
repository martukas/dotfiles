# One ring to rule them all

[![bash](https://img.shields.io/badge/GNU-Bash-4eaa25?logo=gnubash)](https://github.com/PowerShell/PowerShell)
[![PowerShell](https://img.shields.io/badge/PowerShell-7-26405f?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.10-E95420?logo=ubuntu)](https://github.com/PowerShell/PowerShell)
[![Windows10](https://img.shields.io/badge/Windows-10-0078D6?logo=windows)](https://github.com/PowerShell/PowerShell)

These are my dotfiles and bootstrap scripts for Linux (mainly Xubuntu) and Win10+ systems.

If on Windows, before doing anything else, you:
* Must run `Set-ExecutionPolicy RemoteSigned` for PS1 scripts to work
* Should prevent OneDrive from taking over your home directories as described [here](https://answers.microsoft.com/en-us/windows/forum/all/taking-back-control-of-your-folders-from-onedrive/7b7ad05e-8b05-4bcd-9772-9e4eee880346):
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
