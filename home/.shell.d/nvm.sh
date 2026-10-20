# Load nvm for interactive Bash and Zsh; installation is handled by scripts/install-nvm.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
    if [[ -n ${BASH_VERSION:-} && -s "$NVM_DIR/bash_completion" ]]; then
        source "$NVM_DIR/bash_completion"
    fi
fi
