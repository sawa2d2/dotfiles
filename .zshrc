# Interactive shells only
[[ -o interactive ]] || return

# Locale and editor
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
#
# Editor fallback: nvim -> vim -> vi
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
elif command -v vim >/dev/null 2>&1; then
    export EDITOR=vim
else
    export EDITOR=vi
fi

export MAGICK=convert

# Resolve dotfiles root
export DOTPATH="$(dirname "$(realpath "${(%):-%x}")")"

# Load private configuration
[[ -f "$DOTPATH/private.d/init.sh" ]] &&
    source "$DOTPATH/private.d/init.sh"

# Shared PATH configuration
[[ -f "$DOTPATH/.bash.d/path.bash" ]] &&
    source "$DOTPATH/.bash.d/path.bash"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=20000
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

# User aliases
[[ -f "$DOTPATH/.bash_aliases" ]] && source "$DOTPATH/.bash_aliases"
[[ -f "$HOME/.zsh_aliases" ]] && source "$HOME/.zsh_aliases"

# Homebrew Zsh plugins
if command -v brew >/dev/null 2>&1; then
    BREW_PREFIX=$(brew --prefix)

    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        plugin_file="$BREW_PREFIX/share/$plugin/$plugin.zsh"
        [[ -f "$plugin_file" ]] && source "$plugin_file"
    done

    unset BREW_PREFIX plugin plugin_file
fi

# Start tmux on an interactive terminal, unless already inside tmux
if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] &&
   command -v tmux >/dev/null 2>&1; then
    tmux -u new-session
fi
