#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Stub gh: GH_PR_STATE is the current branch's PR state, empty for none.
mkdir "$TMP/bin"
cat > "$TMP/bin/gh" << 'EOF'
#!/usr/bin/env bash
printf 'gh %s\n' "$*" >> "$LOG"
case "$1 $2" in
"pr view")
  if [[ $3 == --json ]]; then
    [[ -n $GH_PR_STATE ]] || {
      echo 'no pull requests found' >&2
      exit 1
    }
    printf '%s\n' "$GH_PR_STATE"
  fi
  ;;
"repo view") echo 'https://github.com/owner/repo main' ;;
*) exit 1 ;;
esac
EOF
# Record browser launches instead of opening anything.
cat > "$TMP/bin/xdg-open" << 'EOF'
#!/bin/sh
printf 'open %s\n' "$1" >> "$LOG"
EOF
cp "$TMP/bin/xdg-open" "$TMP/bin/open"
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH" LOG="$TMP/log"

git init -q -b main "$TMP/repo"
cd "$TMP/repo"
git -c user.name=Test -c user.email=test@example.com commit -q --allow-empty -m base
git clone -q --bare . "$TMP/origin.git"
git remote add origin "$TMP/origin.git"
git push -q origin main
git switch -q -c feat/x
git push -q origin feat/x

run() {
  : > "$LOG"
  local status=0
  GH_PR_STATE=$1 bash "$ROOT/bin/git/ghpr" 2> "$TMP/err" || status=$?
  # The Linux opener runs in the background.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    grep -q '^open ' "$LOG" && break
    ((status == 0)) || break
    sleep 0.1
  done
  return "$status"
}

# The default branch has no PR of its own: open the repository's top page.
git switch -q main
run OPEN
grep -qx 'open https://github.com/owner/repo' "$LOG"
if grep -q 'pr view' "$LOG"; then
  echo 'FAIL: default branch looked up a PR' >&2
  exit 1
fi
git switch -q feat/x

run OPEN
grep -qx 'gh pr view --web' "$LOG"
for state in '' MERGED CLOSED; do
  run "$state"
  grep -qx 'open https://github.com/owner/repo/compare/main...feat/x?expand=1' "$LOG"
done

# Never push: an unpushed branch is an error, not a push prompt.
git switch -q -c feat/local
status=0
run '' || status=$?
((status == 1))
grep -q 'Remote branch not found: feat/local' "$TMP/err"
if grep -q -e 'pr create' -e '^open ' "$LOG"; then
  echo 'FAIL: unpushed branch reached gh pr create or the browser' >&2
  exit 1
fi
[[ -z $(git ls-remote --heads origin feat/local) ]]

echo 'PASS: ghpr opens an open PR, otherwise the compare page (the top page on the default branch), without pushing'
