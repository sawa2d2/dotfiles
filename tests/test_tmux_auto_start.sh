#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
SOCKET="$TMP/s"
trap 'tmux -S "$SOCKET" kill-server 2> /dev/null || true; rm -rf "$TMP"' EXIT

# Route tmux to a private server; attach/new are only logged so the test never
# takes over a terminal.
REAL_TMUX=$(command -v tmux)
mkdir "$TMP/bin"
cat > "$TMP/bin/tmux" << WRAP
#!/bin/sh
case " \$* " in
  *" attach-session "*|*" new-session "*) [ -z "\${LOG_ONLY:-}" ] || { echo "\$*" >> "$TMP/log"; exit 0; } ;;
esac
exec "$REAL_TMUX" -S "$SOCKET" "\$@"
WRAP
chmod +x "$TMP/bin/tmux"
export PATH="$TMP/bin:$PATH"
unset TMUX

fail() {
  printf 'FAIL: %s\n--- log ---\n%s\n' "$1" "$(cat "$TMP/log" 2> /dev/null)" >&2
  exit 1
}
# Run the startup hook in $1 (bash or zsh) with a terminal, logging what it starts.
auto_start() {
  rm -f "$TMP/log"
  (cd "${START_DIR:-$HOME}" && LOG_ONLY=1 script -qec "$1 -c 'source \"$ROOT/home/.shell.d/tmux.sh\"; dotfiles_tmux_auto_start'" /dev/null < /dev/null > /dev/null)
  cat "$TMP/log" 2> /dev/null
}
id_of() { tmux display-message -p -t "$1" '#{session_id}'; }

for sh in bash zsh; do
  command -v "$sh" > /dev/null || continue
  tmux kill-server 2> /dev/null || true
  # No server yet: a new session is created.
  [[ $(auto_start "$sh") == '-u new-session' ]] || fail "$sh: no sessions"

  # An unattached session is reused; the most recently active one wins.
  tmux new-session -d -s old
  sleep 1.1
  tmux new-session -d -s recent
  # It gets a new window in the directory the terminal opened in.
  id=$(id_of recent)
  [[ $(auto_start "$sh") == "-u new-window -t $id: -c $HOME ; attach-session -t $id" ]] || fail "$sh: reuse newest unattached"
  [[ $(START_DIR=$TMP auto_start "$sh") == "-u new-window -t $id: -c $TMP ; attach-session -t $id" ]] || fail "$sh: opened in a folder"

  # Sessions with a client attached are left alone.
  tmux kill-session -t old
  script -qec "tmux attach-session -t recent" /dev/null < <(sleep 5) > /dev/null 2>&1 &
  for _ in $(seq 50); do
    [[ $(tmux display-message -p -t recent '#{session_attached}') == 1 ]] && break
    sleep 0.1
  done
  [[ $(auto_start "$sh") == '-u new-session' ]] || fail "$sh: attached session kept"
  tmux kill-server 2> /dev/null || true
  wait
done

# Inside tmux nothing starts.
rm -f "$TMP/log"
TMUX=x LOG_ONLY=1 script -qec "bash -c 'source \"$ROOT/home/.shell.d/tmux.sh\"; dotfiles_tmux_auto_start'" /dev/null < /dev/null > /dev/null
[[ ! -s $TMP/log ]] || fail 'inside tmux'

echo 'PASS: tmux auto-start opens a window in an unattached session before creating one'
