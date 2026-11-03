#!/usr/bin/env bash
# gprune deletes local branches already squash-merged into origin/main; with
# -w also their clean linked worktrees. Each section starts from a fresh repo.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
# Resolve symlinks (macOS /var) so paths match git worktree output.
TMP_ROOT=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

has_branch() { git -C "$repo" show-ref -q --verify "refs/heads/$1"; }

# Create $TMP_ROOT/$1 with a repo whose main has one commit pushed to origin.git.
setup() {
  TMP=$TMP_ROOT/$1
  repo=$TMP/repo
  git init -q -b main "$repo"
  git -C "$repo" config user.name Test
  git -C "$repo" config user.email test@example.com
  printf 'base\n' > "$repo/base"
  git -C "$repo" add base
  git -C "$repo" commit -qm base
  git clone -q --bare "$repo" "$TMP/origin.git"
  git -C "$repo" remote add origin "$TMP/origin.git"
  git -C "$repo" push -q -u origin main
}

# --- Squash-merged branches are deleted; unmerged ones are kept.
setup squash

git -C "$repo" switch -qc stale
printf 'one\n' > "$repo/one"
git -C "$repo" add one
git -C "$repo" commit -qm one
printf 'two\n' > "$repo/two"
git -C "$repo" add two
git -C "$repo" commit -qm two
git -C "$repo" push -q origin stale

git -C "$repo" switch -q main
git -C "$repo" merge --squash -q stale > /dev/null
git -C "$repo" commit -qm 'squash stale'
git -C "$repo" push -q origin main
git -C "$repo" push -q origin --delete stale

git -C "$repo" switch -qc keep
printf 'unique\n' > "$repo/unique"
git -C "$repo" add unique
git -C "$repo" commit -qm unique
git -C "$repo" switch -q main

output=$(cd "$repo" && "$ROOT/bin/git/gprune")
[[ $output == *'DELETE stale'* ]] || fail "merged branch not reported: $output"
[[ $output != *'DELETE keep'* ]] || fail 'unmerged branch selected'
has_branch stale && fail 'merged branch not removed'
has_branch keep || fail 'unmerged branch removed'
has_branch main || fail 'main removed'

# Quiet mode is silent when nothing is eligible or origin/main is missing.
quiet=$(cd "$repo" && "$ROOT/bin/git/gprune" --quiet 2>&1)
[[ -z $quiet ]] || fail "quiet mode printed: $quiet"
git init -q -b master "$TMP/other"
quiet=$(cd "$TMP/other" && "$ROOT/bin/git/gprune" --quiet 2>&1)
[[ -z $quiet ]] || fail "quiet mode without origin/main printed: $quiet"

# --- -w removes clean linked worktrees of merged branches, then the branches.
setup worktrees

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

echo 'PASS: gprune squash-merged branches, quiet mode, and -w worktrees'
