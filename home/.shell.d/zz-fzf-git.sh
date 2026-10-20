# Shared Git/fzf commands for Bash and Zsh.
# Keep shell-specific history widgets and key bindings in their own files.
command -v fzf >/dev/null 2>&1 || return 0

# Reject interactive Git operations outside a repository.
_fzf_git_require_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 && return 0
  echo 'Not a Git repository' >&2
  return 1
}

# One entry per branch; the first tab-separated field holds the Git ref.
# Display order: LOCAL / REMOTE / BRANCH / WORKTREE.
_fzf_git_branch_candidates() {
  {
    git worktree list --porcelain | awk '
      /^worktree / { path = substr($0, 10) }
      /^branch refs\/heads\// {
        name = substr($0, 19)
        print "W\t" name "\t" path
      }
    '
    git for-each-ref --format='R%09%(refname)%09%(committerdate:unix)' refs/heads refs/remotes
  } | awk -F '\t' -v home="$HOME" '
    $1 == "W" {
      path = $3
      if (home != "" && (path == home || index(path, home "/") == 1))
        path = "~" substr(path, length(home) + 1)
      worktree[$2] = path
      next
    }
    $1 == "R" && $2 ~ /^refs\/heads\// {
      name = substr($2, 12)
      local_ref[name] = name
      if ($3 > date[name]) date[name] = $3
      next
    }
    $1 == "R" && $2 ~ /^refs\/remotes\/[^\/]+\// && $2 !~ /\/HEAD$/ {
      ref = substr($2, 14)
      name = ref
      sub(/^[^\/]+\//, "", name)
      if (!(name in remote_ref) || ref ~ /^origin\//)
        remote_ref[name] = ref
      if ($3 > date[name]) date[name] = $3
    }
    END {
      # Align worktree paths after the longest displayed branch name.
      for (name in date)
        if (length(name) > max_name_length) max_name_length = length(name)
      if (max_name_length > 42) max_name_length = 42
      for (name in date) {
        local_mark = name in local_ref ? "*" : "-"
        remote_mark = name in remote_ref ? "*" : "-"
        ref = name in local_ref ? local_ref[name] : remote_ref[name]
        # Limit the displayed name only; keep the full ref for selection/search.
        display_name = length(name) > 42 ? substr(name, 1, 39) "..." : name
        if (name in worktree)
          printf "%s\t%s\t%s %s  %-*s %s\n",
            date[name], ref, local_mark, remote_mark, max_name_length, display_name, worktree[name]
        else
          printf "%s\t%s\t%s %s  %s\n",
            date[name], ref, local_mark, remote_mark, display_name
      }
    }
  ' | sort -t "$(printf '\t')" -k1,1nr | cut -f2-
}

_fzf_git_select_branch() {
  local selected header
  header='LOCAL REMOTE BRANCH WORKTREE'
  selected=$(_fzf_git_branch_candidates |
    fzf --layout=reverse --no-sort --delimiter="$(printf '\t')" --with-nth=2 \
      --header="$header" --nth=1,2 --prompt='[ BRANCH ] > ' \
      --preview 'git log --oneline --max-count=12 --color=always {1}') || return
  [[ -n $selected ]] || return 1
  printf '%s\n' "${selected%%$(printf '\t')*}"
}

gbr() {
  _fzf_git_require_repo || return 1
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
    echo 'Usage: gbr [branch] | gbr -b <new-branch> | gbr -d|-D [branch]' >&2
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
  _fzf_git_require_repo || return 1
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
  if (($# == 2)) && [[ $1 == -m ]]; then
    worktree_dir=$(gwt-path -m "$2") || return
  elif (($# == 2)) && [[ $1 == -b ]]; then
    worktree_dir=$(gwt-path -b "$2") || return
  elif (($# == 1)) && [[ $1 != -* ]]; then
    worktree_dir=$(gwt-path "$1") || return
  elif (($# == 0)); then
    branch=$(_fzf_git_select_branch) || return
    [[ -n $branch ]] || return
    worktree_dir=$(gwt-path "$branch") || return
  else
    echo 'Usage: gwt [-b|-d|-m] [branch]' >&2
    return 2
  fi
  cd -- "$worktree_dir"
}
