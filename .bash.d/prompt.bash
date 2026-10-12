#!/usr/bin/env bash

# Minimal Bash prompt with Git integration.

# Load Git prompt support if available.
if ! declare -F __git_ps1 >/dev/null; then
    for file in \
        /usr/lib/git-core/git-sh-prompt \
        /usr/share/git/completion/git-prompt.sh \
        /etc/bash_completion.d/git-prompt
    do
        if [[ -f "$file" ]]; then
            source "$file"
            break
        fi
    done
fi

# Git colors (True Color).
_PROMPT_GIT_CLEAN='\[\e[1;38;2;85;201;166m\]'   # Sea Green
_PROMPT_GIT_DIRTY='\[\e[1;38;2;229;164;91m\]'   # Amber
_PROMPT_GIT_STAGED='\[\e[1;38;2;112;174;224m\]' # Blue
_PROMPT_GIT_MIXED='\[\e[1;38;2;226;121;131m\]'  # Red
_PROMPT_RESET='\[\e[0m\]'

# Abbreviate the working directory to its last two components.
_prompt_path() {
    local path="$PWD"
    local relative

    # Display HOME as ~.
    if [[ "$path" == "$HOME" ]]; then
        printf '~'
        return
    fi

    if [[ "$path" == "$HOME/"* ]]; then
        path="~${path#"$HOME"}"
    fi

    # Preserve root.
    if [[ "$path" == "/" ]]; then
        printf '/'
        return
    fi

    # Count directory components, ignoring the root or home prefix.
    relative="${path#\~/}"
    relative="${relative#/}"

    local current="${relative##*/}"
    local parent="${relative%/*}"

    if [[ "$parent" == "$relative" || "$parent" != */* ]]; then
        printf '%s' "$path"
    else
        printf '.../%s/%s' "${parent##*/}" "$current"
    fi
}

# Build the prompt.
_prompt_command() {
    local status=$?

    history -a
    history -n

    local path branch="" dirty="" staged=""
    local git_color

    path="$(_prompt_path)"

    # Detect Git branch and working tree state.
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null ||
                  git rev-parse --short HEAD 2>/dev/null)"

        # Unstaged changes (tracked files).
        if ! git diff --no-ext-diff --quiet 2>/dev/null; then
            dirty="*"
        fi

        # Staged changes.
        if ! git diff --no-ext-diff --cached --quiet 2>/dev/null; then
            staged="+"
        fi
    fi

    # Choose Git color based on status.
    if [[ -n "$dirty" && -n "$staged" ]]; then
        git_color="$_PROMPT_GIT_MIXED"
    elif [[ -n "$dirty" ]]; then
        git_color="$_PROMPT_GIT_DIRTY"
    elif [[ -n "$staged" ]]; then
        git_color="$_PROMPT_GIT_STAGED"
    else
        git_color="$_PROMPT_GIT_CLEAN"
    fi


    # Build prompt, starting with the previous command status.
    PS1=""
    
    if (( status != 0 )); then
        PS1+="${_PROMPT_GIT_MIXED}✘${_PROMPT_RESET} "
    fi
    
    PS1+="${path}"
    
    if [[ -n "$branch" ]]; then
        PS1+=" ${git_color}(${branch}"
        [[ -n "$dirty" ]] && PS1+=" *"
        [[ -n "$staged" ]] && PS1+=" +"
        PS1+=")${_PROMPT_RESET}"
    fi
    
    # $ for regular users, # for root.
    PS1+=" ${_PROMPT_RESET}\\\$ "
}

PROMPT_COMMAND=_prompt_command
