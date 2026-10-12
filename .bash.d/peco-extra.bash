# Select a directory from bookmarks, local directories, zoxide and ghq
peco_change_directory() {
    local selected

    selected=$(
        {
            printf '%s\n' \
                "$HOME/Documents" \
                "$HOME/Desktop" \
                "$HOME/.config"

            find "$PWD" -mindepth 1 -maxdepth 1 \
                -type d ! -name '.*' -print 2>/dev/null

            command -v zoxide >/dev/null &&
                zoxide query --list 2>/dev/null

            command -v ghq >/dev/null &&
                ghq list -p 2>/dev/null
        } |
        awk '!seen[$0]++' |
        peco --query "${READLINE_LINE:-}"
    ) || return

    [[ -d "$selected" ]] || return
    cd -- "$selected" || return

    READLINE_LINE=
    READLINE_POINT=0
}

# Select a GitHub Gist and insert its content into the command line
peco_gists() {
    local selected gist_id filename content

    command -v gh >/dev/null || {
        echo "gh is not installed" >&2
        return 1
    }

    selected=$(
        gh api --paginate gists \
            --jq '.[] | [.id, (.description // ""), (.files | keys | join(", "))] | @tsv' |
        peco --prompt '[ SELECT GIST ] >'
    ) || return

    [[ -n "$selected" ]] || return
    gist_id=${selected%%$'\t'*}

    filename=$(
        gh gist view "$gist_id" --files |
        peco --prompt '[ SELECT FILE ] >'
    ) || return

    [[ -n "$filename" ]] || return

    content=$(gh gist view "$gist_id" \
        --filename "$filename" --raw) || return

    READLINE_LINE=$content
    READLINE_POINT=${#READLINE_LINE}
}

# ble.sh / Bash Readline key bindings
if [[ -n ${BLE_VERSION:-} ]]; then
    ble-bind -x 'C-]' peco_change_directory
    ble-bind -x 'M-g' peco_gists
else
    bind -x '"\C-]": peco_change_directory'
    bind -x '"\eg": peco_gists'
fi