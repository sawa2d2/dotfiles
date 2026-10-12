# Interactive shells only
[[ -o interactive ]] || return

# Locale and editor
export LANG=en_US.UTF-8
export EDITOR=vim
export MAGICK=convert

# Resolve dotfiles root
export DOTPATH="$(dirname "$(realpath "${(%):-%x}")")"

# Load private configuration
[[ -f "$DOTPATH/private.d/init.sh" ]] &&
    source "$DOTPATH/private.d/init.sh"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=200000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Terminal
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

if [[ -x /usr/bin/dircolors ]]; then
    if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
fi

[[ -t 0 ]] && stty werase undef

# Zsh extensions and widgets
for file in "$HOME"/.zsh.d/*.zsh(N); do
    source "$file"
done

# Command completion
autoload -Uz compinit
compinit

# User aliases
[[ -f "$HOME/.zsh_aliases" ]] && source "$HOME/.zsh_aliases"

# Start tmux on an interactive terminal, unless already inside tmux
if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] &&
   command -v tmux >/dev/null 2>&1; then
    tmux -u new-session
fi

