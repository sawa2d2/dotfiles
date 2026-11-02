#!/usr/bin/env bash
# gfinish also deletes the old remote name of a branch renamed with
# `git branch -m` after it was pushed, but only when nothing can be lost.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
gfinish="$repo_root/bin/git/gfinish"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.invalid \
  GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.invalid

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "$(cat "$tmp/out" 2> /dev/null)" >&2
  exit 1
}

git init --bare -q -b main "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/repo" 2> /dev/null
cd "$tmp/repo"
git switch -q -c main
printf 'base\n' > file
git add file
git commit -qm base
git push -q -u origin main

on_origin() { [[ -n $(git ls-remote --heads origin "refs/heads/$1") ]]; }
# Push branch $1 with a commit, then rename it to $2 without pushing.
pushed_then_renamed() {
  git switch -q -c "$1" main
  printf '%s\n' "$1" > "$1.txt"
  git add "$1.txt"
  git commit -qm "$1"
  git push -q -u origin "$1"
  git branch -m "$2"
}
finish() { "$gfinish" -y -m "$1" > "$tmp/out" 2>&1 || fail "$1: gfinish failed"; }

# Renamed after push: both the new and the old name are removed from origin.
pushed_then_renamed old-a new-a
finish new-a
! on_origin old-a || fail 'old-a: old name left on origin'
! on_origin new-a || fail 'new-a: new name left on origin'

# The old name gained a commit the renamed branch lacks: it is kept.
pushed_then_renamed old-b new-b
git clone -q "$tmp/origin.git" "$tmp/other" 2> /dev/null
git -C "$tmp/other" switch -q old-b
printf 'other\n' >> "$tmp/other/file"
git -C "$tmp/other" commit -qam other
git -C "$tmp/other" push -q origin old-b
finish new-b
on_origin old-b || fail 'old-b: deleted with commits not in new-b'
grep -q 'Kept origin/old-b (old name of new-b): it has commits not in new-b' "$tmp/out" || fail 'old-b: message'

# Another local branch still tracks the old name: it is kept.
pushed_then_renamed old-c new-c
git branch -q --track keep-c origin/old-c
finish new-c
on_origin old-c || fail 'old-c: deleted while tracked by keep-c'
grep -q 'also tracked by keep-c' "$tmp/out" || fail 'old-c: message'

# Branched off someone else's branch (upstream differs, but no rename):
# their branch is never touched.
git switch -q -c theirs main
printf 'theirs\n' > theirs.txt
git add theirs.txt
git commit -qm theirs
git push -q origin theirs
git switch -q main
git branch -q -D theirs
git fetch -q origin
git switch -q -c mine --track origin/theirs
printf 'mine\n' >> theirs.txt
git commit -qam mine
git push -q origin HEAD:mine
finish mine
on_origin theirs || fail 'theirs: deleted though mine was never renamed'
! grep -q 'Kept' "$tmp/out" || fail 'theirs: unexpected message'

echo 'PASS: gfinish removes the old remote name of a renamed branch only when safe'
