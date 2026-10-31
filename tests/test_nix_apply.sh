#!/usr/bin/env bash
# nix/apply builds the Home Manager generation and activates it, except with
# --dry-run; it never installs Nix itself.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "${out:-}" >&2
  exit 1
}

# Stub nix: `nix build ... --print-out-paths` prints a generation whose
# activate script records that it ran.
mkdir -p "$TMP/bin" "$TMP/generation"
cat > "$TMP/bin/nix" << 'EOF'
#!/bin/sh
echo "nix $*" >> "$LOG"
echo "$GENERATION"
EOF
cat > "$TMP/generation/activate" << 'EOF'
#!/bin/sh
echo activated >> "$LOG"
EOF
chmod +x "$TMP/bin/nix" "$TMP/generation/activate"
export LOG="$TMP/log" GENERATION="$TMP/generation"
# Only the stub and the system tools; a real nix never runs.
SYSTEM_PATH=$(dirname "$(command -v bash)"):/usr/bin:/bin

out=$(PATH="$TMP/bin:$SYSTEM_PATH" bash "$ROOT/nix/apply" --dry-run 2>&1) || fail 'dry run failed'
grep -q '^nix build' "$LOG" || fail 'dry run did not build'
! grep -q activated "$LOG" || fail 'dry run activated'
[[ $out == *"$TMP/generation"* ]] || fail 'dry run did not report the generation'

: > "$LOG"
out=$(PATH="$TMP/bin:$SYSTEM_PATH" bash "$ROOT/nix/apply" 2>&1) || fail 'apply failed'
grep -q activated "$LOG" || fail 'apply did not activate'

status=0
out=$(PATH="$TMP/bin:$SYSTEM_PATH" bash "$ROOT/nix/apply" --bogus 2>&1) || status=$?
((status == 2)) || fail 'unknown option accepted'

# Without nix it stops; nothing tries to install Nix.
rm "$TMP/bin/nix"
status=0
out=$(PATH="$TMP/bin:$SYSTEM_PATH" bash "$ROOT/nix/apply" 2>&1) || status=$?
((status == 1)) && [[ $out == *'Nix is not installed'* ]] || fail 'missing nix'

echo 'PASS: nix/apply activates, builds only with --dry-run, and needs Nix installed'
