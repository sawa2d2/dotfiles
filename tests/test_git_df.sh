#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL="$ROOT/home/.git.d/.gitconfig_shared" GIT_PAGER=cat
source "$ROOT/tests/git_diff_helpers.bash"
setup_diff_repo
[[ $(git df) == "$(git diff)" ]]
[[ $(git df -p --stat -- base) == "$(git diff --stat -- base)" ]]
[[ $(git df -- -p) == "$(git diff -- -p)" ]]
[[ $(git df -p -- -p) == "$(git diff -- -p)" ]]
cd sub
[[ $(git df -p -- file) == "$(git diff -- file)" ]]
cd ..
check_display df
echo "PASS: git df scope, plain output and paging"
