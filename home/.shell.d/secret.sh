# Load a 1Password secret into the current Bash/Zsh shell.
# bin/secret/load-secret does the work and prints the value; only a shell
# function can export it into this shell. See bin/secret/README.md.
# Usage: load-secret [ENV_NAME] (no arguments: list available names)
load-secret() {
    (( $# == 1 )) || { command load-secret "$@"; return; }
    local value
    value=$(command load-secret "$1") || return
    export "$1=$value"
}
