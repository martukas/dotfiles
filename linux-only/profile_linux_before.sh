# shellcheck disable=SC2148
# shellcheck disable=SC2034
# shellcheck disable=SC1091

# Enable Rust tools
if [ -f "${HOME}/.cargo/bin/rustup" ]; then
    . "${HOME}/.cargo/env"
fi

# Enable Node version manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# This may be needed by PlatformIO at the very least
export PATH=$PATH:$HOME/.local/bin

# TODO: are these really necessary?
NPM_PACKAGES="${HOME}/.npm-packages"
NODE_PATH="$NPM_PACKAGES/lib/node_modules:$NODE_PATH"
PATH="$NPM_PACKAGES/bin:$PATH"
# Unset manpath so we can inherit from /etc/manpath via the `manpath`
# command
unset MANPATH # delete if you already modified MANPATH elsewhere in your config
MANPATH="$NPM_PACKAGES/share/man:$(manpath)"
export PATH=~/.npm-global/bin:$PATH
