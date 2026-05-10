# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo

Cross-platform dotfiles for Linux (Xubuntu) and Windows. [dotbot](https://github.com/anishathalye/dotbot) (submodule)
handles symlinking; [superpack](https://github.com/martukas/superpack) (submodule, uv-based) handles package management.
Sensitive data lives in the `private/` submodule (SSH-only URL by design).

A parallel `GEMINI.md` covers the same project for Gemini CLI — keep both in sync when overall architecture changes.

## Commands

This is a configuration repo — no build/test target.

- **Fresh-machine bootstrap (Linux)**:
  `bash <(wget -qO- https://github.com/martukas/dotfiles/raw/master/bootstrap/bootstrap.sh)`. Installs
  git/ssh/python/xclip, runs `config_ssh.sh` (clones repo to `~/dev/dotfiles`), then chains into `install.sh`.
- **Re-run installer**: `./install.sh` (Linux) or `.\install.ps1` (Windows). Syncs submodules, optionally runs one-time
  apt/snap/pipx/superpack installers, optionally applies XFCE+Guake config, then runs dotbot.
- **Lint**: `pre-commit run --all-files`. Hooks include `shellcheck`, `shfmt -w -s -ci -bn -i 2`, `markdownlint-fix`,
  `prettier`, plus custom hooks that snapshot Guake dconf and XFCE settings into the repo on every commit (Linux only).

`README.md` documents the post-install alias inventory (`dfu`, `df-upgrade`, `commit-push`, etc.) — those run inside an
installed environment, not from the repo dir.

## Architecture

### Distro-aware install path

`install.sh` is the single Linux entrypoint. `linux/_distro.sh` (sourced from `install.sh` and `linux/packages.sh`)
exports `DISTRO_ID`, `DISTRO_VERSION`, `DISTRO_VERSION_MAJOR`, `DISTRO_CODENAME` from `/etc/os-release`. New per-version
branching should go through these vars, not ad-hoc `uname` / `lsb_release` checks. Idempotent pipx installs use the
`pipx_ensure` helper in `install.sh` — use it for any new pipx tool, not raw `pipx install`.

### dotbot symlinks

Two configs run sequentially: `conf_common.yaml` (cross-platform) then `conf_linux.yaml` (Linux). The Linux config has
three buckets gated by guards:

- always-link
- GUI-gated (`if: '[ -n "$XDG_CURRENT_DESKTOP" ]'`) — `~/.config/autostart/*`, KeePass / flameshot / redshift / mimeapps
  configs. Skipped on headless/non-GUI sessions.
- project-dir-gated (`if: "[ -d ~/dev/ess ]"` etc.) — JetBrains `.idea` for specific dev projects. Skipped on machines
  without those checkouts.

When changing what gets symlinked, edit the relevant `conf_*.yaml`. Don't modify dotbot itself.

### Submodules

`dotbot`, `superpack`, `private`, `common/bash/plugins/dircolors-solarized`, `common/bash-git-prompt`, `linux/logiops`.
All initialized by `install.sh`. `private/` is treated as "dirty-ignored" in the parent — commit changes inside the
submodule first, then bump the parent pointer in a separate commit.

### Test infrastructure (`test_infra/`)

Two-tier test bed for validating `install.sh` changes without touching the workstation:

- **`df26` (Multipass headless)** — `multipass launch daily:26.04`, host repo bind-mounted into the VM. Validates
  structural things only (dotbot exit codes, file placement). Cannot validate anything that needs a graphical session.
- **`gui26` (libvirt + Xubuntu desktop, agent-driven via SSH)** — `test_infra/gui-vm.sh` is the lifecycle CLI: `setup`,
  `start`, `reset [name]`, `snapshot [name] [--replace]`, `ssh [...]` (with `-A` baked in), `status`, `teardown --yes`.
  Runs under `qemu:///session` (no system permissions / libvirt group ACL needed). Two snapshots: `pristine`
  (post-Xubuntu-install + sshd + bake) and `bootstrapped` (post-bootstrap.sh, pre-install.sh — repo cloned at
  `~/dev/dotfiles` with submodules synced). The install.sh iteration loop is
  `reset bootstrapped → ssh → cd ~/dev/dotfiles && ./install.sh`.

`docs/superpowers/ubuntu26-progress.md` (gitignored, per-developer) tracks current state on the `ubuntu26` branch and
known gotchas. Read it first when resuming work on that branch.

## Agent collaboration

### Iterative dev cycle

The cycle for fixing or adding `install.sh` features. When running directly on the target machine, skip the VM steps and
iterate in place — edit → `./install.sh` → observe. When targeting a fresh-machine scenario or cross-distro validation,
use `gui26`:

#### Via `gui26` VM

1. **Agent**: `gui-vm.sh reset bootstrapped` (host-side wrapper).
1. **User**: `gui-vm.sh ssh` → `cd ~/dev/dotfiles && git pull && ./install.sh`. **The user always drives `install.sh`**,
   never the agent.
1. Observe failure or wrong behavior.
1. **Agent**: SSH into the VM (separately) to investigate — read state, query dconf/xfconf/systemd, inspect filesystem,
   run hypotheses. VM state is throwaway during this phase — free to `sudo apt install foo`, `dconf write`, `rm`, etc.
   to test ideas, since the next `reset` wipes it.
1. **Agent**: edit the dotfiles repo on the **host** (never inside the VM).
1. **User**: commits + pushes.
1. Loop back to step 1 — fresh snapshot, fresh pull, re-run `install.sh` from cold to confirm end-to-end.

`bootstrapped` is re-baked rarely — only when `bootstrap.sh` / `config_ssh.sh` themselves change, or when the snapshot
drifts so far from current code that pulls become unwieldy. Re-baking `pristine` or `bootstrapped` from scratch is a
user-driven flow (interactive Xubuntu install + bake handoff). The agent only runs the host-side `gui-vm.sh` commands.

**Viewer caveat**: `gui-vm.sh start` and `reset` background `virt-viewer` with stderr suppressed, so they always claim
"viewer opened" whether it actually did. After running, ask the user to confirm the viewer window is visible before
assuming we're ready to proceed.

### Communication discipline

- **State what you're about to run and what should happen** _before_ running it.
- **Check in at every user-action boundary**. When the next step is something the user does (in the VM, in the viewer,
  in another shell), stop and wait for explicit confirmation that they actually did it. Don't accept side-channel
  signals ("VM is off") as proof a multi-step procedure completed ("bootstrap ran successfully") — those are different
  claims.
- **Don't assume execution**. Treat every suggested command as not-yet-run until the user confirms. Same for steps the
  user is supposed to drive — verify, don't infer.
- **One decision per message** during measured-mode work: specific decision + your lean + brief rationale + a direct
  ask. Avoid 2- or 3-option enumerations that push synthesis onto the user.

### Repo-specific rules

- **No AI identity in commits**. No `Co-Authored-By` or any AI attribution.
- **Match fix scope to bug**. Surgical fixes only — don't bundle in cleanup, refactors, or unrelated changes by default.
- **"Committed" means `git commit`d**. For unstaged edits, say "saved / applied / wrote / patched."
- **Verify git state before claiming**. Check `git config`, `remote -v`, `ls` before claiming a workaround is needed
  (especially around submodules + bind mounts).
- **Name the test-bed layer**. Don't conflate "install script exits clean in df26" with "feature works." Always say
  which layer (df26 headless / gui26 GUI / target hardware / direct on workstation).
- **Persistent scripts over ad-hoc**. Nontrivial multi-step work goes into a persistent script (gitignored if not
  committable). When the script hits an edge case, fix the script — don't bolt on a manual workaround.
- **Use the canonical wrapper**. `test_infra/gui-vm.sh` has the right state handling, viewer lifecycle, and snapshot
  naming baked in. Use it instead of calling `virsh` directly when there's an equivalent subcommand.
