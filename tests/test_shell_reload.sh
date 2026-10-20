#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mkdir -p "$TMP/bin"
printf '#!/bin/sh\n' > "$TMP/bin/fzf"
chmod +x "$TMP/bin/fzf"
export PATH="$TMP/bin:/usr/bin:/bin"

# Re-sourcing fzf setup must not keep appending the same defaults.
for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || continue
  [[ $shell == bash ]] && file="$ROOT/home/.bash.d/zz-fzf.bash" || file="$ROOT/home/.zsh.d/zz-fzf.zsh"
  [[ $shell == bash ]] && flags=(--norc) || flags=(-f)
  # bind/zle/bindkey are interactive-only; stub them for this check.
  output=$(env -u FZF_DEFAULT_OPTS DOTPATH="$ROOT" "$shell" "${flags[@]}" -c "
    bind() { :; }; zle() { :; }; bindkey() { :; }
    source '$file'; first=\$FZF_DEFAULT_OPTS
    source '$file'; [ \"\$first\" = \"\$FZF_DEFAULT_OPTS\" ] && echo same || echo \"grew: \$FZF_DEFAULT_OPTS\"")
  [[ $output == same ]] || fail "$shell fzf defaults: $output"
done

# Re-sourcing .zshrc (sr) must load Zsh plugins only once per shell.
if command -v zsh > /dev/null 2>&1; then
  home="$TMP/home"
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    mkdir -p "$home/.local/share/zsh/plugins/$plugin"
    printf '(( ++plugin_loads ))\n' > "$home/.local/share/zsh/plugins/$plugin/$plugin.zsh"
  done
  output=$(HOME="$home" zsh -f -i -c "
    plugin_loads=0
    for i in 1 2 3; do source '$ROOT/home/.zshrc'; done 2> /dev/null
    print \$plugin_loads" < /dev/null 2> /dev/null)
  [[ $output == 2 ]] || fail "zsh plugins loaded $output times across three sources (expected 2)"
fi

echo 'PASS: shell reloads do not repeat fzf defaults or Zsh plugin loading'
