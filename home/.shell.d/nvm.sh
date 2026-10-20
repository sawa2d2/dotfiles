# Load nvm for interactive Bash and Zsh; installation is handled by scripts/install-nvm.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# Activate the default Node.js by following nvm's alias files, which avoids
# nvm's slow default selection at every shell startup.
_dotfiles_nvm_use_default() {
    local name=default hops=0 prefix dir version best= bin rest entry kept=
    local v1 v2 v3 b1 b2 b3
    while [[ -f "$NVM_DIR/alias/$name" ]] && ((hops++ < 10)); do
        read -r name < "$NVM_DIR/alias/$name" || return 1
    done

    # Like nvm, "node"/"stable" mean the newest installed version, and partial
    # versions such as "24" the newest installed match.
    if [[ $name == node || $name == stable ]]; then
        prefix=
    elif [[ $name =~ ^v?[0-9]+(\.[0-9]+){0,2}$ ]]; then
        prefix="v${name#v}"
    else
        # Other aliases (system, iojs, ...) need nvm's own resolution.
        nvm use --silent default > /dev/null
        return
    fi
    [[ -n ${ZSH_VERSION:-} ]] && setopt local_options null_glob
    for dir in "$NVM_DIR"/versions/node/v*; do
        version=${dir##*/}
        [[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && -d $dir/bin ]] || continue
        [[ -z $prefix || $version == "$prefix" || $version == "$prefix".* ]] || continue
        IFS=. read -r v1 v2 v3 <<< "${version#v}"
        if [[ -n $best ]]; then
            IFS=. read -r b1 b2 b3 <<< "${best#v}"
            ((v1 > b1 || (v1 == b1 && (v2 > b2 || (v2 == b2 && v3 > b3))))) || continue
        fi
        best=$version
    done
    if [[ -z $best ]]; then
        nvm use --silent default > /dev/null
        return
    fi
    bin="$NVM_DIR/versions/node/$best/bin"

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
