#!/bin/bash

# Script to link Minecraft modpack shared configuration (saves, config, journeymap, servers.dat).
# Works on both Linux and Windows (MSYS/Git Bash).
# Note: On Windows, run this script as Administrator to allow creating file symbolic links.

# Define suggested defaults based on OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    SUGGESTED_MC_DIR="${HOME}/.local/share/PrismLauncher/instances/SevTech- Ages/.minecraft"
    SUGGESTED_SHARED_DIR="${HOME}/Insync/shared_config"
elif [[ "$OSTYPE" == "msys" ]]; then
    # Check for Administrator privileges on Windows
    if ! net session &>/dev/null; then
        echo "Warning: This script may need Administrator privileges to create file symbolic links (e.g., for servers.dat)."
        echo "If it fails, please restart your terminal as Administrator."
        echo ""
    fi
    # Use USER or whoami
    DETECTED_USER="${USER:-$(whoami)}"
    SUGGESTED_MC_DIR="/c/Users/${DETECTED_USER}/AppData/Roaming/PrismLauncher/instances/SevTech- Ages/.minecraft"
    SUGGESTED_SHARED_DIR="/c/Users/${DETECTED_USER}/Insync/shared_config"
    # Ensure Git Bash creates real symlinks if possible
    export MSYS="winsymlinks:nativestrict"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

read -rp "Enter Minecraft instance .minecraft path [$SUGGESTED_MC_DIR]: " MINECRAFT_DIR
MINECRAFT_DIR="${MINECRAFT_DIR:-$SUGGESTED_MC_DIR}"
# Strip potential quotes from paste
MINECRAFT_DIR=$(echo "$MINECRAFT_DIR" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')

read -rp "Enter Shared Config path [$SUGGESTED_SHARED_DIR]: " SHARED_CONFIG_DIR
SHARED_CONFIG_DIR="${SHARED_CONFIG_DIR:-$SUGGESTED_SHARED_DIR}"
# Strip potential quotes from paste
SHARED_CONFIG_DIR=$(echo "$SHARED_CONFIG_DIR" | sed -e "s/^'//" -e "s/'$//" -e 's/^"//' -e 's/"$//')

if [ ! -d "$MINECRAFT_DIR" ]; then
    echo "Error: Minecraft directory not found: $MINECRAFT_DIR"
    exit 1
fi

if [ ! -d "$SHARED_CONFIG_DIR" ]; then
    echo "Error: Shared config directory not found: $SHARED_CONFIG_DIR"
    exit 1
fi

# Helper function to create links based on OS
create_link() {
    local source="$1"
    local target="$2"
    local is_dir="$3"

    if [[ "$OSTYPE" == "msys" ]]; then
        # Convert to Windows paths for mklink
        local win_source=$(cygpath -w "$source")
        local win_target=$(cygpath -w "$target")
        
        if [ "$is_dir" = true ]; then
            # Use Junction for directories (no admin required)
            cmd //c mklink //j "$win_target" "$win_source"
        else
            # Use Symlink for files (might require Dev Mode/Admin)
            cmd //c mklink "$win_target" "$win_source"
        fi
    else
        ln -s "$source" "$target"
    fi
}

echo "Setting up symlinks for Minecraft modpack shared configuration..."

# --- Journeymap ---
echo "Processing journeymap..."
if [ -d "${MINECRAFT_DIR}/journeymap" ] && [ ! -L "${MINECRAFT_DIR}/journeymap" ]; then
    echo "  Removing original journeymap directory: ${MINECRAFT_DIR}/journeymap"
    rm -rf "${MINECRAFT_DIR}/journeymap"
fi
if [ ! -L "${MINECRAFT_DIR}/journeymap" ]; then
    echo "  Creating link for journeymap: ${MINECRAFT_DIR}/journeymap -> ${SHARED_CONFIG_DIR}/journeymap"
    create_link "${SHARED_CONFIG_DIR}/journeymap" "${MINECRAFT_DIR}/journeymap" true
else
    echo "  journeymap is already a link. Skipping."
fi

# --- Saves ---
echo "Processing saves..."
if [ -d "${MINECRAFT_DIR}/saves" ] && [ ! -L "${MINECRAFT_DIR}/saves" ]; then
    echo "  Removing original saves directory: ${MINECRAFT_DIR}/saves"
    rm -rf "${MINECRAFT_DIR}/saves"
fi
if [ ! -L "${MINECRAFT_DIR}/saves" ]; then
    echo "  Creating link for saves: ${MINECRAFT_DIR}/saves -> ${SHARED_CONFIG_DIR}/saves"
    create_link "${SHARED_CONFIG_DIR}/saves" "${MINECRAFT_DIR}/saves" true
else
    echo "  saves is already a link. Skipping."
fi

# --- Config ---
echo "Processing config..."
if [ -d "${MINECRAFT_DIR}/config" ] && [ ! -L "${MINECRAFT_DIR}/config" ]; then
    echo "  Removing original config directory: ${MINECRAFT_DIR}/config"
    rm -rf "${MINECRAFT_DIR}/config"
fi
if [ ! -L "${MINECRAFT_DIR}/config" ]; then
    echo "  Creating link for config: ${MINECRAFT_DIR}/config -> ${SHARED_CONFIG_DIR}/config"
    create_link "${SHARED_CONFIG_DIR}/config" "${MINECRAFT_DIR}/config" true
else
    echo "  config is already a link. Skipping."
fi

# --- Servers.dat ---
echo "Processing servers.dat..."
if [ -f "${MINECRAFT_DIR}/servers.dat" ] && [ ! -L "${MINECRAFT_DIR}/servers.dat" ]; then
    echo "  Removing original servers.dat file: ${MINECRAFT_DIR}/servers.dat"
    rm -f "${MINECRAFT_DIR}/servers.dat"
fi
if [ ! -L "${MINECRAFT_DIR}/servers.dat" ]; then
    echo "  Creating link for servers.dat: ${MINECRAFT_DIR}/servers.dat -> ${SHARED_CONFIG_DIR}/servers.dat"
    create_link "${SHARED_CONFIG_DIR}/servers.dat" "${MINECRAFT_DIR}/servers.dat" false
else
    echo "  servers.dat is already a link. Skipping."
fi

echo "Symlinking process complete."
