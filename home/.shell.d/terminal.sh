# Initialize terminal helpers after private shell configuration.
dotfiles_terminal_init() {
    if [[ -x /usr/bin/lesspipe ]]; then
        eval "$(SHELL=/bin/sh lesspipe)"
    fi

    if [[ -x /usr/bin/dircolors ]]; then
        if [[ -r "$HOME/.dircolors" ]]; then
            eval "$(dircolors -b "$HOME/.dircolors")"
        else
            eval "$(dircolors -b)"
        fi
    fi

    if [[ -t 0 ]] && command -v stty >/dev/null 2>&1; then
        stty werase undef
    fi
}
