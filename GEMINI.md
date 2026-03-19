# Gemini Project Context: Dotfiles

This project is a cross-platform (Windows & Linux) dotfiles management system. It leverages `dotbot` for symlinking and `SuperPack` for package management.

## Project Architecture

- **Symlink Management**: Uses [dotbot](https://github.com/anishathalye/dotbot) via submodules. Configuration is split into `conf_common.yaml`, `conf_linux.yaml`, and `conf_windows.yaml`.
- **Package Management**: Uses [SuperPack](https://github.com/martukas/superpack) (a custom package installer) to handle OS-specific dependencies defined in `linux/packages.yml` and `windows/packages.yml`.
- **Submodules**:
    - `dotbot`: The linking engine.
    - `superpack`: The package manager.
    - `private`: A private submodule for sensitive/personal configurations (SSH keys, private gitconfig, etc.).
    - Various shell plugins (e.g., `bash-git-prompt`, `dircolors-solarized`).

## Core Components

- **`bootstrap/`**: Contains initial setup scripts (`bootstrap.sh`, `bootstrap.ps1`) for "naked" systems.
- **`common/`**: Platform-agnostic configurations for Bash, PowerShell, and Git.
- **`linux/`**: Linux-specific scripts, binary utilities, and application configs (XFCE, Guake, etc.).
- **`windows/`**: Windows-specific scripts, package lists, and AppData configs.
- **`code-style/`**: JetBrains `.idea` configurations for various projects.

## Installation & Updates

### Windows
1. Run `bootstrap\bootstrap.ps1` (as Administrator).
2. Run `.\install.ps1`. This will:
    - Sync submodules.
    - Optionally run one-time installation scripts (via `windows\packages.ps1`).
    - Use `dotbot` to link common and Windows-specific files.

### Linux
1. Run `bootstrap/bootstrap.sh`.
2. Run `./install.sh`. This will:
    - Sync submodules.
    - Optionally install system packages (via `apt`, `snap`, `pipx`).
    - Optionally apply XFCE/Desktop settings.
    - Use `dotbot` to link common and Linux-specific files.

## Development Guidelines

1. **Private Data**: Never commit secrets to the main repo. Use the `private/` submodule.
2. **Cross-platform Consistency**: When adding aliases or functions, attempt to implement them in both `common/bash/aliases.sh` and `common/powershell/Aliases.ps1`.
3. **Modifying Links**: Update the relevant `conf_*.yaml` files. `dotbot` handles the heavy lifting.
4. **Submodules**: Remember that `private` state is often ignored in the parent repo; commit changes there first.
