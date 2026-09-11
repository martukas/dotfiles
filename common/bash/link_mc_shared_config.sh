#!/bin/bash

# Link Minecraft modpack shared configuration (saves, config, journeymap, ...)
# out of cloud storage into a Prism/MultiMC instance, so worlds and settings
# travel between machines. Works on Linux and Windows (MSYS/Git Bash).
#
# Usage:
#   link_mc_shared_config.sh [pack] [--check]
#
#     pack     sevtech | atm10   (prompted if omitted)
#     --check  report link health and change nothing
#
# Windows note: directory links use junctions and need no special privileges.
# Linking an individual *file* needs a real symlink, which requires
# Administrator or Developer Mode. Only packs listing PACK_FILES are affected.

PACK=""
CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    -*)
      echo "Unknown option: $arg"
      exit 1
      ;;
    *) PACK="$arg" ;;
  esac
done

# --- Pack profiles -----------------------------------------------------------
# PACK_DIRS      directories to replace with links; may be nested (config/jei/world)
# PACK_FILES     individual files to replace with links (needs admin on Windows)
# PACK_SEED_ONCE files copied once and then left alone -- see the servers.dat
#                comment further down for why some files must not be linked
# PACK_UNLINK    paths that USED to be shared and no longer should be; converted
#                back into real local copies so a machine keeps what it has and
#                simply stops syncing it
#
# Share only what is portable between machines. Worlds, map data and keybinds
# travel fine. A whole config/ directory does not: it is hundreds of files of
# per-launch mod state, and it silently couples both machines to the same mod
# versions. Sharing it once left the title screen blank with unlabelled buttons,
# because a GUI-customisation mod read settings written by a different build.
pack_profile() {
  case "$1" in
    sevtech)
      PACK_DIRS="journeymap saves config"
      PACK_FILES=""
      PACK_SEED_ONCE="servers.dat"
      PACK_UNLINK=""
      ;;
    atm10)
      # config/jei/world holds JEI bookmarks and lookup history, per world.
      # local/ftbchunks holds map waypoints and claims. The rest of config/ and
      # local/ is machine-specific churn -- local/crash_assistant in particular
      # is PID-named lock files that two machines must not write concurrently.
      PACK_DIRS="saves journeymap config/jei/world local/ftbchunks"
      PACK_FILES="options.txt"
      PACK_SEED_ONCE=""
      PACK_UNLINK="config local"
      ;;
    *)
      return 1
      ;;
  esac
  return 0
}

if [ -z "$PACK" ]; then
  read -rp "Which pack? [sevtech/atm10]: " PACK
fi
if ! pack_profile "$PACK"; then
  echo "Unknown pack: $PACK (expected 'sevtech' or 'atm10')"
  exit 1
fi

# --- OS-specific defaults ----------------------------------------------------
if [[ $OSTYPE == "linux-gnu"* ]]; then
  PRISM_INSTANCES="${HOME}/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances"
  INSYNC_ROOT="${HOME}/Insync"
  case "$PACK" in
    sevtech) SUGGESTED_INSTANCE="${PRISM_INSTANCES}/SevTechAges" ;;
    atm10) SUGGESTED_INSTANCE="${PRISM_INSTANCES}/All the Mods 10 - ATM10" ;;
  esac
elif [[ $OSTYPE == "msys" || $OSTYPE == "cygwin" ]]; then
  if [ -n "$PACK_FILES" ] && ! net session &>/dev/null; then
    echo "Warning: this pack links individual files (${PACK_FILES}), which needs"
    echo "Administrator or Developer Mode on Windows. If it fails, reopen the"
    echo "terminal as Administrator."
    echo ""
  fi
  DETECTED_USER="${USER:-$(whoami)}"
  PRISM_INSTANCES="/c/Users/${DETECTED_USER}/AppData/Roaming/PrismLauncher/instances"
  INSYNC_ROOT="/c/Users/${DETECTED_USER}/Insync"
  case "$PACK" in
    sevtech) SUGGESTED_INSTANCE="${PRISM_INSTANCES}/SevTech- Ages" ;;
    atm10) SUGGESTED_INSTANCE="${PRISM_INSTANCES}/All the Mods 10 - ATM10" ;;
  esac
  # Ensure Git Bash creates real symlinks rather than copies
  export MSYS="winsymlinks:nativestrict"
else
  echo "Unsupported OS: $OSTYPE"
  exit 1
fi

# Insync nests everything under an account directory, e.g.
#   ~/Insync/you@gmail.com/Google Drive/fun/MC/shared_config
# Discover it the same way linux/packages.sh:install_prism_launcher does.
# Keeping every pack under that one granted path means the Prism flatpak
# override on Linux covers new packs without needing to be widened.
INSYNC_ACCOUNT=$(find "$INSYNC_ROOT" -maxdepth 1 -type d -name "*@*" 2>/dev/null | head -1)
if [ -n "$INSYNC_ACCOUNT" ]; then
  SUGGESTED_SHARED_ROOT="${INSYNC_ACCOUNT}/Google Drive/fun/MC/shared_config"
else
  SUGGESTED_SHARED_ROOT="${INSYNC_ROOT}/shared_config"
fi

strip_quotes() {
  echo "$1" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//'
}

read -rp "Enter instance path [$SUGGESTED_INSTANCE]: " INSTANCE_DIR
INSTANCE_DIR=$(strip_quotes "${INSTANCE_DIR:-$SUGGESTED_INSTANCE}")

read -rp "Enter shared config root [$SUGGESTED_SHARED_ROOT]: " SHARED_ROOT
SHARED_ROOT=$(strip_quotes "${SHARED_ROOT:-$SUGGESTED_SHARED_ROOT}")

# Prism uses ".minecraft" for MultiMC-imported instances and "minecraft" for
# newer ones, so accept either the instance root or the game dir itself.
resolve_game_dir() {
  local p="$1"
  if [ -d "$p/mods" ] || [ -d "$p/saves" ] || [ -f "$p/options.txt" ]; then
    echo "$p"
    return 0
  fi
  local sub
  for sub in .minecraft minecraft; do
    if [ -d "$p/$sub" ]; then
      echo "$p/$sub"
      return 0
    fi
  done
  echo "$p"
}

GAME_DIR=$(resolve_game_dir "$INSTANCE_DIR")
# Every pack gets its own subdirectory under the shared root, so packs never
# collide on common names like saves/ or config/.
SHARED_DIR="${SHARED_ROOT}/${PACK}"

echo ""
echo "Pack        : $PACK"
echo "Game dir    : $GAME_DIR"
echo "Shared dir  : $SHARED_DIR"
echo ""

if [ ! -d "$GAME_DIR" ]; then
  echo "Error: instance game directory not found: $GAME_DIR"
  exit 1
fi

# --- Check mode --------------------------------------------------------------
# A link can silently degenerate into a real file (see the servers.dat note),
# which looks fine but quietly stops syncing. This reports that rather than
# letting it go unnoticed.

# True if $1 is a link -- including a Windows junction or directory symlink, and
# including one whose target no longer exists. Bash's -L does not see junctions
# under MSYS, so a stale one would otherwise look like an ordinary directory.
is_link() {
  local target="$1"
  [ -L "$target" ] && return 0
  if [[ $OSTYPE == "msys" || $OSTYPE == "cygwin" ]]; then
    local parent base
    parent=$(cygpath -w "$(dirname "$target")") || return 1
    base=$(basename "$target")
    # dir /AL lists only reparse points (<JUNCTION>, <SYMLINK>, <SYMLINKD>).
    cmd //c dir //al "$parent" 2>/dev/null | grep -qiF "$base" && return 0
  fi
  return 1
}

# Report where a link points, for messages. Junctions do not answer readlink.
link_target() {
  readlink "$1" 2>/dev/null || echo "(unresolved)"
}

# Remove the link itself, never the contents it points at. On Windows a junction
# must go via rmdir: "rm -r" would delete straight through it into the shared
# copy. rmdir removes only the reparse point.
remove_link() {
  local target="$1"
  if [[ $OSTYPE == "msys" || $OSTYPE == "cygwin" ]]; then
    local win_target
    win_target=$(cygpath -w "$target")
    cmd //c rmdir "$win_target" >/dev/null 2>&1 && return 0
    cmd //c del //f //q "$win_target" >/dev/null 2>&1 && return 0
    echo "  ERROR: could not remove link: $target" >&2
    return 1
  fi
  rm -f "$target"
}

check_item() {
  local name="$1"
  local target="${GAME_DIR}/${name}"
  if is_link "$target"; then
    if [ -e "$target" ]; then
      printf '  %-24s OK (linked)\n' "$name"
    else
      printf '  %-24s BROKEN LINK -> %s\n' "$name" "$(link_target "$target")"
    fi
  elif [ -e "$target" ]; then
    printf '  %-24s NOT LINKED (real file/dir) -- shared copy is NOT updating\n' "$name"
  else
    printf '  %-24s absent\n' "$name"
  fi
}

# Reports paths that should no longer be shared but still are.
check_unlinked_item() {
  local name="$1"
  local target="${GAME_DIR}/${name}"
  if is_link "$target"; then
    printf '  %-24s STILL SHARED -- run without --check to un-share\n' "$name"
  else
    printf '  %-24s local only (correct)\n' "$name"
  fi
}

if [ "$CHECK_ONLY" = true ]; then
  echo "Link health:"
  for name in $PACK_DIRS $PACK_FILES; do
    check_item "$name"
  done
  for name in $PACK_SEED_ONCE; do
    printf '  %-24s (seed-once, never linked by design)\n' "$name"
  done
  for name in $PACK_UNLINK; do
    check_unlinked_item "$name"
  done
  exit 0
fi

if [ ! -d "$SHARED_DIR" ]; then
  echo "Shared directory does not exist yet: $SHARED_DIR"
  read -rp "Create it and seed this machine's files into it? [y/N]: " reply
  case "$reply" in
    [yY]*) mkdir -p "$SHARED_DIR" ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
fi

# --- Linking -----------------------------------------------------------------
create_link() {
  local source="$1"
  local target="$2"
  local is_dir="$3"

  if [[ $OSTYPE == "msys" || $OSTYPE == "cygwin" ]]; then
    local win_source win_target
    win_source=$(cygpath -w "$source")
    win_target=$(cygpath -w "$target")
    if [ "$is_dir" = true ]; then
      # Junction: no admin required
      cmd //c mklink //j "$win_target" "$win_source"
    else
      # File symlink: needs admin or Developer Mode
      cmd //c mklink "$win_target" "$win_source"
    fi
  else
    ln -s "$source" "$target"
  fi
}

# Replace an instance path with a link into the shared config.
#   - never deletes the local copy with nothing to link it to
#   - seeds the shared copy from this machine if the shared side is empty
#   - if both sides exist, keeps the shared copy and moves the local one aside
#     rather than deleting it, so a newer local world is never silently lost
link_shared_item() {
  local name="$1"
  local is_dir="$2"
  local source="${SHARED_DIR}/${name}"
  local target="${GAME_DIR}/${name}"

  echo "Processing ${name}..."

  if is_link "$target"; then
    if [ -e "$target" ]; then
      echo "  already a link. Skipping."
      return 0
    fi
    # A dangling link (shared root moved/renamed) is still a link, so a plain
    # existence test would skip it and leave the instance broken. Drop it and
    # relink below; removing a broken link discards nothing.
    echo "  Replacing broken link -> $(link_target "$target")"
    remove_link "$target" || return 1
  fi

  if [ ! -e "$source" ]; then
    if [ -e "$target" ]; then
      echo "  Seeding shared copy from this machine: $target -> $source"
      mv "$target" "$source" || return 1
    else
      echo "  SKIPPING: not present on either side."
      return 1
    fi
  elif [ -e "$target" ]; then
    local backup
    backup="${target}.local-backup-$(date +%Y%m%d-%H%M%S)"
    echo "  Both sides exist; shared copy wins."
    echo "  Moving local copy aside to: $backup"
    mv "$target" "$backup" || return 1
  fi

  echo "  Linking ${name}: $target -> $source"
  # Nested names (config/jei/world) need their parent to exist before linking.
  mkdir -p "$(dirname "$target")" || return 1
  create_link "$source" "$target" "$is_dir"
}

# --- Un-sharing --------------------------------------------------------------
# Turns a previously shared path back into a real local copy holding whatever the
# shared side currently has, so the machine keeps its content and merely stops
# syncing it. Used to retire an over-broad share without losing anything.
unlink_shared_item() {
  local name="$1"
  local target="${GAME_DIR}/${name}"
  local source="${SHARED_DIR}/${name}"

  echo "Un-sharing ${name}..."

  if ! is_link "$target"; then
    if [ -e "$target" ]; then
      echo "  already a real local copy. Nothing to do."
    else
      echo "  absent. Nothing to do."
    fi
    return 0
  fi

  if [ ! -e "$source" ]; then
    echo "  Link is broken and the shared copy is gone; removing the dead link."
    remove_link "$target" || return 1
    return 0
  fi

  # Copy first, so a failure here leaves the existing link untouched.
  local staging="${target}.unsharing-$$"
  echo "  Copying shared content to a local copy (this may take a moment)..."
  if ! cp -a "$source" "$staging"; then
    echo "  ERROR: copy failed; leaving the link in place." >&2
    rm -rf "$staging"
    return 1
  fi
  if ! remove_link "$target"; then
    rm -rf "$staging"
    return 1
  fi
  mv "$staging" "$target" || return 1
  echo "  Done: ${name} is now local-only and no longer syncs."
}

echo "Setting up links for $PACK..."
echo ""

# Retire over-broad shares first, so a path being un-shared cannot collide with
# a narrower path being linked underneath it (config -> config/jei/world).
for name in $PACK_UNLINK; do
  unlink_shared_item "$name"
done

for name in $PACK_DIRS; do
  link_shared_item "$name" true
done

for name in $PACK_FILES; do
  link_shared_item "$name" false
done

# --- Seed-once files ---------------------------------------------------------
# Some files must never be linked. Minecraft saves servers.dat with a
# write-to-temp plus rename (Util.safeReplaceFile): it renames servers.dat aside
# to servers.dat_old and moves a fresh real file into place. That destroys the
# link on the first in-game save and silently strands the shared copy, giving a
# false impression that the file is syncing. A hard link fails identically --
# the rename leaves the shared copy pointing at the old inode.
# Directories are immune: the rename happens *inside* the linked directory, so
# the link itself is never touched.
for name in $PACK_SEED_ONCE; do
  echo "Processing ${name}..."
  if [ -L "${GAME_DIR}/${name}" ]; then
    echo "  Found a stale link from an older run; replacing with a real copy."
    rm -f "${GAME_DIR}/${name}"
  fi
  if [ -e "${GAME_DIR}/${name}" ]; then
    echo "  Leaving existing ${name} in place (cannot be linked; see comment in script)."
  elif [ -f "${SHARED_DIR}/${name}" ]; then
    echo "  Seeding ${name} from shared config (one-time copy; will NOT stay in sync)."
    cp "${SHARED_DIR}/${name}" "${GAME_DIR}/${name}"
  else
    echo "  No shared ${name} to seed from; skipping."
  fi
done

echo ""
echo "Done. Verify any time with:  $(basename "$0") $PACK --check"
