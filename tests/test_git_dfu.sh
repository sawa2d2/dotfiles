#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL="$ROOT/home/.git.d/.gitconfig_shared" GIT_PAGER=cat
source "$ROOT/tests/git_diff_helpers.bash"
setup_diff_repo
out=$(git dfu)
[[ $(git dfu -p) == "$out" ]]
for file in base sub/file untracked -p; do
  grep -q "^diff --git a/$file b/$file$" <<< "$out"
done
if grep -q -e 'a/staged' -e 'a/first' -e 'a/second' <<< "$out"; then
  echo 'FAIL: includes staged or committed changes' >&2
  exit 1
fi
status=0
git dfu extra 2> /dev/null || status=$?
[[ $status -eq 2 ]]
check_display dfu
echo "PASS: git dfu scope, plain output and paging"
