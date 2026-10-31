#!/usr/bin/env bash
# gfinish wherever main is checked out: in the primary worktree, in another
# worktree, or nowhere; run from the primary worktree or an extra one.
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
git clone -q "$tmp/origin.git" "$tmp/primary" 2> /dev/null
cd "$tmp/primary"
git switch -q -c main
printf 'base\n' > file
git add file
git commit -qm base
git push -q -u origin main

# Commit a change to file on a new branch $1 in the current worktree.
change() {
  git switch -q -c "$1" main
  printf '%s\n' "$1" >> file
  git commit -qam "$1"
  git push -q origin "$1"
}
finish() { "$gfinish" -y -m "$1" > "$tmp/out" 2>&1 || fail "$1: gfinish failed"; }
# main locally and on origin is the squash commit of $1, and $1 is gone.
finished() {
  [[ $(git -C "$tmp/primary" log -1 --format=%s main) == "$1" ]] || fail "$1: local main"
  [[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s main) == "$1" ]] || fail "$1: origin main"
  [[ -z $(git -C "$tmp/primary" branch --list "$1") ]] || fail "$1: branch left"
  [[ $(git -C "$tmp/primary" worktree list | wc -l) == "$2" ]] || fail "$1: worktrees left"
}

# Primary worktree, main checked out nowhere else: ends on main.
change feat/a
finish feat/a
finished feat/a 1
[[ $(git branch --show-current) == main ]] || fail 'feat/a: not on main'

# Primary worktree while main is checked out in another worktree: that
# worktree is fast-forwarded and the primary is left detached at main.
git switch -q --detach
git worktree add -q "$tmp/main-wt" main
change feat/b
finish feat/b
finished feat/b 2
[[ $(git -C "$tmp/main-wt" log -1 --format=%s) == feat/b ]] || fail 'feat/b: main worktree not updated'
[[ -z $(git branch --show-current) && $(git rev-parse HEAD) == $(git rev-parse main) ]] ||
  fail 'feat/b: primary not detached at main'
git worktree remove "$tmp/main-wt"

# Extra worktree while the primary is on another branch: main is moved
# without touching the primary, and the extra worktree is removed.
git switch -q -c other main
git worktree add -q -b feat/c "$tmp/c" main
(
  cd "$tmp/c"
  printf 'c\n' >> file
  git commit -qam c
  git push -q origin feat/c
  finish feat/c
)
finished feat/c 1
[[ $(git branch --show-current) == other && ! -e $tmp/c ]] || fail 'feat/c: primary or worktree'

# A dirty main worktree stops before anything changes.
git switch -q main
change feat/d
git worktree add -q "$tmp/main-wt" main
printf 'dirty\n' >> "$tmp/main-wt/file"
before=$(git rev-parse main)
if "$gfinish" -y -m feat/d > "$tmp/out" 2>&1; then fail 'feat/d: dirty main worktree accepted'; fi
grep -q 'Main worktree has uncommitted changes' "$tmp/out" || fail 'feat/d: message'
[[ $(git rev-parse main) == "$before" && $(git branch --show-current) == feat/d ]] || fail 'feat/d: state changed'
git -C "$tmp/main-wt" checkout -q -- file
git worktree remove "$tmp/main-wt"

# A conflicting squash leaves main and the worktree list as they were.
git switch -q main
printf 'conflict\n' >> file
git commit -qam conflict
git push -q origin main
git switch -q feat/d
if "$gfinish" -y -m feat/d > "$tmp/out" 2>&1; then fail 'feat/d: conflict accepted'; fi
[[ $(git log -1 --format=%s main) == conflict && $(git worktree list | wc -l) == 1 ]] ||
  fail 'feat/d: conflict left state behind'
[[ $(git branch --show-current) == feat/d && -z $(git status --porcelain) ]] || fail 'feat/d: checkout changed'
grep -qx '  file' "$tmp/out" || fail 'feat/d: conflicted path not listed'

# An aborted commit message (editor exits non-zero) also leaves no trace.
git switch -q -c feat/e main
printf 'e\n' >> file
git commit -qam e
git push -q origin feat/e
if GIT_EDITOR=false "$gfinish" <<< y > "$tmp/out" 2>&1; then fail 'feat/e: aborted commit accepted'; fi
grep -q "Squash commit was not made" "$tmp/out" || fail 'feat/e: did not reach the commit'
[[ $(git log -1 --format=%s main) == conflict && $(git worktree list | wc -l) == 1 ]] ||
  fail 'feat/e: aborted commit left state behind'

# Nothing is checked out to squash: a required filter whose smudge fails
# (e.g. Git LFS configured but not installed) does not get in the way.
git switch -q main
git reset -q --hard origin/main
printf '*.bin filter=broken\n' > .gitattributes
printf 'blob\n' > font.bin
git -c filter.broken.clean=cat add .gitattributes font.bin
git commit -qm 'add filtered file'
git push -q origin main
git config filter.broken.clean cat
git config filter.broken.smudge false
git config filter.broken.required true
change feat/f
finish feat/f
finished feat/f 1

# Without -m or -y the editor gets the default message; comments are dropped.
cat > "$tmp/editor" << 'EDITOR'
#!/bin/sh
grep -q '^feat: g$' "$1" || exit 1
printf 'edited subject\n# dropped\n' > "$1"
EDITOR
chmod +x "$tmp/editor"
change feat/g
GIT_EDITOR="$tmp/editor" "$gfinish" <<< $'y\ny' > "$tmp/out" 2>&1 || fail 'feat/g: gfinish failed'
[[ $(git log -1 --format=%B main) == 'edited subject' ]] || fail 'feat/g: edited message'

echo 'PASS: gfinish integrates wherever main is checked out'
