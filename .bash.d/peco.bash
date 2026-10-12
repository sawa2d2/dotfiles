peco_search_history() {
    local selected

    selected=$(
        HISTTIMEFORMAT= history |
        sed -E 's/^ *[0-9]+ +//' |
        tac |
        peco --query "$READLINE_LINE"
    ) || return

    [[ -n "$selected" ]] || return
    READLINE_LINE=$selected
    READLINE_POINT=${#selected}
}

bind -x '"\C-r": peco_search_history'