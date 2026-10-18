# fzf widgets for interactive Bash.
command -v fzf > /dev/null 2>&1 || return 0
# Remove stale color options exported by the previous theme loader.
# Keep all other fzf defaults; colors now come from FZF_DEFAULT_OPTS_FILE.
if [[ ${FZF_DEFAULT_OPTS:-} == *--color=* ]]; then
  FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS//--color=[^[:space:]]*/}"
  export FZF_DEFAULT_OPTS
fi
export FZF_DEFAULT_OPTS_FILE="$DOTPATH/theme/generated/fzf.opts"

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
