#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git init -q -b main "$TMP/repo"
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email test@example.com
echo base > "$TMP/repo/base"
git -C "$TMP/repo" add base
git -C "$TMP/repo" commit -qm base
git clone -q --bare "$TMP/repo" "$TMP/origin.git"
git -C "$TMP/repo" remote add origin "$TMP/origin.git"
git -C "$TMP/repo" push -q origin main
git -C "$TMP/repo" branch both
git -C "$TMP/repo" branch local-only
git -C "$TMP/repo" branch longest-branch-name
git -C "$TMP/repo" branch remote-only
git -C "$TMP/repo" push -q origin both remote-only
git -C "$TMP/repo" branch -D remote-only >/dev/null
git -C "$TMP/repo" fetch -q origin
git -C "$TMP/repo" worktree add -q "$TMP/linked" both

cd "$TMP/repo"
# A shell function stub avoids requiring an interactive terminal for fzf.
fzf() { cat; }
source "$ROOT/home/.shell.d/zz-fzf-git.sh"

candidates=$(_fzf_git_branch_candidates)
[[ -n $candidates ]]
# Every candidate must have an undecorated ref and one tab delimiter.
printf '%s\n' "$candidates" | awk -F '\\t' '
  NF != 2 || $1 == "" || $2 == "" { bad=1 }
  END { exit bad }
'
visible=$(printf '%s\n' "$candidates" | cut -f2-)
printf '%s\n' "$visible" | awk '$1 == "*" && $2 == "*" && $3 == "both" { found=1 } END { exit !found }'
printf '%s\n' "$visible" | awk '$1 == "*" && $2 == "-" && $3 == "local-only" { found=1 } END { exit !found }'
printf '%s\n' "$visible" | awk '$1 == "-" && $2 == "*" && $3 == "remote-only" { found=1 } END { exit !found }'
[[ $(printf '%s\n' "$visible" | awk '$3 == "both" { n++ } END { print n+0 }') -eq 1 ]]

both_row=$(printf '%s\n' "$candidates" | grep -E '^both[[:space:]]')
[[ $both_row == *"$TMP/linked"* ]]
# The worktree path starts immediately after the longest branch-name column.
printf '%s\n' "$visible" | awk -v path="$TMP/linked" '
  $3 == "both" {
    pos = index($0, path)
    # "* *  " is five chars; 19-char longest-branch-name; one separator.
    if (pos != 5 + length("longest-branch-name") + 2) exit 1
    found = 1
  }
  END { if (!found) exit 1 }
'

# The selection output remains an undecorated branch ref.
fzf() { grep 'remote-only' | head -n 1; }
[[ $(_fzf_git_select_branch) == origin/remote-only ]]
fzf() { grep 'both' | head -n 1; }
[[ $(_fzf_git_select_branch) == both ]]

# A name longer than 42 characters must not move the worktree column.
long_branch='feat/this-is-a-very-long-branch-name-exceeding-forty-two-characters'
git branch "$long_branch"
git worktree add -q "$TMP/long-linked" "$long_branch"
candidates=$(_fzf_git_branch_candidates)
visible=$(printf '%s\n' "$candidates" | cut -f2-)
printf '%s\n' "$visible" | awk -v path="$TMP/long-linked" '
  index($0, path) {
    if (index($0, path) != 5 + 42 + 2) bad = 1
    if (index($0, "...") == 0) bad = 1
    found = 1
  }
  END { exit bad || !found }
'
printf '%s\n' "$candidates" | grep -Fq "$long_branch"
fzf() { grep -F "$long_branch" | head -n 1; }
[[ $(_fzf_git_select_branch) == "$long_branch" ]]

# Like gbr -b, gwt -b requires a new branch name and never opens fzf.
fzf() {
  echo 'fzf must not run' >&2
  return 1
}
status=0
err=$(gwt -b 2>&1) || status=$?
[[ $status -eq 2 && $err == 'Usage: gwt -b <new-branch>' ]]
status=0
err=$(gwt -b '' 2>&1) || status=$?
[[ $status -eq 2 && $err == 'Usage: gwt -b <new-branch>' ]]

echo 'PASS: deduplicated branch status, capped columns, ref selection and gwt -b usage'
