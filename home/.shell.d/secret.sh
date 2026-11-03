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
    local value
    value=$(command load-secret ${force:+"$force"} "$1") || return
    export "$1=$value"
}
