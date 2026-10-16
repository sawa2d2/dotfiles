# System-wide deployment of bin/, sourced by ./install --system.
# Helper functions use Bash's dynamic scoping to access install_system_bin locals.
_validate_system_bin() {
    [[ -d "$src" ]] || { echo "Missing bin directory: $src" >&2; return 1; }
    if [[ -n $(find "$src" -type l -print -quit) ]]; then
        echo "Refusing symlinks within bin/ for system installation" >&2
        return 1
    fi

    # Avoid taking over an unrelated installation or configuration.
    if [[ -e $root && ! -f $root/.dotfiles-bin-managed ]]; then
        echo "Unmanaged destination exists: $root" >&2
        return 1
    fi
    if [[ -e $profile ]] && ! grep -q '^# Managed by dotfiles install-dotfiles-bin.sh$' "$profile"; then
        echo "Unmanaged profile exists: $profile" >&2
        return 1
    fi

    # sudo uses secure_path instead of shell startup files.
    # Preserve its current effective value, appending only root-owned directories.
    if ! command -v visudo >/dev/null 2>&1; then
        echo "visudo is required for sudo command support" >&2
        return 1
    fi
    if [[ -e $sudoers ]] && ! grep -qx '# Managed by dotfiles install-dotfiles-bin.sh' "$sudoers"; then
        echo "Unmanaged sudoers file exists: $sudoers" >&2
        return 1
    fi
    secure_path=$(LC_ALL=C sudo -V | awk '/^Value to override/ { sub(/^[^:]*: /, ""); print; exit }')
    if [[ -z $secure_path ]]; then
        echo "Cannot determine sudo secure_path; refusing to replace sudoers settings" >&2
        return 1
    fi
    # Identify all immediate child directories, matching the profile script.
    candidate="$secure_path"
    for dir in "$root" "$src"/*/; do
        if [[ $dir == "$root" ]]; then
            :
        else
            dir="${dir%/}"
            dir="$root/${dir##*/}"
        fi
        dir="${dir%/}"
        case ":$candidate:" in
            *":$dir:"*) ;;
            *) candidate="$candidate:$dir" ;;
        esac
    done
}

_deploy_system_bin() {
    mkdir -p "$parent"
    stage=$(mktemp -d "$parent/.dotfiles-bin-stage.XXXXXXXX")
    if ! cp -a "$src/." "$stage/"; then
        rm -rf -- "$stage"
        return 1
    fi
    chown -R root:root "$stage"
    chmod -R go-w "$stage"
    touch "$stage/.dotfiles-bin-managed"
    chmod 644 "$stage/.dotfiles-bin-managed"

    backup=""
    if [[ -d $root ]]; then
        backup=$(mktemp -d "$parent/.dotfiles-bin-backup.XXXXXXXX")
        rmdir "$backup"
        mv -- "$root" "$backup"
    fi
    if ! mv -- "$stage" "$root"; then
        if [[ -n $backup ]]; then mv -- "$backup" "$root"; fi
        return 1
    fi
}

_configure_system_profile() {
    cat > "$profile" <<'PROFILE'
# Managed by dotfiles install-dotfiles-bin.sh
# Loaded by login shells that source /etc/profile.d/*.sh.
_dotfiles_bin_root=/usr/local/lib/dotfiles-bin
for _dotfiles_bin_dir in "$_dotfiles_bin_root" "$_dotfiles_bin_root"/*/; do
    [ -d "$_dotfiles_bin_dir" ] || continue
    _dotfiles_bin_dir=${_dotfiles_bin_dir%/}
    case ":$PATH:" in
        *":$_dotfiles_bin_dir:"*) ;;
        *) PATH="$PATH:$_dotfiles_bin_dir" ;;
    esac
done
export PATH
unset _dotfiles_bin_dir _dotfiles_bin_root
PROFILE
    chmod 644 "$profile"
}

_configure_system_sudo() {
    local sudoers_stage
    sudoers_stage=$(mktemp /etc/sudoers.d/.dotfiles-bin.XXXXXXXX)
    printf '%s\n' "$sudoers_content" > "$sudoers_stage"
    chmod 440 "$sudoers_stage"
    if ! visudo -cf "$sudoers_stage" >/dev/null; then
        rm -f -- "$sudoers_stage"
        echo "sudoers validation failed; retaining previous configuration" >&2
        return 1
    fi
    mv -f -- "$sudoers_stage" "$sudoers"
}

install_system_bin() {
    local dry_run=0
    if [[ ${1:-} == --dry-run && $# -eq 1 ]]; then
        dry_run=1
    elif (( $# != 0 )); then
        echo "Usage: sudo ./install --system [--dry-run]" >&2
        return 2
    fi
    if (( ! dry_run && EUID != 0 )); then
        echo "System installation requires root: sudo ./install --system" >&2
        return 1
    fi

    local root=/usr/local/lib/dotfiles-bin
    local profile=/etc/profile.d/dotfiles-bin.sh
    local sudoers=/etc/sudoers.d/dotfiles-bin
    local src="$DOTPATH/bin"
    local secure_path candidate dir sudoers_content
    local parent=/usr/local/lib stage backup sudoers_stage

    _validate_system_bin || return $?
    sudoers_content=$(printf '# Managed by dotfiles install-dotfiles-bin.sh\nDefaults secure_path="%s"\n' "$candidate")

    echo "Copy $src -> $root (preserving directories)"
    echo "Configure PATH in $profile and sudo secure_path in $sudoers"
    if (( dry_run )); then
        echo "(dry-run; no changes)"
        return 0
    fi

    _deploy_system_bin
    _configure_system_profile
    _configure_system_sudo
    if [[ -n $backup ]]; then rm -rf -- "$backup"; fi
    echo "System commands installed. Start a new login shell to load PATH."
}
