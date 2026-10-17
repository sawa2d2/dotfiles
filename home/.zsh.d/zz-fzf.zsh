# fzf widgets for interactive Zsh.
(( $+commands[fzf] )) || return 0
# Remove stale color options exported by the previous theme loader.
# Keep all other fzf defaults; colors now come from FZF_DEFAULT_OPTS_FILE.
if [[ ${FZF_DEFAULT_OPTS:-} == *--color=* ]]; then
    FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS//--color=[^[:space:]]*/}"
    export FZF_DEFAULT_OPTS
fi
export FZF_DEFAULT_OPTS_FILE="$DOTPATH/theme/generated/fzf.opts"

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
