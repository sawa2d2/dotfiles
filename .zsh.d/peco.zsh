# Ctrl+R: Search command history with peco
peco-history() {
    local selected

    selected=$(
        fc -rl 1 |
        sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
        peco --query "$LBUFFER"
    ) || return

    [[ -n "$selected" ]] || return

    BUFFER="$selected"
    CURSOR=${#BUFFER}
    zle redisplay
}

zle -N peco-history
bindkey '^R' peco-history