#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL="$ROOT/home/.git.d/.gitconfig_shared" GIT_PAGER=cat
source "$ROOT/tests/git_diff_helpers.bash"
setup_diff_repo
[[ $(git dfn) == "$(git diff HEAD~1 HEAD)" ]]
[[ $(git dfn 2) == "$(git diff HEAD~2 HEAD~1)" ]]
[[ $(git dfn -p 2) == "$(git diff HEAD~2 HEAD~1)" ]]
[[ $(git dfn -p 2 --stat -- second) == "$(git diff HEAD~2 HEAD~1 --stat -- second)" ]]
[[ $(git dfn -p -- sub/file) == "$(git diff HEAD~1 HEAD -- sub/file)" ]]
check_display dfn
echo "PASS: git dfn scope, plain output and paging"
