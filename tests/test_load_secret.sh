#!/usr/bin/env bash
# shellcheck disable=SC2016 # expanded by the inner shell
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Stub op, plus a chmod that rejects "--" after the mode like macOS (BSD) does.
REAL_CHMOD=$(command -v chmod)
mkdir -p "$TMP/bin" "$TMP/home/.config/secret" "$TMP/run"
cat > "$TMP/bin/op" << 'STUB'
#!/bin/sh
echo "$1" >> "$OP_LOG"
# OP_SIGNED_OUT: every command fails as when no session exists, until the
# shell evaluates what signin prints for the password "pw" read from stdin.
# OP_BAD_REF: only read fails, as for a wrong reference.
if [ "$1" = signin ]; then
  read -r pw && [ "$pw" = pw ] || { echo '[ERROR] authentication failed' >&2; exit 1; }
  echo 'export OP_SESSION_test=token'
  exit 0
fi
[ -z "${OP_SIGNED_OUT:-}" ] || [ -n "${OP_SESSION_test:-}" ] ||
  { echo '[ERROR] You are not currently signed in.' >&2; exit 1; }
[ "$1" = whoami ] && exit 0
[ -z "${OP_BAD_REF:-}" ] || { echo '[ERROR] could not read secret' >&2; exit 1; }
[ "$1" = read ] && printf 'value-of:%s' "$2"
STUB
cat > "$TMP/bin/chmod" << STUB
#!/bin/sh
[ "\$2" != -- ] || { echo "chmod: --: No such file or directory" >&2; exit 1; }
exec "$REAL_CHMOD" "\$@"
STUB
chmod +x "$TMP/bin/op" "$TMP/bin/chmod"
printf 'GH_TOKEN=op://Private/GitHub/token\n' > "$TMP/home/.config/secret/secrets.conf"
export PATH="$TMP/bin:$ROOT/bin/secret:$PATH" HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/run" OP_LOG="$TMP/op.log"

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "${out:-}" >&2
  exit 1
}
for sh in bash zsh; do
  command -v "$sh" > /dev/null || continue
  rm -rf "$TMP/run/secret-cache" "$OP_LOG"
  # stdout is only what the test prints; the function reports on stderr.
  load() { "$sh" -c 'source "$1/home/.shell.d/secret.sh" && load-secret GH_TOKEN && printf "%s" "$GH_TOKEN"' _ "$ROOT" 2> "$TMP/err"; }
  out=$(load) || fail "$sh: load-secret failed"
  [[ $out == 'value-of:op://Private/GitHub/token' ]] || fail "$sh: exported value"
  [[ $(cat "$TMP/err") == 'load-secret: loaded GH_TOKEN' ]] || fail "$sh: success notice: $(cat "$TMP/err")"
  # The second call is served from the private cache without asking 1Password.
  out=$(load) || fail "$sh: cached load failed"
  [[ $out == 'value-of:op://Private/GitHub/token' && $(wc -l < "$OP_LOG") == 1 ]] || fail "$sh: cache"
  [[ -n $(find "$TMP/run/secret-cache" -maxdepth 0 -perm 700) ]] || fail "$sh: cache permissions"
  # -f asks 1Password again even within the cache lifetime and refreshes the cache.
  printf 'stale' > "$(find "$TMP/run/secret-cache" -name 'GH_TOKEN-*')"
  out=$("$sh" -c 'source "$1/home/.shell.d/secret.sh" && load-secret -f GH_TOKEN && printf "%s" "$GH_TOKEN"' _ "$ROOT" 2> "$TMP/err") ||
    fail "$sh: forced load failed"
  [[ $out == 'value-of:op://Private/GitHub/token' && $(grep -c '^read$' "$OP_LOG") == 2 ]] || fail "$sh: -f"
  out=$(load) && [[ $out == 'value-of:op://Private/GitHub/token' ]] || fail "$sh: -f did not refresh the cache"
done

# When signed out, the function signs in on the terminal (stdin) in the
# current shell and retries; the session stays for later op calls.
fresh() {
  rm -rf "$TMP/run/secret-cache" "$OP_LOG"
  "${2:-bash}" -c 'source "$1/home/.shell.d/secret.sh" && load-secret GH_TOKEN && printf "%s|%s" "$GH_TOKEN" "$OP_SESSION_test"' _ "$ROOT" 2>&1
}
for sh in bash zsh; do
  command -v "$sh" > /dev/null || continue
  out=$(printf 'pw\n' | OP_SIGNED_OUT=1 fresh "$sh") || fail "$sh: sign-in and retry"
  [[ $out == *'signing in'*'loaded GH_TOKEN'*'value-of:op://Private/GitHub/token|token' && $out != *'run: eval'* ]] ||
    fail "$sh: sign-in output"
done
status=0
out=$(printf 'wrong\n' | OP_SIGNED_OUT=1 fresh) || status=$?
((status == 3)) && [[ $out == *'sign-in failed'*'failed to load GH_TOKEN'* && $(grep -c '^read$' "$OP_LOG") == 1 ]] ||
  fail 'failed sign-in reported without retry'
# Run directly (e.g. from scripts), the program only explains how to sign in.
status=0
rm -f "$OP_LOG"
out=$(OP_SIGNED_OUT=1 load-secret -f GH_TOKEN 2>&1 < /dev/null) || status=$?
((status == 3)) && [[ $out == *'not signed in'*'eval "$(op signin)"'* && $(grep -c '^signin$' "$OP_LOG") == 0 ]] ||
  fail 'sign-in hint'
status=0
out=$(OP_BAD_REF=1 fresh) || status=$?
((status == 1)) && [[ $out == *'could not read secret'* && $out != *'op signin'* && $out != *'signing in'* ]] ||
  fail 'no sign-in for other failures'

# Listing and direct use of the program (e.g. from scripts) work without the function.
out=$(load-secret) && [[ $out == GH_TOKEN ]] || fail 'list names'
out=$(load-secret GH_TOKEN) && [[ $out == 'value-of:op://Private/GitHub/token' ]] || fail 'program prints the value'
status=0
out=$(bash -c 'source "$1/home/.shell.d/secret.sh" && load-secret "bad name"' _ "$ROOT" 2>&1) || status=$?
((status == 2)) || fail 'invalid name rejected'
status=0
out=$(load-secret -f 2>&1) || status=$?
((status == 2)) || fail '-f without a name rejected'

# Run directly on a terminal, the program refuses to show the value.
if command -v script > /dev/null && script -qc true /dev/null > /dev/null 2>&1; then
  out=$(script -qc 'load-secret GH_TOKEN; echo "status=$?"' /dev/null 2>&1) || true
  [[ $out != *value-of:* && $out == *'not printing GH_TOKEN to a terminal'* && $out == *status=1* ]] ||
    fail 'terminal output refused'
fi

echo 'PASS: load-secret exports and caches secrets, -f bypasses the cache, never prints to a terminal, and signs in when signed out'
