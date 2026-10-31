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
# OP_SIGNED_OUT: every command fails as when no session exists.
# OP_BAD_REF: only read fails, as for a wrong reference.
[ -z "${OP_SIGNED_OUT:-}" ] || { echo '[ERROR] You are not currently signed in.' >&2; exit 1; }
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
  load() { "$sh" -c 'source "$1/home/.shell.d/secret.sh" && load-secret GH_TOKEN && printf "%s" "$GH_TOKEN"' _ "$ROOT" 2>&1; }
  out=$(load) || fail "$sh: load-secret failed"
  [[ $out == 'value-of:op://Private/GitHub/token' ]] || fail "$sh: exported value"
  # The second call is served from the private cache without asking 1Password.
  out=$(load) || fail "$sh: cached load failed"
  [[ $out == 'value-of:op://Private/GitHub/token' && $(wc -l < "$OP_LOG") == 1 ]] || fail "$sh: cache"
  [[ -n $(find "$TMP/run/secret-cache" -maxdepth 0 -perm 700) ]] || fail "$sh: cache permissions"
done

# A failed read explains how to sign in, but only when signed out.
fresh() {
  rm -rf "$TMP/run/secret-cache"
  bash -c 'source "$1/home/.shell.d/secret.sh" && load-secret GH_TOKEN' _ "$ROOT" 2>&1
}
status=0
out=$(OP_SIGNED_OUT=1 fresh) || status=$?
((status == 1)) && [[ $out == *'not signed in'*'eval "$(op signin)"'* ]] || fail 'sign-in hint'
status=0
out=$(OP_BAD_REF=1 fresh) || status=$?
((status == 1)) && [[ $out == *'could not read secret'* && $out != *'op signin'* ]] || fail 'no hint for other failures'

# Listing and direct use of the program (e.g. from scripts) work without the function.
out=$(load-secret) && [[ $out == GH_TOKEN ]] || fail 'list names'
out=$(load-secret GH_TOKEN) && [[ $out == 'value-of:op://Private/GitHub/token' ]] || fail 'program prints the value'
status=0
out=$(bash -c 'source "$1/home/.shell.d/secret.sh" && load-secret "bad name"' _ "$ROOT" 2>&1) || status=$?
((status == 2)) || fail 'invalid name rejected'

echo 'PASS: load-secret exports and caches secrets and explains a missing sign-in'
