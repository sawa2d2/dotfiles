# Start tmux only after shell-specific initialization has completed.
dotfiles_tmux_auto_start() {
    if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] &&
       command -v tmux >/dev/null 2>&1; then
        tmux -u new-session
    fi
}
