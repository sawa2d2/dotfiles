# fzf widgets for interactive Zsh.
(( $+commands[fzf] )) || return 0
[[ -f "$DOTPATH/theme/generated/fzf.sh" ]] && source "$DOTPATH/theme/generated/fzf.sh"

fzf-history() {
    local selected
    selected=$(fc -rl 1 | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
        fzf --query "$LBUFFER") || return
    [[ -n $selected ]] || return
    BUFFER=$selected
    CURSOR=${#BUFFER}
    zle redisplay
}
zle -N fzf-history
bindkey '^R' fzf-history
