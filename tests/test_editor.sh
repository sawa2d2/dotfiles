#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Stub nvim and a sudo that prints the command and editor it was given.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\n' > "$TMP/bin/nvim"
cat > "$TMP/bin/sudo" << 'STUB'
#!/bin/sh
printf '%s\n' "$*"
STUB
chmod +x "$TMP/bin/nvim" "$TMP/bin/sudo"

for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || continue
  [[ $shell == bash ]] && flags=(--norc) || flags=(-f)
  # sudo resets the environment and root's PATH lacks per-user installs
  # (e.g. Nix), so visudo gets the editor's absolute path on the command line.
  out=$(env -u SUDO_EDITOR PATH="$TMP/bin:/usr/bin:/bin" "$shell" "${flags[@]}" -c "
    source '$ROOT/home/.shell.d/editor.sh'
    echo \"\$EDITOR|\$SUDO_EDITOR\"
    visudo -f /etc/sudoers.d/x")
  [[ $out == "nvim|$TMP/bin/nvim"$'\n'"SUDO_EDITOR=$TMP/bin/nvim visudo -f /etc/sudoers.d/x" ]] ||
    fail "$shell: $out"
done

echo 'PASS: visudo and sudoedit use the preferred editor'
