# Start tmux only after shell-specific initialization has completed.
dotfiles_tmux_auto_start() {
    if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] &&
       command -v tmux >/dev/null 2>&1; then
        # Reuse a session no client is attached to (e.g. left by a closed
        # terminal) so they don't pile up; the most recently active one wins.
        local session
        session=$(tmux list-sessions -F '#{session_attached} #{session_activity} #{session_id}' 2>/dev/null |
            awk '$1 == 0 && (id == "" || $2 > best) { best = $2; id = $3 } END { print id }')
        if [[ -n $session ]]; then
            tmux -u attach-session -t "$session"
        else
            tmux -u new-session
        fi
    fi
}
