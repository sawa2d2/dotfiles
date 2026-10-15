# fzf widgets for interactive Bash.
command -v fzf > /dev/null 2>&1 || return 0
[[ -f "$DOTPATH/theme/generated/fzf.sh" ]] && source "$DOTPATH/theme/generated/fzf.sh"

fzf_search_history() {
  local selected
  selected=$(HISTTIMEFORMAT= history | sed -E 's/^ *[0-9]+ +//' | tac | fzf --query "$READLINE_LINE") || return
  [[ -n $selected ]] || return
  READLINE_LINE=$selected
  READLINE_POINT=${#selected}
}

fzf_change_directory() {
  local selected
  selected=$(
    {
      printf '%s\n' "$HOME/Documents" "$HOME/Desktop" "$HOME/.config"
      find "$PWD" -mindepth 1 -maxdepth 1 -type d ! -name '.*' -print 2> /dev/null
      if command -v zoxide > /dev/null 2>&1; then zoxide query --list 2> /dev/null; fi
      if command -v ghq > /dev/null 2>&1; then ghq list -p 2> /dev/null; fi
    } | awk '!seen[$0]++' | fzf --query "${READLINE_LINE:-}"
  ) || return
  [[ -d $selected ]] || return
  cd -- "$selected" || return
  READLINE_LINE=
  READLINE_POINT=0
}

fzf_gists() {
  local selected gist_id filename content
  command -v gh > /dev/null 2>&1 || {
    echo 'gh is not installed' >&2
    return 1
  }
  selected=$(gh api --paginate gists --jq '.[] | [.id, (.description // ""), (.files | keys | join(", "))] | @tsv' |
    fzf --prompt '[ SELECT GIST ] >') || return
  [[ -n $selected ]] || return
  gist_id=${selected%%$'\t'*}
  filename=$(gh gist view "$gist_id" --files | fzf --prompt '[ SELECT FILE ] >') || return
  [[ -n $filename ]] || return
  content=$(gh gist view "$gist_id" --filename "$filename" --raw) || return
  READLINE_LINE=$content
  READLINE_POINT=${#READLINE_LINE}
}

fzf_kill() {
  local selected pid
  selected=$(ps ax -o pid=,time=,command= | fzf) || return
  [[ -n $selected ]] || return
  pid=${selected%%[[:space:]]*}
  kill "$pid"
}

# Interactive key bindings.
if [[ -n ${BLE_VERSION:-} ]]; then
  ble-bind -x 'C-r' fzf_search_history
  ble-bind -x 'C-]' fzf_change_directory
  ble-bind -x 'M-g' fzf_gists
else
  bind -x '"\C-r": fzf_search_history'
  bind -x '"\C-]": fzf_change_directory'
  bind -x '"\eg": fzf_gists'
fi

# Select a branch name without relying on fzf-git.sh's private return format.
_fzf_git_select_branch() {
  git for-each-ref --format='%(refname:short)' refs/heads refs/remotes |
    grep -v '/HEAD$' |
    fzf --prompt='[ BRANCH ] > ' --preview 'git log --oneline --max-count=12 --color=always {}'
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
  local branch path selected
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
    path=$(gwt-path -d "$branch") || return
    cd -- "$path"
    return
  fi
  if (($# == 2)) && [[ $1 == -b ]]; then
    path=$(gwt-path -b "$2") || return
  elif (($# == 1)) && [[ $1 != -* ]]; then
    path=$(gwt-path "$1") || return
  elif (($# == 0)); then
    branch=$(_fzf_git_select_branch) || return
    [[ -n $branch ]] || return
    path=$(gwt-path "$branch") || return
  else
    echo 'Usage: gwt [-b|-d] [branch]' >&2
    return 2
  fi
  cd -- "$path"
}

# Load fzf-git shortcuts after the other interactive key bindings.
fzf_git_script="$HOME/.local/opt/fzf-git.sh/fzf-git.sh"
if [[ -f "$fzf_git_script" ]]; then
  source "$fzf_git_script"
fi
unset fzf_git_script
