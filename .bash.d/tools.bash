# Rust toolchain
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Node Version Manager
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

eval "$(zoxide init bash --cmd cd)"

function ide() {
  [[ -n ${TMUX:-} ]] || {
    echo "Not inside tmux" >&2
    return 1
  }

  tmux split-window -v -p 30
  tmux split-window -h -p 40
  tmux select-pane -L
  tmux select-pane -U
}
