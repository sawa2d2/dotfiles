#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL="$ROOT/home/.git.d/.gitconfig_shared" GIT_PAGER=cat
source "$ROOT/tests/git_diff_helpers.bash"
setup_diff_repo
[[ $(git dfh) == "$(git diff HEAD)" ]]
[[ $(git dfh -p --stat -- base) == "$(git diff HEAD --stat -- base)" ]]
[[ $(git dfh -- -p) == "$(git diff HEAD -- -p)" ]]
[[ $(git dfh -p -- -p) == "$(git diff HEAD -- -p)" ]]
cd sub
[[ $(git dfh -p -- file) == "$(git diff HEAD -- file)" ]]
cd ..
check_display dfh
echo "PASS: git dfh scope, plain output and paging"
