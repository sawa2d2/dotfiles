#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL=/dev/null GIT_PAGER=cat

git init -q -b main "$TMP/repo"
cd "$TMP/repo"
git config user.name Test
git config user.email test@example.com
echo base > base
git add base
git commit -qm base
git clone -q --bare . "$TMP/origin.git"
git remote add origin "$TMP/origin.git"
git fetch -q origin

git switch -q -c feature
echo committed > committed
git add committed
git commit -qm committed

# origin/main moves on after the branch forked.
git clone -q "$TMP/origin.git" "$TMP/other"
git -C "$TMP/other" -c user.name=Test -c user.email=test@example.com commit -q --allow-empty -m noop
echo upstream > "$TMP/other/upstream"
git -C "$TMP/other" add upstream
git -C "$TMP/other" -c user.name=Test -c user.email=test@example.com commit -qm upstream
git -C "$TMP/other" push -q origin main
git fetch -q origin

echo staged > staged
git add staged
echo changed >> base
echo untracked > untracked
echo ignored > ignored.log
echo '*.log' > .git/info/exclude

out=$(git dfm)
for file in committed staged base untracked; do
  grep -q "^diff --git a/$file b/$file\$" <<< "$out" || {
    echo "FAIL: missing $file" >&2
    exit 1
  }
done
if grep -q -e upstream -e ignored.log <<< "$out"; then
  echo 'FAIL: includes origin/main-only or ignored changes' >&2
  exit 1
fi

status=0
git dfm extra 2> /dev/null || status=$?
[[ $status -eq 2 ]]

echo 'PASS: git dfm shows branch, worktree and untracked changes since merge base'
