#!/usr/bin/env bash
# gprune -w removes clean linked worktrees of merged branches, then the branches.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# Resolve symlinks (macOS /var) so paths match git worktree output.
TMP=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP"' EXIT
repo=$TMP/repo

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

has_branch() { git -C "$repo" show-ref -q --verify "refs/heads/$1"; }

git init -q -b main "$repo"
git -C "$repo" config user.name Test
git -C "$repo" config user.email test@example.com
printf 'base\n' > "$repo/base"
git -C "$repo" add base
git -C "$repo" commit -qm base
git clone -q --bare "$repo" "$TMP/origin.git"
git -C "$repo" remote add origin "$TMP/origin.git"
git -C "$repo" push -q -u origin main

# Create a worktree branch whose commit lands on origin/main.
merged_worktree() {
  local branch=$1
  git -C "$repo" worktree add -q -b "$branch" "$TMP/$branch"
  printf '%s\n' "$branch" > "$TMP/$branch/$branch"
  git -C "$TMP/$branch" add "$branch"
  git -C "$TMP/$branch" commit -qm "$branch"
  git -C "$repo" merge -q --ff-only "$branch"
}

merged_worktree clean
merged_worktree modified
merged_worktree staged
merged_worktree untracked
merged_worktree missing
merged_worktree current
# Sorted after the refused worktrees to prove the loop continues past them.
merged_worktree z-clean
git -C "$repo" push -q origin main
printf 'changed\n' >> "$TMP/modified/modified"
printf 'changed\n' >> "$TMP/staged/staged"
git -C "$TMP/staged" add staged
printf 'untracked\n' > "$TMP/untracked/new"
rm -rf "$TMP/missing"

git -C "$repo" worktree add -q -b unmerged "$TMP/unmerged"
printf 'unique\n' > "$TMP/unmerged/unique"
git -C "$TMP/unmerged" add unique
git -C "$TMP/unmerged" commit -qm unique

# Without -w, every branch checked out in a worktree is kept.
(cd "$repo" && "$ROOT/bin/git/gprune") > /dev/null
for branch in clean modified staged untracked current z-clean unmerged; do
  has_branch "$branch" || fail "$branch removed without -w"
done
[[ -d $TMP/clean ]] || fail 'worktree removed without -w'

# Run from a linked worktree so it is protected as the current one.
output=$(cd "$TMP/current" && "$ROOT/bin/git/gprune" -w 2>&1) || fail "gprune -w failed: $output"

[[ ! -d $TMP/clean ]] || fail 'clean worktree kept'
has_branch clean && fail 'clean branch kept'
has_branch missing && fail 'branch of missing worktree kept'
# git worktree remove refuses these without --force; gprune skips them.
for branch in modified staged untracked; do
  [[ -d $TMP/$branch ]] || fail "$branch worktree removed"
  has_branch "$branch" || fail "$branch branch removed"
  [[ $output == *"SKIP $branch"* ]] || fail "$branch not reported as skipped: $output"
done
[[ $(git -C "$TMP/modified" diff --name-only) == modified ]] || fail 'unstaged change lost'
[[ $(git -C "$TMP/staged" diff --cached --name-only) == staged ]] || fail 'staged change lost'
[[ -f $TMP/untracked/new ]] || fail 'untracked file lost'
[[ ! -d $TMP/z-clean ]] || fail 'clean worktree after skipped ones kept'
has_branch z-clean && fail 'clean branch after skipped ones kept'
[[ -d $TMP/current ]] || fail 'current worktree removed'
has_branch current || fail 'current branch removed'
[[ -d $TMP/unmerged ]] || fail 'unmerged worktree removed'
has_branch unmerged || fail 'unmerged branch removed'
has_branch main || fail 'main removed'
[[ $output == *"DELETE clean"*"$TMP/clean"* ]] || fail "worktree path not reported: $output"

echo 'PASS: gprune -w removes only clean merged worktrees'
