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

# Keep readline-style Ctrl-A/Ctrl-E editing even when EDITOR is nvim/vi.
bindkey -e
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# Resolve dotfiles root
export DOTPATH="$(dirname "$(realpath "${(%):-%x}")")"

# Load private configuration
[[ -f "$DOTPATH/private.d/init.sh" ]] &&
    source "$DOTPATH/private.d/init.sh"

# Shared PATH configuration
[[ -f "$DOTPATH/.bash.d/path.bash" ]] &&
    source "$DOTPATH/.bash.d/path.bash"

# Allow comments in interactive commands (including pasted snippets).
setopt INTERACTIVE_COMMENTS

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

[[ -t 0 ]] && command -v stty >/dev/null 2>&1 && stty werase undef

# Zsh extensions and widgets
for file in "$HOME"/.zsh.d/*.zsh(N); do
    source "$file"
done

# User aliases
[[ -f "$DOTPATH/.bash_aliases" ]] && source "$DOTPATH/.bash_aliases"
[[ -f "$HOME/.zsh_aliases" ]] && source "$HOME/.zsh_aliases"

# Prefer Nix-managed Zsh plugins, with Homebrew as a fallback.
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    plugin_file="$HOME/.local/share/zsh/plugins/$plugin/$plugin.zsh"
    if [[ -f "$plugin_file" ]]; then
        source "$plugin_file"
    elif (( $+commands[brew] )); then
        plugin_file="$(brew --prefix)/share/$plugin/$plugin.zsh"
        [[ -f "$plugin_file" ]] && source "$plugin_file"
    fi
done
unset plugin plugin_file

# Start tmux on an interactive terminal, unless already inside tmux
if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] &&
   command -v tmux >/dev/null 2>&1; then
    tmux -u new-session
fi
