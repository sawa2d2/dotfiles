# Interactive shells only
[[ -o interactive ]] || return

# Locale
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en

# Resolve dotfiles root and load shared initialization
export DOTPATH="$(dirname "$(dirname "$(realpath "${(%):-%x}")")")"
# Keep readline-style Ctrl-A/Ctrl-E editing even when EDITOR is nvim/vi.
bindkey -e
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line

# Load private configuration
[[ -f "$DOTPATH/private.d/.zshrc" ]] &&
    source "$DOTPATH/private.d/.zshrc"

# Load reusable Bash/Zsh modules after private PATH additions.
for file in "$DOTPATH"/home/.shell.d/*.sh; do
    [[ -f "$file" ]] && source "$file"
done
unset file

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
dotfiles_terminal_init

# Zsh extensions and widgets
for file in "$HOME"/.zsh.d/*.zsh(N); do
    source "$file"
done

# User aliases
[[ -f "$DOTPATH/home/.bash_aliases" ]] && source "$DOTPATH/home/.bash_aliases"
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
dotfiles_tmux_auto_start
