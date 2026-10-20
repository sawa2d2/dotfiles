# fzf widgets for interactive Zsh.
(( $+commands[fzf] )) || return 0
# Remove stale color options exported by the previous theme loader.
# Keep all other fzf defaults; colors now come from FZF_DEFAULT_OPTS_FILE.
if [[ ${FZF_DEFAULT_OPTS:-} == *--color=* ]]; then
    FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS//--color=[^[:space:]]*/}"
    export FZF_DEFAULT_OPTS
fi
export FZF_DEFAULT_OPTS_FILE="$DOTPATH/theme/generated/fzf.opts"
# Append each default once; re-sourcing and child shells inherit the variable.
_fzf_default_opt() {
    [[ " ${FZF_DEFAULT_OPTS:-} " == *" $1 "* ]] ||
        export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS }$1"
}
# Wrap from last to first candidate (and vice versa).
_fzf_default_opt --cycle
# Vim-style half-page navigation within fzf.
_fzf_default_opt --bind=ctrl-d:half-page-down,ctrl-u:half-page-up
unset -f _fzf_default_opt

# Resolve session colors only when fzf starts; preserve all other colors.
fzf() {
    local accent selected colors
    if [[ -n ${TMUX:-} ]] && (( $+commands[tmux] )); then
        colors=$(tmux display-message -p '#{@color_accent} #{@color_selected}' 2>/dev/null)
        accent=${colors%% *}
        selected=${colors#* }
        # Zsh treats quoted =~ patterns differently from Bash; use glob matching.
        if [[ $accent == \#?????? && $selected == \#?????? ]]; then
            command fzf --color="bg+:$selected,hl:$accent,prompt:$accent,pointer:$accent" "$@"
            return $?
        fi
    fi
    command fzf "$@"
}

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
