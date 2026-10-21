#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
SOCKET="$TMP/s"
trap 'tmux -S "$SOCKET" kill-server 2> /dev/null || true; rm -rf "$TMP"' EXIT

# Route every tmux call, including those from the scripts, to a private server.
mkdir "$TMP/bin"
printf '#!/bin/sh\nexec %s -S %s "$@"\n' "$(command -v tmux)" "$SOCKET" > "$TMP/bin/tmux"
chmod +x "$TMP/bin/tmux"
export PATH="$TMP/bin:$PATH" HOME="$TMP" DOTPATH="$ROOT"
unset TMUX
# Stand in for the generated theme, which defines the global foreground.
printf 'set -g base-index 1\nsetw -g pane-base-index 1\nset -g @color_fg "#ffffff"\n' > "$TMP/tmux.conf"

tmux -f "$TMP/tmux.conf" new-session -d -s colored
tmux new-session -d -s plain
option() { tmux show-options -qv -t "$1" "$2"; }

# tcolor -t targets a session from outside tmux and records its variant.
bash "$ROOT/bin/tcolor" -t colored violet
[[ $(option colored @color_variant) == violet ]]
expected_bg=$(option colored @color_bg)
[[ -n $expected_bg ]]

bash "$ROOT/bin/tmux-bin/tsave" colored > /dev/null
bash "$ROOT/bin/tmux-bin/tsave" plain > /dev/null
[[ $(jq -r .color "$TMP/.local/state/tmux/sessions/colored.json") == violet ]]
[[ $(jq -r .color "$TMP/.local/state/tmux/sessions/plain.json") == null ]]

# Restoring recreates the session and reapplies the saved variant.
tmux set-option -u -t colored @color_variant
tmux set-option -u -t colored @color_bg
python3 "$ROOT/bin/tmux-bin/tmux-session" apply colored
[[ $(option colored @color_variant) == violet ]]
[[ $(option colored @color_bg) == "$expected_bg" ]]

python3 "$ROOT/bin/tmux-bin/tmux-session" apply plain
[[ -z $(option plain @color_variant) && -z $(option plain @color_bg) ]]

# default clears the recorded variant.
bash "$ROOT/bin/tcolor" -t colored default
[[ -z $(option colored @color_variant) ]]

echo 'PASS: tsave saves the tcolor variant and tload reapplies it'
