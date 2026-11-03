# Load a 1Password secret into the current Bash/Zsh shell.
# bin/secret/load-secret does the work and prints the value; only a shell
# function can export it into this shell. See bin/secret/README.md.
# Usage: load-secret [-f] [ENV_NAME] (no arguments: list available names;
#   -f: skip the cache)
load-secret() {
    local force=
    if [[ ${1:-} == -f ]]; then
        force=-f
        shift
    fi
    (( $# == 1 )) || { command load-secret ${force:+"$force"} "$@"; return; }
    local value session rc=0
    value=$(LOAD_SECRET_SIGNIN=shell command load-secret ${force:+"$force"} "$1") || rc=$?
    # Status 3: signed out of 1Password. Sign in here, since only this shell
    # can keep the session variable op signin prints, then retry once.
    if (( rc == 3 )); then
        printf 'load-secret: signing in to 1Password\n' >&2
        if session=$(op signin) && eval "$session"; then
            rc=0
            value=$(LOAD_SECRET_SIGNIN=shell command load-secret ${force:+"$force"} "$1") || rc=$?
        else
            printf 'load-secret: 1Password sign-in failed\n' >&2
        fi
    fi
    if (( rc != 0 )); then
        printf 'load-secret: failed to load %s\n' "$1" >&2
        return "$rc"
    fi
    export "$1=$value"
    printf 'load-secret: loaded %s\n' "$1" >&2
}
