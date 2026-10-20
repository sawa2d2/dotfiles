# Interactive shells only
[[ -o interactive ]] || return

# Keep the first occurrence of each PATH entry.
typeset -gU path

# Directory stack and terminal behavior.
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt NO_BEEP

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
[[ -f "$DOTPATH/private.d/home/.zshrc" ]] &&
    source "$DOTPATH/private.d/home/.zshrc"

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
# Load them once per shell: re-sourcing this file (e.g. via sr) would wrap
# every zle widget again, slowing down both reloads and key handling.
if (( ! ${+_dotfiles_zsh_plugins_loaded} )); then
    typeset -g _dotfiles_zsh_plugins_loaded=1
    # Run brew at most once, and not at all when brew shellenv already set it.
    brew_prefix=${HOMEBREW_PREFIX:-}
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        plugin_file="$HOME/.local/share/zsh/plugins/$plugin/$plugin.zsh"
        if [[ ! -f "$plugin_file" ]]; then
            if [[ -z "$brew_prefix" ]] && (( $+commands[brew] )); then
                brew_prefix=$(brew --prefix)
            fi
            plugin_file="${brew_prefix:-/nonexistent}/share/$plugin/$plugin.zsh"
        fi
        [[ -f "$plugin_file" ]] && source "$plugin_file"
    done
    unset plugin plugin_file brew_prefix
fi

# Start tmux on an interactive terminal, unless already inside tmux
dotfiles_tmux_auto_start
