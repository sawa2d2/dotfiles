# ~/.bashrc — common interactive Bash settings
case $- in
    *i*) ;;
      *) return ;;
esac

# Machine-specific variables needed by path.bash.
[[ -f "$HOME/.bash.private.d/bootstrap.bash" ]] &&
    source "$HOME/.bash.private.d/bootstrap.bash"

# Locale and editor
export LANG=en_US.UTF-8
export EDITOR=vim
export MAGICK=convert

# History
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=100000
HISTFILESIZE=200000
# Avoid multiplying the hook when ~/.bashrc is re-sourced.
case ";${PROMPT_COMMAND:-};" in
    *';history -a; history -n;'*) ;;
    *) PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

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

# Bash widgets
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

# Private overrides (bootstrap already loaded above)
for file in "$HOME"/.bash.private.d/*.bash; do
    [[ -f "$file" && "$file" != */bootstrap.bash ]] && source "$file"
done


# Start tmux on an interactive terminal, unless already inside tmux.
if [[ -z ${TMUX:-} && -t 0 && -t 1 ]] && command -v tmux >/dev/null 2>&1; then
    tmux -u new-session
fi
