#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
SOCKET="$TMP/s"
trap 'tmux -S "$SOCKET" kill-server 2> /dev/null || true; rm -rf "$TMP"' EXIT
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Route every tmux call, including those from the scripts, to a private server
# that loads the real configuration through the installed symlink.
mkdir "$TMP/bin"
printf '#!/bin/sh\nexec %s -S %s "$@"\n' "$(command -v tmux)" "$SOCKET" > "$TMP/bin/tmux"
chmod +x "$TMP/bin/tmux"
export PATH="$TMP/bin:$PATH" HOME="$TMP"
unset TMUX
ln -s "$ROOT/home/.tmux.conf" "$TMP/.tmux.conf"
tmux -f "$TMP/.tmux.conf" new-session -d -s test -x 120 -y 20 -n alpha
tmux new-window -d -t test: -n beta
tmux new-window -d -t test: -n gamma
session=$(tmux display-message -p -t test '#{session_id}')
mark() { tmux set-option -w -t "test:$1" @agent_status "$2" \; set-option -w -t "test:$1" @agent_attention "$3"; }
status_of() { tmux show-options -wqv -t "test:$1" @agent_status; }
render() { bash "$ROOT/bin/tmux-bin/tmux-status-windows" 0 "$session" 120; }
selected=$(tmux show-options -gqv @color_selected)
[[ -n $selected ]] || fail 'no selection color'

# A window whose agent needs the user is drawn on the selection color, bold; the label
# and therefore the wrapping stay unchanged.
before=$(render)
mark 2 'done' 1
row=$(render)
[[ $row == *",bg=$selected,bold] 2:beta "* ]] || fail "attention: $row"
others=${row/",bg=$selected,"/}
[[ $others != *"bg=$selected,"* ]] || fail "others: $row"
tmux set-option -wu -t test:2 @agent_attention
[[ $(render) == "$before" ]] || fail 'attention kept after unset'

# agent-config runs @agent_status_hook after each change: it must re-sync the rows.
hook=$(tmux show-options -gqv @agent_status_hook)
[[ $hook == *'/bin/tmux-bin/tmux-status-windows --sync' ]] || fail "hook: $hook"
tmux run-shell "$hook" || fail 'hook failed'

# Selecting a window acknowledges its notification, whatever the state, and
# only there; the detailed state stays.
mark 2 'done' 1
mark 3 waiting 1
tmux select-window -t test:2
sleep 0.3
[[ -z $(tmux show-options -wqv -t test:2 @agent_attention) && $(status_of 2) == 'done' ]] || fail 'done not acknowledged'
[[ $(tmux show-options -wqv -t test:3 @agent_attention) == 1 ]] || fail 'other window cleared'
tmux select-window -t test:3
sleep 0.3
[[ -z $(tmux show-options -wqv -t test:3 @agent_attention) && $(status_of 3) == waiting ]] || fail 'waiting not acknowledged'

echo 'PASS: tmux agent status'
