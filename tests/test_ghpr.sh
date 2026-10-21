#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Stub gh: GH_PR_STATE is the current branch's PR state, empty for none.
mkdir "$TMP/bin"
cat > "$TMP/bin/gh" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
if [[ "$1 $2 $3" == "pr view --json" ]]; then
  [[ -n $GH_PR_STATE ]] || {
    echo 'no pull requests found' >&2
    exit 1
  }
  printf '%s\n' "$GH_PR_STATE"
fi
EOF
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH" GH_LOG="$TMP/log"

run() {
  : > "$GH_LOG"
  GH_PR_STATE=$1 bash "$ROOT/bin/git/ghpr" "${@:2}"
  tail -n 1 "$GH_LOG"
}

[[ $(run OPEN) == 'pr view --web' ]]
[[ $(run '' --base dev) == 'pr create --web --base dev' ]]
# A merged or closed PR is history; propose a new one instead.
[[ $(run MERGED) == 'pr create --web' ]]
[[ $(run CLOSED) == 'pr create --web' ]]

echo 'PASS: ghpr opens an open PR, otherwise the compare page'
