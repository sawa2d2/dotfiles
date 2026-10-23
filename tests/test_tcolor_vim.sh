#!/usr/bin/env bash
# shellcheck disable=SC2016 # Vim expressions are expanded by Vim
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
SOCKET="$TMP/s"
trap 'tmux -S "$SOCKET" kill-server 2> /dev/null || true; rm -rf "$TMP"' EXIT

# Route every tmux call, including Vim's, to a private server.
mkdir -p "$TMP/bin" "$TMP/dotfiles/theme"
printf '#!/bin/sh\nexec %s -S %s "$@"\n' "$(command -v tmux)" "$SOCKET" > "$TMP/bin/tmux"
chmod +x "$TMP/bin/tmux"
export PATH="$TMP/bin:$PATH" HOME="$TMP" DOTPATH="$ROOT" XDG_CONFIG_HOME="$TMP/.config"
unset TMUX TMUX_PANE

# .vimrc reads the generated theme from ~/dotfiles; generate it there (violet).
cp "$ROOT/theme/sync" "$ROOT/theme/colors.sh" "$TMP/dotfiles/theme/"
bash "$TMP/dotfiles/theme/sync" violet > /dev/null
tmux -f "$TMP/dotfiles/theme/generated/tmux.theme.conf" new-session -d -s plain
tmux new-session -d -s colored
bash "$ROOT/bin/tcolor" -t colored orange > /dev/null

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "${out:-}" >&2
  exit 1
}
# Print the Visual and DotStatusMode backgrounds Vim ends up with in the
# session's pane; extra Ex commands ($2...) run before printing.
colors_in() {
  local pane editor=${EDITOR_CMD:-vim}
  pane=$(tmux display-message -p -t "$1" '#{pane_id}')
  shift
  local args=()
  for cmd in "$@"; do args+=(-c "$cmd"); done
  TMUX_PANE=$pane run_editor "$editor" "${args[@]}" \
    -c 'call writefile([synIDattr(hlID("Visual"), "bg#", "gui") . " " . synIDattr(hlID("DotStatusMode"), "bg#", "gui")], $OUT)'
}
# Run headless with the repo's .vimrc and print what it wrote to $OUT.
run_editor() {
  local editor=$1
  shift
  rm -f "$TMP/out"
  OUT="$TMP/out" "$editor" -Nu "$ROOT/home/.vimrc" -i NONE -es "$@" -c 'qa!' < /dev/null > /dev/null 2>&1 || true
  cat "$TMP/out" 2> /dev/null
}

for EDITOR_CMD in vim nvim; do
  command -v "$EDITOR_CMD" > /dev/null || continue
  export EDITOR_CMD
  # A session without tcolor keeps the global theme.
  out=$(colors_in plain)
  [[ $out == '#b1a5e5 #9180d8' ]] || fail "$EDITOR_CMD: global colors"
  # A tcolor session is followed at startup.
  out=$(colors_in colored)
  [[ $out == '#e9b888 #d98d50' ]] || fail "$EDITOR_CMD: session colors at startup"
  # A later tcolor is picked up when the pane regains focus.
  out=$(colors_in colored 'call system("tmux set-option -t colored @color_accent \"#24a86a\"; tmux set-option -t colored @color_selected \"#82cfaa\"")' 'doautocmd FocusGained')
  [[ $out == '#82cfaa #24a86a' ]] || fail "$EDITOR_CMD: session colors on focus"
  bash "$ROOT/bin/tcolor" -t colored orange > /dev/null
done

# Outside tmux nothing is queried.
out=$(run_editor vim -c 'call writefile([synIDattr(hlID("DotStatusMode"), "bg#", "gui")], $OUT)')
[[ $out == '#9180d8' ]] || fail 'outside tmux'

echo 'PASS: Vim and Neovim follow the tmux session color set by tcolor'
