# Append existing directories to PATH without duplicates.
path_add() {
    [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && PATH="${PATH:+$PATH:}$1"
    return 0
}

[[ -n ${DOTPATH:-} ]] && path_add "$DOTPATH/bin"
[[ -n ${DOTPATH:-} ]] && path_add "$DOTPATH/private.d/bin"

if [[ -n ${DOTPATH:-} ]]; then
    for dir in "$DOTPATH"/bin/*/; do
        [[ -d "$dir" ]] && path_add "${dir%/}"
    done
fi
export PATH
