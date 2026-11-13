#!/usr/bin/env bash
# gwt-path finds a worktree by its branch even after the branch is renamed
# in place, refuses to reuse the old directory without leaving a branch, and
# -d keeps untracked files while removing the worktree and its branch.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
gwt_path="$repo_root/bin/git/gwt-path"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.invalid \
  GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.invalid

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "$(cat "$tmp/out" 2> /dev/null)" >&2
  exit 1
}

git init -q -b main "$tmp/repo"
cd "$tmp/repo"
git commit -q --allow-empty -m base
git remote add origin git@github.com:owner/repo.git

wt=$("$gwt_path" -b feat/a 2> /dev/null) || fail 'create feat/a'
[[ $wt == "$HOME/worktrees/owner/repo/feat/a" ]] || fail "unexpected path: $wt"
git -C "$wt" branch -m feat/b

[[ $("$gwt_path" feat/b 2> /dev/null) == "$wt" ]] || fail 'renamed branch not found'

if "$gwt_path" -b feat/a > "$tmp/out" 2>&1; then fail 'taken directory reused'; fi
grep -q 'Destination already exists' "$tmp/out" || fail 'message'
[[ -z $(git branch --list feat/a) ]] || fail 'stray branch feat/a left'
[[ $(git worktree list | wc -l) == 2 ]] || fail 'worktree list changed'

# -d keeps untracked and ignored files, removes tracked ones, unregisters
# the worktree and deletes the branch.
mkdir -p src
echo tracked > src/tracked.txt
echo '*.log' > .gitignore
git add -A && git commit -q -m files
wt=$("$gwt_path" -b feat/c 2> /dev/null) || fail 'create feat/c'
echo note > "$wt/src/untracked.txt"
echo log > "$wt/debug.log"
admin=$(git -C "$wt" rev-parse --absolute-git-dir)
out=$("$gwt_path" -d feat/c 2> "$tmp/out") || fail 'delete feat/c'
[[ $out == "$PWD" ]] || fail "unexpected cd target: $out"
grep -q "Kept untracked files in: $wt" "$tmp/out" || fail 'kept message'
[[ -f $wt/src/untracked.txt && -f $wt/debug.log ]] || fail 'untracked or ignored file removed'
[[ ! -e $wt/src/tracked.txt && ! -e $wt/.gitignore && ! -e $wt/.git ]] || fail 'tracked file or .git left'
! git worktree list | grep -qF "$wt" || fail 'worktree still registered'
[[ ! -e $admin ]] || fail 'admin dir left'
[[ -z $(git branch --list feat/c) ]] || fail 'branch feat/c not deleted'

# A clean worktree directory is removed entirely.
wt=$("$gwt_path" -b feat/d 2> /dev/null) || fail 'create feat/d'
"$gwt_path" -d feat/d > /dev/null 2> "$tmp/out" || fail 'delete feat/d'
[[ ! -e $wt ]] || fail 'clean worktree directory left'

echo 'PASS: gwt-path follows renamed branches, refuses taken directories and keeps untracked files on -d'
