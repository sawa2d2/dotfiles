#!/usr/bin/env zsh

# Minimal Zsh prompt with Git integration.

autoload -Uz add-zsh-hook

# Git status colors (shared palette).
# Load generated Git colors
if [[ -f "$DOTPATH/theme/generated/zsh-prompt.zsh" ]]; then
    source "$DOTPATH/theme/generated/zsh-prompt.zsh"
else
    _PROMPT_GIT_CLEAN='#55c9a6'
    _PROMPT_GIT_DIRTY='#e5a45b'
    _PROMPT_GIT_STAGED='#70aee0'
    _PROMPT_GIT_MIXED='#e27983'
fi

# Abbreviate the working directory to its last two components.
_prompt_path() {
    local dir_path="$PWD"
    local relative current parent

    if [[ "$dir_path" == "$HOME" ]]; then
        print -rn -- '~'
        return
    fi

    if [[ "$dir_path" == "$HOME/"* ]]; then
        dir_path="~${dir_path#"$HOME"}"
    fi

    if [[ "$dir_path" == "/" ]]; then
        print -rn -- '/'
        return
    fi

    relative="${dir_path#\~/}"
    relative="${relative#/}"

    current="${relative##*/}"
    parent="${relative%/*}"

    if [[ "$parent" == "$relative" || "$parent" != */* ]]; then
        print -rn -- "$dir_path"
    else
        print -rn -- ".../${parent##*/}/$current"
    fi
}

# Build the prompt before each command line.
_prompt_command_zsh() {
    local exit_status=$?
    local display_path branch="" dirty="" staged=""
    local git_color

    display_path="$(_prompt_path)"

    # Detect Git branch and working tree state.
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        branch="$(
            git symbolic-ref --quiet --short HEAD 2>/dev/null ||
            git rev-parse --short HEAD 2>/dev/null
        )"

        # Unstaged changes.
        if ! git diff --no-ext-diff --quiet 2>/dev/null; then
            dirty="*"
        fi

        # Staged changes.
        if ! git diff --no-ext-diff --cached --quiet 2>/dev/null; then
            staged="+"
        fi
    fi

    # Choose Git color.
    if [[ -n "$dirty" && -n "$staged" ]]; then
        git_color="$_PROMPT_GIT_MIXED"
    elif [[ -n "$dirty" ]]; then
        git_color="$_PROMPT_GIT_DIRTY"
    elif [[ -n "$staged" ]]; then
        git_color="$_PROMPT_GIT_STAGED"
    else
        git_color="$_PROMPT_GIT_CLEAN"
    fi

    PROMPT=""

    # Previous command failed.
    if (( exit_status != 0 )); then
        PROMPT+="%F{${_PROMPT_GIT_MIXED}}✘%f "
    fi

    # Escape Zsh prompt expansion characters.
    PROMPT+="${display_path//\%/%%}"

    if [[ -n "$branch" ]]; then
        branch="${branch//\%/%%}"

        PROMPT+=" %F{${git_color}}(${branch}"
        [[ -n "$dirty" ]] && PROMPT+=" *"
        [[ -n "$staged" ]] && PROMPT+=" +"
        PROMPT+=")%f"
    fi

    # $ for regular users, # for root.
    [[ -n "$branch" ]] && PROMPT+=" "
    PROMPT+="%(!.#.$) "
}

# Register once, even when sourced repeatedly.
add-zsh-hook -d precmd _prompt_command_zsh 2>/dev/null || true
add-zsh-hook precmd _prompt_command_zsh
