# Append existing directories to PATH without duplicates.
path_add() {
    [[ -d "$1" && ":$PATH:" != *":$1:"* ]] && PATH="${PATH:+$PATH:}$1"
    return 0
}

[[ -n ${DOTPATH:-} ]] && path_add "$DOTPATH/bin"
[[ -n ${DOTPATH:-} ]] && path_add "$DOTPATH/private.d/bin"
path_add /usr/local/go/bin
[[ -n ${GOPATH:-} ]] && path_add "$GOPATH/bin"
[[ -n ${ANDROID_STUDIO:-} ]] && path_add "$ANDROID_STUDIO/bin"
path_add "${KREW_ROOT:-$HOME/.krew}/bin"

if [[ -n ${DOTPATH:-} ]]; then
    for dir in "$DOTPATH"/bin/*/; do
        [[ -d "$dir" ]] && path_add "${dir%/}"
    done
fi
export PATH
