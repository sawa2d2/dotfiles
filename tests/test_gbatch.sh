#!/usr/bin/env bash
# gbatch merges branches into a batch/<timestamp> worktree from main and
# prints their Manual-check trailers; --clean removes batch worktrees.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
gbatch="$repo_root/bin/git/gbatch"
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
printf 'base\n' > file
git add file
git commit -qm base
git remote add origin git@github.com:owner/repo.git

# Commit file $2 with content $3 on a new branch $1 from main; extra
# arguments are added to the commit message.
branch() {
  git switch -q -c "$1" main
  printf '%s\n' "$3" > "$2"
  git add "$2"
  git commit -q -m "$1" "${@:4}"
  git switch -q main
}
branch feat/a a.txt a -m $'Manual-check: open a\nManual-check: close a'
branch feat/b b.txt b
branch feat/c file c

# --- Usage errors.
for args in '' '--force feat/a' '--clean feat/a' '--bogus'; do
  # shellcheck disable=SC2086
  if "$gbatch" $args > /dev/null 2>&1; then fail "accepted: '$args'"; fi
done

# --- Unknown branch: nothing is created.
if "$gbatch" feat/a nope > "$tmp/out" 2>&1; then fail 'unknown branch accepted'; fi
grep -q 'No such branch: nope' "$tmp/out" || fail 'unknown branch: message'
[[ -z $(git branch --list 'batch/*') ]] || fail 'unknown branch: batch branch created'

# --- Success: both branches merged in order, checklist printed.
"$gbatch" feat/a feat/b > "$tmp/out" 2> /dev/null || fail 'gbatch failed'
wt=$(sed -n 's/^Batch worktree: //p' "$tmp/out")
[[ $wt == "$HOME"/worktrees/owner/repo/batch/[0-9]*-[0-9]* ]] || fail "unexpected path: $wt"
[[ $(git -C "$wt" log --merges --format=%s main..) == "Merge branch 'feat/b' into batch/"*$'\n'"Merge branch 'feat/a' into batch/"* ]] ||
  fail 'merges'
[[ $(git config rerere.enabled) == true ]] || fail 'rerere not enabled'
expected="Batch worktree: $wt
Manual checks:
feat/a
  - open a
  - close a
feat/b
  (none)"
[[ $(cat "$tmp/out") == "$expected" ]] || fail 'checklist'

# --- --clean refuses a dirty batch worktree unless --force.
echo dirty >> "$wt/file"
if "$gbatch" --clean > "$tmp/out" 2>&1; then fail 'dirty worktree removed'; fi
[[ -d $wt ]] || fail 'dirty worktree deleted'
"$gbatch" --clean --force > "$tmp/out" 2>&1 || fail '--clean --force failed'
[[ ! -e $wt && -z $(git branch --list 'batch/*') ]] || fail '--clean --force left batch'

# --- Conflict: stops naming the branch and the worktree, which is kept.
branch feat/d file d
if "$gbatch" feat/c feat/d feat/a > "$tmp/out" 2>&1; then fail 'conflict not reported'; fi
wt=$(git worktree list --porcelain | sed -n 's|^worktree \(.*/batch/.*\)|\1|p')
grep -qF "Merge of feat/d conflicted in $wt." "$tmp/out" || fail 'conflict: message'
grep -q 'merge the rest: feat/a$' "$tmp/out" || fail 'conflict: remaining branches'
[[ -n $(git -C "$wt" ls-files --unmerged) ]] || fail 'conflict: not left for resolution'
"$gbatch" --clean --force > /dev/null 2>&1 || fail 'clean after conflict'
[[ -z $(git branch --list 'batch/*') ]] || fail 'batch branch left after clean'

echo 'PASS: gbatch'
