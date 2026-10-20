# Load nvm for interactive Bash and Zsh; installation is handled by scripts/install-nvm.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Activate the default Node.js by following nvm's alias files, which avoids
# nvm's slow default selection at every shell startup.
_dotfiles_nvm_use_default() {
    local name=default hops=0 bin rest entry kept=
    while [[ -f "$NVM_DIR/alias/$name" ]] && ((hops++ < 10)); do
        read -r name < "$NVM_DIR/alias/$name" || return 1
    done
    bin="$NVM_DIR/versions/node/v${name#v}/bin"
    # Partial versions such as "24" still need nvm's own resolution.
    if [[ ! $name =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ || ! -d "$bin" ]]; then
        nvm use --silent default > /dev/null
        return
    fi

    # Replace any Node.js version inherited from a parent shell, as nvm does.
    rest="$PATH:"
    while [[ -n $rest ]]; do
        entry=${rest%%:*}
        rest=${rest#*:}
        case $entry in
        "$NVM_DIR"/versions/node/*/bin) ;;
        *) kept="$kept:$entry" ;;
        esac
    done
    export PATH="$bin$kept"
    export NVM_BIN="$bin"
    export NVM_INC="${bin%/bin}/include/node"
}

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh" --no-use
    if [[ -n ${BASH_VERSION:-} && -s "$NVM_DIR/bash_completion" ]]; then
        source "$NVM_DIR/bash_completion"
    fi
    _dotfiles_nvm_use_default
fi
unset -f _dotfiles_nvm_use_default
