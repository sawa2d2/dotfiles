# Load a 1Password secret into the current Bash/Zsh shell.
# ~/.config/secret/secrets.conf: KEY=op://Vault/Item/field (one per line)
# Example: GH_TOKEN=op://Private/GitHub/token
# Usage: load-secret [ENV_NAME] (no arguments: list available names)
# Cache: 30 minutes; already exported variables remain until unset/shell exit.
load-secret() {
    [[ $# -le 1 ]] || { printf 'Usage: load-secret [ENV_NAME]\n' >&2; return 2; }

    local name=${1:-} ref='' key value line root file hash mtime now tmp
    local config="$HOME/.config/secret/secrets.conf"
    [[ -r $config ]] || { printf 'load-secret: cannot read %s\n' "$config" >&2; return 1; }
    if [[ -z $name ]]; then
        while IFS='=' read -r key value || [[ -n $key ]]; do
            [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ && $value == op://* ]] &&
                printf '%s\n' "$key"
        done < "$config"
        return 0
    fi
    [[ $name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
        printf 'Usage: load-secret [ENV_NAME]\n' >&2
        return 2
    }

    while IFS='=' read -r key value || [[ -n $key ]]; do
        if [[ $key == "$name" ]]; then
            ref=$value
            break
        fi
    done < "$config"
    [[ $ref == op://* ]] || { printf 'load-secret: no reference for %s\n' "$name" >&2; return 1; }

    root="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    [[ -d $root ]] || root=${TMPDIR:-}
    [[ $root == /* && -d $root ]] || { printf 'load-secret: no runtime directory\n' >&2; return 1; }
    root="$root/secret-cache"
    [[ ! -L $root ]] || return 1
    (umask 077; mkdir -p -- "$root") || return 1
    # No "--": BSD chmod (macOS) takes it as a file name after the mode. The
    # absolute path above cannot be mistaken for an option.
    chmod 700 "$root" || return 1

    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(printf '%s' "$ref" | sha256sum) || return 1
    else
        hash=$(printf '%s' "$ref" | shasum -a 256) || return 1
    fi
    file="$root/$name-${hash%% *}"
    now=$(date +%s) || return 1
    if [[ -f $file && ! -L $file ]]; then
        mtime=$(stat -c %Y "$file" 2>/dev/null) ||
            mtime=$(stat -f %m "$file" 2>/dev/null) || return 1
        if (( now >= mtime && now - mtime < 1800 )); then
            value=$(cat -- "$file") || return 1
            export "$name=$value"
            return
        fi
    fi

    command -v op >/dev/null 2>&1 || { printf 'load-secret: op not installed\n' >&2; return 1; }
    value=$(op read "$ref") || return 1
    [[ -n $value ]] || return 1
    tmp=$(umask 077; mktemp "$root/.secret.XXXXXXXX") || return 1
    if ! printf '%s' "$value" > "$tmp" || ! mv -f -- "$tmp" "$file"; then
        rm -f -- "$tmp"
        return 1
    fi
    export "$name=$value"
}
