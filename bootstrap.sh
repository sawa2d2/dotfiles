#!/usr/bin/env bash
set -euo pipefail

REPO=https://github.com/sawa2d2/dotfiles.git
DEST=${DOTFILES_DIR:-"$HOME/dotfiles"}

command -v git >/dev/null 2>&1 || {
    echo "git is required" >&2
    exit 1
}

if [[ -d "$DEST/.git" ]]; then
    echo "Using existing checkout: $DEST"
elif [[ -e "$DEST" || -L "$DEST" ]]; then
    echo "Destination exists and is not a Git checkout: $DEST" >&2
    exit 1
else
    git clone "$REPO" "$DEST"
fi

cd "$DEST"
./install
