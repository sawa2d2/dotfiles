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

# Locale and editor
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en

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
export DOTPATH="$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")"

# Load private configuration
[[ -f "$DOTPATH/private.d/.bashrc" ]] &&
	source "$DOTPATH/private.d/.bashrc"

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
shopt -s checkwinsize
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

if [[ -x /usr/bin/dircolors ]]; then
	if [[ -r "$HOME/.dircolors" ]]; then
		eval "$(dircolors -b "$HOME/.dircolors")"
	else
		eval "$(dircolors -b)"
	fi
fi

[[ -t 0 ]] && stty werase undef

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
if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] && command -v tmux >/dev/null 2>&1; then
	tmux -u new-session
fi

# Attach ble.sh after shell initialization
type ble-attach &>/dev/null && ble-attach
