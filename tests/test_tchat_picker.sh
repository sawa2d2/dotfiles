#!/usr/bin/env bash
# shellcheck disable=SC2016 # wait_for conditions are expanded by eval
# End to end: `tchat once` with no panes shows tmux's pane numbers twice
# (source, then destination) and forwards between the chosen panes.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
SOCKET="$TMP/s"
trap 'exec 7>&- 2> /dev/null; tmux -S "$SOCKET" kill-server 2> /dev/null || true; rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# Route every tmux call, including tchat's callbacks, to a private server.
mkdir "$TMP/bin"
printf '#!/bin/sh\nexec %s -S %s "$@"\n' "$(command -v tmux)" "$SOCKET" > "$TMP/bin/tmux"
chmod +x "$TMP/bin/tmux"
export PATH="$TMP/bin:$PATH" XDG_RUNTIME_DIR="$TMP"
unset TMUX TMUX_PANE

tmux -f /dev/null new-session -d -x 100 -y 30 -s t 'printf "hello from A\n"; exec sh'
tmux split-window -t t 'cat'
tmux split-window -t t 'sh'

# display-panes needs an attached client; keys written to the fifo reach it.
mkfifo "$TMP/keys"
setsid script -qfc "env TERM=xterm-256color $TMP/bin/tmux attach -t t" /dev/null \
  < "$TMP/keys" > /dev/null 2>&1 &
exec 7> "$TMP/keys"
for _ in $(seq 50); do
  [[ -n $(tmux list-clients) ]] && break
  sleep 0.1
done
[[ -n $(tmux list-clients) ]] || fail 'client did not attach'

wait_for() {
  for _ in $(seq 50); do
    eval "$1" && return 0
    sleep 0.1
  done
  return 1
}
state() { cat "$TMP"/dotfiles-tchat/pick-* 2> /dev/null; }

tmux send-keys -t t.2 "$ROOT/bin/tmux-bin/tchat once" Enter
wait_for '[[ $(state | wc -l) == 2 ]]' || fail 'source picker not shown'
printf 0 >&7
wait_for '[[ $(state | sed -n 3p) == %0 ]]' || fail 'source pane not recorded'
printf 1 >&7
wait_for 'tmux capture-pane -p -t t.1 | grep -q "hello from A"' || fail 'not forwarded to the destination'
tmux capture-pane -p -t t.1 | grep -q 'forwarded from tmux pane %0' || fail 'missing source header'
[[ -z $(state) ]] || fail 'picker state left behind'

echo 'PASS: tchat picks source and destination panes with display-panes'
