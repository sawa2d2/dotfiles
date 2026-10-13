# Prioritize commands from the developer checkout over system-installed copies.
path_prepend() {
    [[ -d "$1" ]] || return 0
    if [[ -n ${ZSH_VERSION:-} ]]; then
        path=("$1" "${(@)path:#$1}")
        return 0
    fi
    local item
    local -a parts kept=()
    IFS=: read -r -a parts <<< "$PATH"
    for item in "${parts[@]}"; do
        [[ $item == "$1" ]] || kept+=("$item")
    done
    local remainder
    remainder=$(IFS=:; echo "${kept[*]}")
    PATH="$1${remainder:+:$remainder}"
    return 0
}

configure_developer_path() {
    local -a dirs
    local dir i
    # Build the list in precedence order, then prepend in reverse.
    dirs=("$DOTPATH/bin" "$DOTPATH/private.d/bin")
    for dir in "$DOTPATH"/bin/*/; do
        [[ -d "$dir" ]] && dirs+=("${dir%/}")
    done
    local offset=0
    [[ -n ${ZSH_VERSION:-} ]] && offset=1
    for (( i=${#dirs[@]}-1+offset; i>=offset; i-- )); do
        path_prepend "${dirs[i]}"
    done
}

[[ -n ${DOTPATH:-} ]] && configure_developer_path
export PATH
