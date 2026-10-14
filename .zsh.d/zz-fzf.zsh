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


fbr() {
    local branch
    branch=$(_fzf_git_branches) || return
    [[ -n $branch ]] || return
    if git show-ref --verify --quiet "refs/remotes/$branch"; then
        local local_branch=${branch#*/}
        if git show-ref --verify --quiet "refs/heads/$local_branch"; then
            git switch "$local_branch"
        else
            git switch --track "$branch"
        fi
    else
        git switch "$branch"
    fi
}

# Load fzf-git shortcuts after the other interactive key bindings.
fzf_git_script="$HOME/.local/opt/fzf-git.sh/fzf-git.sh"
if [[ -f "$fzf_git_script" ]]; then
    source "$fzf_git_script"
fi
unset fzf_git_script
