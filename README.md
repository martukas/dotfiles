# My dotfiles

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
* The usual add-commit-push, or the `commit-push` alias
* symlinked files will stay up to date
* occasionally run `update.sh` to extract and save settings for guake
* `dirty` state in `private` part will be ignored by git. Commit changes to that submodule separately.

## Manual installation for now

* [InSync](https://www.insynchq.com/downloads/linux)
* Dark mode for Keepass [1](https://github.com/xatupal/KeeTheme) [2](https://github.com/BradyThe/DarkenKP)
* [Jetbrains remote](https://www.jetbrains.com/help/idea/remote-development-overview.html)

## TODO

* wget bootstrap files now that repo is public
* Linux gui links optional
* Code style links optional
* Linux:
  * NPM & NVM
  * conan
  * platformio
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
* Set up conditional GPG things in `.gitconfig_local` or some such
* custom hosts file for ssh remote aliases
* Adopt https://github.com/pop-os/shell ?
* Migrate to https://www.chezmoi.io/ ?
