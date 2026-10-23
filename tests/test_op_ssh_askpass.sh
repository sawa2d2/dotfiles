#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ASKPASS="$ROOT/bin/secret/op-ssh-askpass"

# Stub op: log each call; OP_FAIL makes it fail like a locked 1Password.
mkdir -p "$TMP/bin" "$TMP/home/.config/secret"
cat > "$TMP/bin/op" << 'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$OP_LOG"
[ -z "${OP_FAIL:-}" ] || exit 1
[ "$1" = read ] && printf 'secret-for:%s\n' "$2"
EOF
chmod +x "$TMP/bin/op"
export PATH="$TMP/bin:$PATH" HOME="$TMP/home" OP_LOG="$TMP/op.log" TMPDIR="$TMP"
cat > "$HOME/.config/secret/ssh-passwords.conf" << 'EOF'
# host as shown in the password prompt = 1Password secret reference
host1=op://SSH/host1/password
admin@host1=op://SSH/host1-admin/password
EOF

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "${out:-}" >&2
  exit 1
}
# Run without a controlling terminal, as when nothing can be typed.
no_tty() { setsid -w "$@" < /dev/null; }
# Run with a terminal that receives $1 as typed input.
with_tty() {
  local input=$1
  shift
  printf '%s\n' "$input" | script -qec "$(printf '%q ' "$@")" /dev/null
}

# Password prompts for mapped hosts are answered from 1Password.
out=$(no_tty "$ASKPASS" "dev@host1's password: ")
[[ $out == 'secret-for:op://SSH/host1/password' ]] || fail 'password prompt'
out=$(no_tty "$ASKPASS" "admin@host1's password: ")
[[ $out == 'secret-for:op://SSH/host1-admin/password' ]] || fail 'user@host wins over host'
out=$(no_tty "$ASKPASS" '(dev@host1) Password: ')
[[ $out == 'secret-for:op://SSH/host1/password' ]] || fail 'keyboard-interactive prompt'

# Server text cannot pose as another host behind the client's prefix.
: > "$OP_LOG"
status=0
out=$(no_tty "$ASKPASS" '(dev@evil) (dev@host1) Password: ') || status=$?
((status == 1)) && [[ ! -s $OP_LOG ]] || fail 'spoofed keyboard-interactive prompt'

# A rejected password is not resent: within one ssh process (the parent),
# 1Password answers only the first prompt and the rest go to the terminal.
cat > "$TMP/bin/twice" << 'EOF'
#!/bin/sh
"$1" "$2"; echo "status=$?"
"$1" "$2"; echo "status=$?"
EOF
chmod +x "$TMP/bin/twice"
: > "$OP_LOG"
out=$(no_tty twice "$ASKPASS" "dev@host1's password: ")
[[ $out == $'secret-for:op://SSH/host1/password\nstatus=0\nstatus=1' ]] || fail 'second prompt without a terminal'
[[ $(wc -l < "$OP_LOG") == 1 ]] || fail '1Password read only once'
out=$(with_tty typed twice "$ASKPASS" "dev@host1's password: ")
[[ $out == *secret-for:op://SSH/host1/password*rejected*typed* ]] || fail 'second prompt asked on the terminal'

# Records of finished ssh processes are cleaned up.
true &
dead=$!
wait "$dead"
touch "$TMP/op-ssh-askpass-$(id -u)/$dead"
no_tty "$ASKPASS" "dev@host1's password: " > /dev/null
[[ ! -e $TMP/op-ssh-askpass-$(id -u)/$dead ]] || fail 'stale record removed'
: > "$OP_LOG"

# Unmapped hosts and other prompts never reach 1Password; with no terminal
# to ask, they fail like ssh would.
for prompt in "dev@other's password: " "Enter passphrase for key '/k': "; do
  status=0
  out=$(no_tty "$ASKPASS" "$prompt") || status=$?
  ((status == 1)) && [[ ! -s $OP_LOG ]] || fail "unmapped: $prompt"
done

# Everything else is asked on the terminal: hidden for secrets, visible for
# yes/no questions, and confirmations answer through the exit status.
out=$(with_tty typed "$ASKPASS" "dev@other's password: ")
[[ $out == *typed* ]] || fail 'terminal fallback'
out=$(with_tty yes "$ASKPASS" 'Are you sure you want to continue connecting (yes/no/[fingerprint])? ')
[[ $(grep -c yes <<< "$out") == 2 ]] || fail 'yes/no echoes the answer'
SSH_ASKPASS_PROMPT=confirm with_tty y "$ASKPASS" 'Allow use of key?' > /dev/null || fail 'confirm yes'
if SSH_ASKPASS_PROMPT=confirm with_tty n "$ASKPASS" 'Allow use of key?' > /dev/null; then
  fail 'confirm no'
fi

# A locked or failing 1Password falls back to typing the password.
out=$(OP_FAIL=1 with_tty typed "$ASKPASS" "dev@host1's password: ")
[[ $out == *typed* ]] || fail 'op failure falls back to the terminal'

# Without the mapping file nothing is looked up.
rm "$HOME/.config/secret/ssh-passwords.conf"
: > "$OP_LOG"
status=0
out=$(no_tty "$ASKPASS" "dev@host1's password: ") || status=$?
((status == 1)) && [[ ! -s $OP_LOG ]] || fail 'no mapping file'

# The shell hook enables it only when the mapping file exists.
env_after_hook() {
  # shellcheck disable=SC2016 # expanded by the inner bash
  env -u SSH_ASKPASS -u SSH_ASKPASS_REQUIRE DOTPATH="$ROOT" HOME="$HOME" \
    bash -c 'source "$DOTPATH/home/.shell.d/ssh.sh"; echo "${SSH_ASKPASS:-}|${SSH_ASKPASS_REQUIRE:-}"'
}
[[ $(env_after_hook) == '|' ]] || fail 'hook without mapping file'
touch "$HOME/.config/secret/ssh-passwords.conf"
[[ $(env_after_hook) == "$ASKPASS|force" ]] || fail 'hook with mapping file'

echo 'PASS: op-ssh-askpass answers mapped password prompts and asks for the rest'
