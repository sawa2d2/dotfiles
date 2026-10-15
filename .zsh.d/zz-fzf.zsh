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


# Select a branch name without relying on fzf-git.sh's private return format.
_fzf_git_select_branch() {
  git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads refs/remotes |
    grep -v '/HEAD
}

gbr() {
    local branch
    if [[ ${1:-} == -b ]]; then
      if (($# != 2)) || [[ -z $2 ]]; then
        echo 'Usage: gbr -b <new-branch>' >&2
        return 2
      fi
      git switch -c "$2"
      return
    fi
    if [[ ${1:-} == -d || ${1:-} == -D ]] && (($# <= 2)); then
      if (($# == 2)); then
        branch=$2
      else
        branch=$(git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/heads |
        fzf --layout=reverse --no-sort --prompt='[ DELETE BRANCH ] > ' --preview 'git log --oneline --max-count=12 --color=always {}') || return
        [[ -n $branch ]] || return
      fi
      git branch "$1" -- "$branch"
      return
    fi
    if (($# == 0)); then
      branch=$(_fzf_git_select_branch) || return
      [[ -n $branch ]] || return
    elif (($# == 1)) && [[ -n $1 && $1 != -* ]]; then
      branch=$1
    else
      echo 'Usage: gbr [branch] | fbr -b <new-branch> | fbr -d|-D [branch]' >&2
      return 2
    fi
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

gwt() {
  local branch worktree_dir selected
  if [[ ${1:-} == -d ]] && (($# <= 2)); then
    if (($# == 2)); then
      branch=$2
    else
      selected=$(git worktree list --porcelain | awk '
        /^worktree / {
          if (count++ > 1 && branch != "") print branch "|" path
          path = substr($0, 10)
          branch = ""
        }
        /^branch / { branch = substr($0, 19) }
        END { if (count > 1 && branch != "") print branch "|" path }
      ' | while IFS= read -r entry; do
        ref=${entry%%|*}
        timestamp=$(git log -1 --format=%ct "$ref" 2>/dev/null) || timestamp=0
        printf '%s\t%s\n' "${timestamp:-0}" "$entry"
      done | sort -rn | cut -f2- |
        fzf --layout=reverse --no-sort --delimiter='|' --with-nth=1,2 --prompt='[ REMOVE WORKTREE ] >') || return
      [[ -n $selected ]] || return
      branch=${selected%%|*}
    fi
    worktree_dir=$(gwt-path -d "$branch") || return
    cd -- "$worktree_dir"
    return
  fi
  if (($# == 2)) && [[ $1 == -b ]]; then
    worktree_dir=$(gwt-path -b "$2") || return
  elif (($# == 1)) && [[ $1 != -* ]]; then
    worktree_dir=$(gwt-path "$1") || return
  elif (($# == 0)); then
    branch=$(_fzf_git_select_branch) || return
    [[ -n $branch ]] || return
    worktree_dir=$(gwt-path "$branch") || return
  else
    echo 'Usage: gwt [-b|-d] [branch]' >&2
    return 2
  fi
  cd -- "$worktree_dir"
}

# Load fzf-git shortcuts after the other interactive key bindings.
fzf_git_script="$HOME/.local/opt/fzf-git.sh/fzf-git.sh"
if [[ -f "$fzf_git_script" ]]; then
    source "$fzf_git_script"
fi
unset fzf_git_script
 |
    fzf --layout=reverse --no-sort --prompt='[ BRANCH ] > ' --preview 'git log --oneline --max-count=12 --color=always {}'
}

gbr() {
    local branch
    if [[ ${1:-} == -b ]]; then
      if (($# != 2)) || [[ -z $2 ]]; then
        echo 'Usage: gbr -b <new-branch>' >&2
        return 2
      fi
      git switch -c "$2"
      return
    fi
    if [[ ${1:-} == -d || ${1:-} == -D ]] && (($# <= 2)); then
      if (($# == 2)); then
        branch=$2
      else
        branch=$(_fzf_git_branches --bind 'alt-a:ignore' --border-label 'DELETE BRANCH (-d/-D)') || return
        [[ -n $branch ]] || return
      fi
      git branch "$1" -- "$branch"
      return
    fi
    if (($# == 0)); then
      branch=$(_fzf_git_select_branch) || return
      [[ -n $branch ]] || return
    elif (($# == 1)) && [[ -n $1 && $1 != -* ]]; then
      branch=$1
    else
      echo 'Usage: gbr [branch] | fbr -b <new-branch> | fbr -d|-D [branch]' >&2
      return 2
    fi
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

gwt() {
  local branch worktree_dir selected
  if [[ ${1:-} == -d ]] && (($# <= 2)); then
    if (($# == 2)); then
      branch=$2
    else
      selected=$(git worktree list --porcelain | awk '
        /^worktree / {
          if (count++ > 1 && branch != "") print branch "|" path
          path = substr($0, 10)
          branch = ""
        }
        /^branch / { branch = substr($0, 19) }
        END { if (count > 1 && branch != "") print branch "|" path }
      ' | fzf --delimiter='|' --with-nth=1,2 --prompt='[ REMOVE WORKTREE ] >') || return
      [[ -n $selected ]] || return
      branch=${selected%%|*}
    fi
    worktree_dir=$(gwt-path -d "$branch") || return
    cd -- "$worktree_dir"
    return
  fi
  if (($# == 2)) && [[ $1 == -b ]]; then
    worktree_dir=$(gwt-path -b "$2") || return
  elif (($# == 1)) && [[ $1 != -* ]]; then
    worktree_dir=$(gwt-path "$1") || return
  elif (($# == 0)); then
    branch=$(_fzf_git_select_branch) || return
    [[ -n $branch ]] || return
    worktree_dir=$(gwt-path "$branch") || return
  else
    echo 'Usage: gwt [-b|-d] [branch]' >&2
    return 2
  fi
  cd -- "$worktree_dir"
}

# Load fzf-git shortcuts after the other interactive key bindings.
fzf_git_script="$HOME/.local/opt/fzf-git.sh/fzf-git.sh"
if [[ -f "$fzf_git_script" ]]; then
    source "$fzf_git_script"
fi
unset fzf_git_script
