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

This will also set up ssh credentials for me and clone this repo with privileges. Further configuration and installation steps are provided by the below...

## Routine use:

Just run either `install.ps1` or `install.sh` as per shell type.

This will also run [SuperPack](https://github.com/martukas/superpack) to offer you installation of packages appropriate for your system.

## Updating repo

Symlinked files will stay up to date. You only need to commit and push. Except...

Run `update.sh` to extract and save settings for:
* guake

## Upgrading dependencies

Sometimes you may need to update submodules in this repo. Try `upgrade.sh`, but check to make sure it really worked as intended. This is still poorly tested.

## TODO

* wget bootstrap files now that repo is public
* custom hosts file for ssh remote aliases
* keepass dark mode [1](https://github.com/xatupal/KeeTheme) [2](https://github.com/BradyThe/DarkenKP)
* [Jetbrains remote](https://www.jetbrains.com/help/idea/remote-development-overview.html)
* Linux gui links optional
* Code style links optional
* Linux:
  * docker via apt
  * flameshot config
  * Rust
  * NPM & NVM
  * synaptic
  * baobab
  * circleci
  * libreoffice
  * InSync
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
* Adopt https://github.com/pop-os/shell ?
* Migrate to https://www.chezmoi.io/ ?

## Docker config
If docker was installed with snap, you should:
* open `/var/snap/docker/current/config/daemon.json` and change `storage-driver` from "overlay2" to "vfs"
* run `sudo snap restart docker`.
