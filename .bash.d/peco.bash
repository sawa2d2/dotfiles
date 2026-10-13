peco_kill() {
    local selected pid

    selected=$(ps ax -o pid=,time=,command= | peco) || return
    [[ -n "$selected" ]] || return

    pid=${selected%%[[:space:]]*}
    kill "$pid"
}
