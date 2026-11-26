#!/usr/bin/env bash
# gfinish squash-merges into the origin default branch and removes the feature. Each
# section below starts from a fresh origin and clone under $tmp.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
gfinish="$repo_root/bin/git/gfinish"
tmp_root=$(mktemp -d)
trap 'rm -rf -- "$tmp_root"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@example.invalid \
  GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@example.invalid
# Agents run these tests with AGENT_APPROVAL_DIR set; only the approval
# section below sets it.
unset AGENT_APPROVAL_DIR

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "$(cat "$tmp/out" 2> /dev/null)" >&2
  exit 1
}

# Create $tmp_root/$1 with origin.git and a clone at repo whose default has one
# commit pushed, and cd into the clone.
setup() {
  tmp=$tmp_root/$1
  test_default=${2:-main}
  git init --bare -q -b "$test_default" "$tmp/origin.git"
  git clone -q "$tmp/origin.git" "$tmp/repo" 2> /dev/null
  cd "$tmp/repo"
  git switch -q -c "$test_default"
  printf 'base\n' > file
  git add file
  git commit -qm base
  git push -q -u origin "$test_default"
  git symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$test_default"
}

finish() { "$gfinish" -y -m "$1" > "$tmp/out" 2>&1 || fail "$1: gfinish failed"; }

# --- Commit message: -m, --, the default, and invalid arguments.
setup message

check_finish() {
  local branch=$1 expected=$2
  shift 2
  git switch -q -c "$branch"
  printf '%s\n' "$branch" >> file
  git add file
  git commit -qm change
  "$gfinish" -y "$@" > "$tmp/out" 2>&1 || fail "$branch: gfinish failed"
  [[ $(git branch --show-current) == main ]] || fail "$branch: not on main"
  [[ $(git log -1 --format=%s) == "$expected" ]] || fail "$branch: message"
  [[ -z $(git branch --list "$branch") ]] || fail "$branch: branch left"
}

check_finish feat/separator 'Fix: hoge fuga' -- Fix: hoge fuga
check_finish feat/legacy 'Fix: original syntax' -m 'Fix: original syntax'
check_finish feat/default 'feat: default'

git switch -q -c feat/invalid
if "$gfinish" -y -- > /dev/null 2>&1; then fail 'empty -- message accepted'; fi
if "$gfinish" -y -m existing -- other > /dev/null 2>&1; then fail 'ambiguous -m/-- accepted'; fi
if "$gfinish" -y -- '  ' > /dev/null 2>&1; then fail 'whitespace-only message accepted'; fi

# --- Renamed branches: the old remote name of a branch renamed with
# `git branch -m` after it was pushed is deleted, but only when nothing can be lost.
setup renamed

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

# --- Worktrees: wherever main is checked out (in the primary worktree, in
# another worktree, or nowhere), run from the primary worktree or an extra one.
setup worktrees

# Commit a change to file on a new branch $1 in the current worktree.
change() {
  git switch -q -c "$1" main
  printf '%s\n' "$1" >> file
  git commit -qam "$1"
  git push -q origin "$1"
}
# main locally and on origin is the squash commit of $1, and $1 is gone.
finished() {
  [[ $(git -C "$tmp/repo" log -1 --format=%s main) == "$1" ]] || fail "$1: local main"
  [[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s main) == "$1" ]] || fail "$1: origin main"
  [[ -z $(git -C "$tmp/repo" branch --list "$1") ]] || fail "$1: branch left"
  [[ $(git -C "$tmp/repo" worktree list | wc -l) == "$2" ]] || fail "$1: worktrees left"
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
grep -q 'main worktree has uncommitted changes' "$tmp/out" || fail 'feat/d: message'
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

# --- Agent approval: with AGENT_APPROVAL_DIR set, gfinish needs a fresh
# marker for the worktree's real top level and uses it up.
setup approval
approval_dir=$tmp/approval
marker=$approval_dir/$(printf %s "$(realpath "$tmp/repo")" | sha256sum | cut -c1-64)
mkdir -p "$approval_dir"
change feat/h
# gfinish on the current branch is refused for reason $1 and changes nothing.
refused() {
  local branch before
  branch=$(git branch --show-current)
  before=$(git rev-parse main)
  if AGENT_APPROVAL_DIR=$approval_dir "$gfinish" -y -m "$branch" > "$tmp/out" 2>&1; then fail "$branch: $1 accepted"; fi
  grep -qx 'gfinish: an agent needs the user to say approved first' "$tmp/out" || fail "$branch: $1 message"
  [[ $(git rev-parse main) == "$before" && $(git branch --show-current) == "$branch" ]] || fail "$branch: $1 changed state"
}
refused 'missing marker'
touch -d '61 minutes ago' "$marker"
refused 'stale marker'
touch "$approval_dir/$(printf %s /elsewhere | sha256sum | cut -c1-64)"
rm -- "$marker"
refused 'marker of another repository'
touch "$marker"
AGENT_APPROVAL_DIR=$approval_dir "$gfinish" -y -m feat/h > "$tmp/out" 2>&1 || fail 'feat/h: approved gfinish failed'
finished feat/h 1
[[ ! -e $marker ]] || fail 'feat/h: marker not used up'
change feat/i
refused 'reused marker'
grep -qxF "gfinish: approval counts only in a session whose working directory is in $(realpath "$tmp/repo")" "$tmp/out" ||
  fail 'feat/i: expected top level not named'
# A linked worktree (reached through a symlink, with a space in its path) has
# its own key: approval in the primary checkout does not finish it.
git switch -q main
git worktree add -q -b feat/j "$tmp/linked wt" main
ln -s "$tmp/linked wt" "$tmp/wt-link"
cd "$tmp/wt-link"
printf 'j\n' >> file
git commit -qam feat/j
git push -q origin feat/j
touch "$marker"
refused 'marker of the primary checkout'
grep -qxF "gfinish: approval counts only in a session whose working directory is in $tmp/linked wt" "$tmp/out" ||
  fail 'feat/j: linked worktree not named'
linked_marker=$approval_dir/$(printf %s "$tmp/linked wt" | sha256sum | cut -c1-64)
touch "$linked_marker"
AGENT_APPROVAL_DIR=$approval_dir "$gfinish" -y -m feat/j > "$tmp/out" 2>&1 || fail 'feat/j: approved gfinish failed'
cd "$tmp/repo"
finished feat/j 1
[[ ! -e $linked_marker && -e $marker ]] || fail 'feat/j: wrong marker used up'

# --- Offline: with origin unreachable, gfinish fails unless --offline, which
# squashes into local main, pushes nothing, and prints the follow-up commands.
setup offline
change feat/k
git remote set-url origin "$tmp/missing.git"
if "$gfinish" -y -m feat/k > "$tmp/out" 2>&1; then fail 'feat/k: unreachable origin accepted'; fi
[[ $(git log -1 --format=%s main) == base && $(git branch --show-current) == feat/k ]] ||
  fail 'feat/k: failed gfinish changed state'
"$gfinish" -y --offline -m feat/k > "$tmp/out" 2>&1 || fail 'feat/k: offline gfinish failed'
[[ $(git log -1 --format=%s main) == feat/k ]] || fail 'feat/k: local main'
[[ -z $(git branch --list feat/k) ]] || fail 'feat/k: branch left'
[[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s main) == base ]] || fail 'feat/k: main pushed'
[[ -n $(git --git-dir="$tmp/origin.git" branch --list feat/k) ]] || fail 'feat/k: remote branch deleted'
grep -qx '  git push origin main' "$tmp/out" || fail 'feat/k: push command not printed'
grep -qx '  git push origin --delete feat/k' "$tmp/out" || fail 'feat/k: delete command not printed'

# A second offline run builds on the unpushed squash left on main.
git switch -q -c feat/l main
printf 'l\n' >> file
git commit -qam feat/l
"$gfinish" -y --offline -m feat/l > "$tmp/out" 2>&1 || fail 'feat/l: offline gfinish on unpushed main failed'
[[ $(git log -2 --format=%s main) == $'feat/l\nfeat/k' ]] || fail 'feat/l: local main'
[[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s main) == base ]] || fail 'feat/l: main pushed'

# Online, main ahead of origin/main still stops before anything changes.
git remote set-url origin "$tmp/origin.git"
change feat/m
before=$(git rev-parse main)
if "$gfinish" -y -m feat/m > "$tmp/out" 2>&1; then fail 'feat/m: main ahead of origin accepted'; fi
grep -q 'Local main has commits not on origin/main' "$tmp/out" || fail 'feat/m: message'
[[ $(git rev-parse main) == "$before" && $(git branch --show-current) == feat/m ]] || fail 'feat/m: state changed'

# --- Default branch resolution: online origin HEAD overrides a stale cache.
setup master master
git branch main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
before_main=$(git rev-parse main)
git worktree add -q -b feat/master "$tmp/feature" master
(
  cd "$tmp/feature"
  printf 'master change\n' >> file
  git commit -qam 'master change'
  finish 'master squash'
)
[[ ! -e $tmp/feature && $(git log -1 --format=%s master) == 'master squash' ]] || fail 'master: worktree or local target'
[[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s master) == 'master squash' ]] || fail 'master: remote target'
[[ $(git rev-parse main) == "$before_main" ]] || fail 'master: main changed'
grep -qx 'Finished: feat/master -> master' "$tmp/out" || fail 'master: result message'
if "$gfinish" -y > "$tmp/out" 2>&1; then fail 'master: default branch accepted'; fi
grep -qx 'Run gfinish from a feature branch.' "$tmp/out" || fail 'master: default branch rejection'

# A renamed default must never be deleted as the feature's old remote name.
git branch -m feat/renamed-master
git branch --no-track master origin/master
printf 'renamed\n' >> file
git commit -qam renamed
finish 'renamed master'
on_origin master || fail 'master: old default name deleted'
grep -qx 'Kept origin/master (old name of feat/renamed-master): it is master.' "$tmp/out" || fail 'master: old name protection'

# The default can have another name, and main can be a feature branch.
setup custom-default trunk
git switch -q -c main
printf 'custom\n' >> file
git commit -qam custom
finish 'custom squash'
[[ $(git branch --show-current) == trunk ]] || fail 'trunk: did not switch to default'
[[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s trunk) == 'custom squash' ]] || fail 'trunk: remote target'

# An origin with no advertised symbolic HEAD must not fall back to main.
setup unresolved
git switch -q -c feat/unresolved
printf 'unresolved\n' >> file
git commit -qam unresolved
before=$(git rev-parse main)
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/missing
if "$gfinish" -y > "$tmp/out" 2>&1; then fail 'unresolved: online default guessed'; fi
grep -qx 'Could not resolve origin default branch.' "$tmp/out" || fail 'unresolved: online message'
[[ $(git rev-parse main) == "$before" && $(git branch --show-current) == feat/unresolved ]] || fail 'unresolved: online state changed'

# Offline master uses cached HEAD without making any network-capable calls.
setup offline-master master
git switch -q -c feat/offline-master
printf 'offline master\n' >> file
git commit -qam 'offline master'
git push -q origin feat/offline-master
git remote set-url origin "$tmp/missing.git"
mkdir "$tmp/no-network"
real_git=$(command -v git)
cat > "$tmp/no-network/git" << 'NO_NETWORK'
#!/usr/bin/env bash
case $1 in
fetch | ls-remote | push) echo "Unexpected network command: $*" >&2; exit 99 ;;
esac
exec "$REAL_GIT" "$@"
NO_NETWORK
chmod +x "$tmp/no-network/git"
REAL_GIT=$real_git PATH="$tmp/no-network:$PATH" "$gfinish" -y --offline -m 'offline master squash' > "$tmp/out" 2>&1 || fail 'offline master: gfinish failed'
[[ $(git log -1 --format=%s master) == 'offline master squash' ]] || fail 'offline master: local target'
[[ $(git --git-dir="$tmp/origin.git" log -1 --format=%s master) == base ]] || fail 'offline master: pushed'
[[ -n $(git --git-dir="$tmp/origin.git" branch --list feat/offline-master) ]] || fail 'offline master: remote branch deleted'
grep -qx '  git push origin master' "$tmp/out" || fail 'offline master: push followup'
grep -qx '  git push origin --delete feat/offline-master' "$tmp/out" || fail 'offline master: delete followup'
grep -q "git pull --rebase origin master' on master" "$tmp/out" || fail 'offline master: rebase followup'

# Missing cached HEAD or target refs fail before consuming approval or merging.
git switch -q -c feat/missing-cache
printf 'missing cache\n' >> file
git commit -qam 'missing cache'
mkdir "$tmp/approval"
marker=$tmp/approval/$(printf %s "$(realpath "$tmp/repo")" | sha256sum | cut -c1-64)
touch "$marker"
before=$(git rev-parse master)
git symbolic-ref --delete refs/remotes/origin/HEAD
if REAL_GIT=$real_git PATH="$tmp/no-network:$PATH" AGENT_APPROVAL_DIR="$tmp/approval" "$gfinish" -y --offline > "$tmp/out" 2>&1; then fail 'offline: missing cached HEAD accepted'; fi
grep -qx 'Could not resolve cached origin default branch (origin/HEAD).' "$tmp/out" || fail 'offline: missing cache message'
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
git update-ref -d refs/remotes/origin/master
if REAL_GIT=$real_git PATH="$tmp/no-network:$PATH" AGENT_APPROVAL_DIR="$tmp/approval" "$gfinish" -y --offline > "$tmp/out" 2>&1; then fail 'offline: missing cached target accepted'; fi
grep -qx 'Required default branch ref is unavailable: refs/remotes/origin/master' "$tmp/out" || fail 'offline: missing target message'
[[ -e $marker && $(git rev-parse master) == "$before" && $(git branch --show-current) == feat/missing-cache ]] || fail 'offline: unresolved default changed state or consumed approval'

echo 'PASS: gfinish messages, renamed branches, worktrees, agent approval, offline, and default branches'
