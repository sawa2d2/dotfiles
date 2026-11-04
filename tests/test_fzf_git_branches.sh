#!/usr/bin/env bash
# shellcheck disable=SC2329 # fzf stubs are called by the sourced functions
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
git -C "$TMP/repo" branch -D remote-only > /dev/null
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

# Fetch must update candidates before selection, pruning deleted remote refs.
git --git-dir="$TMP/origin.git" branch fetched-branch main
git --git-dir="$TMP/origin.git" branch -D remote-only > /dev/null
git --git-dir="$TMP/origin.git" tag unfetched-tag main
git() {
  if [[ ${1:-} == fetch ]]; then
    printf '%s\n' "$*" >> "$TMP/fetch.log"
    [[ ${GIT_TERMINAL_PROMPT:-} == 0 ]] || return 1
    if [[ ${fail_fetch:-0} == 1 ]]; then
      return 1
    fi
  fi
  command git "$@"
}
timeout() {
  [[ $1 == 10s ]]
  shift
  if [[ ${expire_fetch:-0} == 1 ]]; then
    return 124
  fi
  "$@"
}
fzf() { grep 'fetched-branch' | head -n 1; }
gbr
[[ $(git branch --show-current) == fetched-branch ]]
[[ $(cat "$TMP/fetch.log") == 'fetch --prune --no-tags --no-recurse-submodules' ]]
[[ -z $(git for-each-ref --format='%(refname)' refs/remotes/origin/remote-only) ]]
[[ -z $(git tag --list unfetched-tag) ]]

# Failed and timed-out fetches still permit selecting existing local refs.
fzf() { grep 'local-only' | head -n 1; }
fail_fetch=1
gbr 2> "$TMP/fetch.err"
[[ $(git branch --show-current) == local-only ]]
grep -Fq 'Warning: git fetch failed; continuing with existing refs.' "$TMP/fetch.err"
fail_fetch=0
expire_fetch=1
fzf() { grep 'main' | head -n 1; }
gbr 2> "$TMP/fetch.err"
[[ $(git branch --show-current) == main ]]
grep -Fq 'Warning: git fetch failed; continuing with existing refs.' "$TMP/fetch.err"
expire_fetch=0

# Without timeout, skip fetch and select an existing local branch immediately.
: > "$TMP/fetch.log"
mkdir "$TMP/no-timeout-bin"
for tool in git awk sort cut grep head; do
  ln -s "$(type -P "$tool")" "$TMP/no-timeout-bin/$tool"
done
(
  unset -f timeout
  export PATH="$TMP/no-timeout-bin"
  fzf() { grep 'local-only' | head -n 1; }
  gbr 2> "$TMP/no-timeout.err"
  [[ $(git branch --show-current) == local-only ]]
  [[ ! -s $TMP/fetch.log ]]
  grep -Fq 'Skipping git fetch: timeout is not installed.' "$TMP/no-timeout.err"
  grep -Fq 'brew install coreutils' "$TMP/no-timeout.err"
)

# Other gbr modes and gwt must never fetch.
: > "$TMP/fetch.log"
gbr local-only
gbr -b created-branch
gbr main
gbr -d created-branch
git branch delete-selected
fzf() { grep '^delete-selected$'; }
gbr -D
gwt-path() { printf '%s\n' "$TMP/repo"; }
fzf() { grep 'main' | head -n 1; }
gwt
[[ ! -s $TMP/fetch.log ]]

echo 'PASS: branch candidates, gbr fetch/failure handling, unchanged explicit modes and gwt'
