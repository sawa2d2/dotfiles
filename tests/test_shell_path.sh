#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
dotpath="$tmp/dotfiles"
# Like the repo, bin/ has a subdirectory (an unmatched bin/*/ glob errors under zsh nomatch).
mkdir -p "$home/.local/bin" "$home/bin" "$home/.nix-profile/bin" "$dotpath/bin/sub"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run() {
  local shell=$1 path=$2
  env -i HOME="$home" DOTPATH="$dotpath" PATH="$path" "$shell" -c "source '$root/home/.shell.d/path.sh'; printf '%s' \"\$PATH\""
}

expected="$dotpath/bin:$dotpath/bin/sub:$home/.nix-profile/bin:$home/.local/bin:$home/bin:/usr/bin:/bin"
for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || {
    echo "SKIP: $shell not installed"
    continue
  }

  # Non-login start: ~/.profile has not added the per-user bins.
  out=$(run "$shell" /usr/bin:/bin)
  [[ $out == "$expected" ]] || fail "$shell non-login: $out"

  # Login start: ~/.profile already added them; no duplicates remain.
  out=$(run "$shell" "$home/.local/bin:$home/bin:/usr/bin:/bin")
  [[ $out == "$expected" ]] || fail "$shell login: $out"
done

# Missing per-user bins are not added.
rmdir "$home/bin"
out=$(run bash /usr/bin:/bin)
[[ $out == "$dotpath/bin:$dotpath/bin/sub:$home/.nix-profile/bin:$home/.local/bin:/usr/bin:/bin" ]] || fail "missing ~/bin: $out"

echo 'PASS: per-user bins are on PATH once in non-login and login shells'
