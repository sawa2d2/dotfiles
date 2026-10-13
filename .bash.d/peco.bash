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

peco_kill() {
    local selected pid

    selected=$(ps ax -o pid=,time=,command= | peco) || return
    [[ -n "$selected" ]] || return

    pid=${selected%%[[:space:]]*}
    kill "$pid"
}


ghq_peco_repo() {
    local selected
    selected=$(ghq list -p | peco --query "$READLINE_LINE") || return
    [[ -n "$selected" ]] || return

    cd -- "$selected" || return
    READLINE_LINE=
    READLINE_POINT=0
}
bind -x '"\C-g": ghq_peco_repo'

