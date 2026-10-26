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
echo call >> "$OP_LOG"
[ "$1" = read ] && printf 'value-of:%s' "$2"
STUB
cat > "$TMP/bin/chmod" << STUB
#!/bin/sh
[ "\$2" != -- ] || { echo "chmod: --: No such file or directory" >&2; exit 1; }
exec "$REAL_CHMOD" "\$@"
STUB
chmod +x "$TMP/bin/op" "$TMP/bin/chmod"
printf 'GH_TOKEN=op://Private/GitHub/token\n' > "$TMP/home/.config/secret/secrets.conf"
export PATH="$TMP/bin:$PATH" HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/run" OP_LOG="$TMP/op.log"

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

echo 'PASS: load-secret exports and caches secrets (BSD chmod compatible)'
