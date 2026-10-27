# Shared editor preference.
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
elif command -v vim >/dev/null 2>&1; then
    export EDITOR=vim
else
    export EDITOR=vi
fi

# sudoedit and visudo run the editor as root, whose PATH lacks per-user
# installs (e.g. Nix), so give them its absolute path.
if SUDO_EDITOR=$(command -v "$EDITOR" 2>/dev/null); then
    export SUDO_EDITOR
else
    unset SUDO_EDITOR
fi

# sudo drops SUDO_EDITOR from the environment; pass it on the command line.
visudo() {
    command sudo ${SUDO_EDITOR:+SUDO_EDITOR="$SUDO_EDITOR"} visudo "$@"
}
