# Interactive shells only
case $- in
*i*) ;;
*) return ;;
esac

# Initialize ble.sh (without attaching yet)
if command -v blesh-share >/dev/null 2>&1; then
    source "$(blesh-share)/ble.sh" --attach=none
elif [[ -f "$HOME/.local/share/blesh/ble.sh" ]]; then
    source "$HOME/.local/share/blesh/ble.sh" --attach=none
fi

# Locale
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en

# Resolve dotfiles root and load shared initialization
export DOTPATH="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"
# Load private configuration
[[ -f "$DOTPATH/private.d/home/.bashrc" ]] &&
	source "$DOTPATH/private.d/home/.bashrc"

# Load reusable Bash/Zsh modules after private PATH additions.
for file in "$DOTPATH"/home/.shell.d/*.sh; do
    [[ -f "$file" ]] && source "$file"
done
unset file

# History
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# Synchronize history across sessions without duplicating the hook
#case ";${PROMPT_COMMAND:-};" in
#    *';history -a; history -n;'*) ;;
#    *) PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
#esac

# Terminal
dotfiles_terminal_init

# Bash extensions and widgets
for file in "$HOME"/.bash.d/*.bash; do
	[[ -f "$file" ]] && source "$file"
done

# Command completion
if ! shopt -oq posix; then
	if [[ -f /usr/share/bash-completion/bash_completion ]]; then
		source /usr/share/bash-completion/bash_completion
	elif [[ -f /etc/bash_completion ]]; then
		source /etc/bash_completion
	fi
fi

# User aliases
[[ -f "$HOME/.bash_aliases" ]] && source "$HOME/.bash_aliases"

# Start tmux on an interactive terminal, unless already inside tmux
dotfiles_tmux_auto_start

# Attach ble.sh after shell initialization
type ble-attach &>/dev/null && ble-attach
