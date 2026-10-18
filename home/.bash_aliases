# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'

alias de='cd ~/Desktop'
alias dl='cd ~/Downloads'

# Change to the directory containing an executable resolved by which-basedir.
cwhich() {
  if (($# != 1)); then
    printf 'Usage: cwhich <command>\n' >&2
    return 2
  fi

  local target
  target=$("$DOTPATH/bin/which-basedir" "$1") || return
  cd -- "$target"
}

# Directory operations
alias md='mkdir -p'

unalias rm 2> /dev/null || true
rm() {
  local trash_cmd=""

  if command -v trash-put > /dev/null 2>&1; then
    trash_cmd=$(command -v trash-put)
  elif [[ $(uname -s) == Darwin ]]; then
    for candidate in \
      /opt/homebrew/opt/trash-cli/bin/trash-put \
      /usr/local/opt/trash-cli/bin/trash-put; do
      if [[ -x "$candidate" ]]; then
        trash_cmd="$candidate"
        break
      fi
    done
  fi

  if [[ -n "$trash_cmd" ]]; then
    "$trash_cmd" "$@"
  else
    printf 'Warning: trash-put not found; falling back to permanent deletion.\n' >&2
    command rm "$@"
  fi
}

# Directory listing
alias ls='ls --color=auto -FA'
alias l='\ls -lhA'
alias ll='\ls -lh'
alias la='\ls -lha'

# Editors
unalias vi 2> /dev/null || true
alias vimrc='$EDITOR ~/.vimrc'

_shell_rc() {
  if [ -n "${ZSH_VERSION:-}" ]; then
    printf '%s\n' "$HOME/.zshrc"
  else
    printf '%s\n' "$HOME/.bashrc"
  fi
}

sr() {
  . "$(_shell_rc)"
}

# Terminal and SSH
alias less='/usr/bin/less -+F'
alias sshconf='vi ~/.ssh/config'

# Development tools
alias qiita='npx qiita'
alias grep='grep --color=auto'

# Return to the primary worktree after gfinish removes the active feature worktree.
gfinish() {
  local current primary
  current=$(git rev-parse --show-toplevel) || return
  primary=$(git worktree list --porcelain | sed -n '1s/^worktree //p') || return
  command gfinish "$@" || return
  if [[ ! -d $current ]]; then
    cd -- "$primary"
  fi
}
