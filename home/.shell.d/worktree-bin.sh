# While the shell is inside a checkout or linked worktree of a trusted repository,
# put its bin/ first on PATH so it shadows the main checkout's copy (`ai restart`
# instead of `./bin/ai restart`). Only allowlisted origins are trusted: an
# arbitrary clone must not be able to inject commands.
[[ $- == *i* ]] || return 0

# Extend with space-separated host/owner/repo entries in DOTFILES_WORKTREE_BIN_REPOS
# (e.g. from private.d).
_dotfiles_worktree_bin_repos='github.com/sawa2d2/local-ai github.com/sawa2d2/dotfiles github.com/sawa2d2/agent-config'
# Newline-separated "root<TAB>origin" entries, so git runs once per root.
_dotfiles_worktree_bin_cache=${_dotfiles_worktree_bin_cache-}

_dotfiles_worktree_bin_update() {
    local ret=$? root=$PWD origin bin= entry kept= rest
    [[ $PWD == "${_dotfiles_worktree_bin_pwd-}" ]] && return $ret
    _dotfiles_worktree_bin_pwd=$PWD

    # .git is a directory in a main checkout and a file in a linked worktree.
    while [[ -n $root && ! -e $root/.git ]]; do
        root=${root%/*}
    done
    if [[ -n $root && -d $root/bin ]]; then
        case $_dotfiles_worktree_bin_cache in
        *$'\n'"$root"$'\t'*)
            origin=${_dotfiles_worktree_bin_cache#*$'\n'"$root"$'\t'}
            origin=${origin%%$'\n'*}
            ;;
        *)
            # Normalize https://, ssh:// and scp-like URLs to host/owner/repo.
            origin=$(command git -C "$root" config --get remote.origin.url 2>/dev/null)
            origin=${origin%/}
            origin=${origin%.git}
            origin=${origin#*://}
            origin=${origin#*@}
            origin=${origin/://}
            _dotfiles_worktree_bin_cache+=$'\n'"$root"$'\t'"$origin"
            ;;
        esac
        case " $_dotfiles_worktree_bin_repos ${DOTFILES_WORKTREE_BIN_REPOS-} " in
        *" $origin "*) [[ -n $origin ]] && bin=$root/bin ;;
        esac
    fi

    # Remove only the entry this hook added, leaving the rest of PATH in order.
    if [[ -n ${_dotfiles_worktree_bin_added-} ]]; then
        rest="$PATH:"
        while [[ -n $rest ]]; do
            entry=${rest%%:*}
            rest=${rest#*:}
            [[ $entry == "$_dotfiles_worktree_bin_added" ]] || kept="$kept:$entry"
        done
        PATH=${kept#:}
        _dotfiles_worktree_bin_added=
    fi
    # A main checkout whose bin/ is already on PATH needs nothing.
    if [[ -n $bin && ":$PATH:" != *":$bin:"* ]]; then
        path_prepend "$bin"
        _dotfiles_worktree_bin_added=$bin
    fi
    return $ret
}

if [[ -n ${ZSH_VERSION:-} ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook chpwd _dotfiles_worktree_bin_update
elif [[ ";${PROMPT_COMMAND:-};" != *";_dotfiles_worktree_bin_update;"* ]]; then
    PROMPT_COMMAND="_dotfiles_worktree_bin_update${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi
# Re-sourcing (sr) reruns path.sh, so reapply even if PWD is unchanged.
_dotfiles_worktree_bin_pwd=
_dotfiles_worktree_bin_update
