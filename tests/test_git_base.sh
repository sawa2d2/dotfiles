#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL=/dev/null

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "$out" >&2
  exit 1
}
commit() { git commit -q --allow-empty -m "$1"; }
short() { git rev-parse --short "$1"; }

git init -q -b main "$TMP/repo"
cd "$TMP/repo"
git config user.name Test
git config user.email test@example.com

# main -> dev1 -> dev2 -> dev3; dev1 moves on after dev2 forks.
commit m1
git switch -q -c dev1
commit d1
git switch -q -c dev2
commit d2
commit d2b
git switch -q -c dev3
commit d3
git switch -q dev1
commit d1-later
git switch -q dev2

out=$(git base)
[[ $(sed -n 1p <<< "$out") == 'Branch: dev2' ]] || fail 'branch line'
[[ $(sed -n 2p <<< "$out") == "Created at: $(short dev1~1) d1 (branch: Created from HEAD)" ]] ||
  fail 'creation commit from the reflog'
# Nearest first; descendants (dev3) and the branch itself are not candidates.
[[ $(sed -n '4,$p' <<< "$out") == "$(printf '  %s\n' \
  "dev1  2 commits since $(short dev1~1) (matches creation)" \
  "main  3 commits since $(short main)")" ]] || fail 'candidates'

# A branch name selects another branch; the current one does not matter.
out=$(git base dev1)
[[ $(sed -n 1p <<< "$out") == 'Branch: dev1' ]] || fail 'explicit branch'
[[ $(sed -n '4,$p' <<< "$out") == "  main  2 commits since $(short main) (matches creation)" ]] ||
  fail 'explicit branch candidates'

# A new branch without commits is contained by every branch at or past it.
git switch -q -c fresh
out=$(git base)
[[ $(sed -n '4,$p' <<< "$out") == "$(printf '  %s\n' \
  "dev2  0 commits since $(short dev2) (matches creation)" \
  "dev3  0 commits since $(short dev2) (matches creation)" \
  "dev1  2 commits since $(short dev1~1)" \
  "main  3 commits since $(short main)")" ]] || fail 'branch without commits'
git switch -q dev2
git branch -q -D fresh

# Without its own creation entry, children are still recognized by theirs.
git reflog expire --expire=all refs/heads/dev1
out=$(git base dev1)
[[ $(sed -n '4,$p' <<< "$out") == "  main  2 commits since $(short main)" ]] ||
  fail 'children by their creation entries'

# Without a creation entry the commit is unknown, but candidates remain.
git reflog expire --expire=all --all
out=$(git base)
[[ $(sed -n 2p <<< "$out") == 'Created at: unknown (no creation entry in the reflog)' ]] ||
  fail 'expired reflog'
[[ $(sed -n 4p <<< "$out") == "  dev1  2 commits since $(short dev1~1)" ]] || fail 'candidates without reflog'

# The only branch has nothing to compare with.
git init -q -b main "$TMP/lonely"
git -C "$TMP/lonely" -c user.name=Test -c user.email=test@example.com commit -q --allow-empty -m only
out=$(git -C "$TMP/lonely" base)
[[ $(sed -n 3p <<< "$out") == 'Candidates: none' ]] || fail 'no candidates'

# Squash-merge workflow: old branches never rejoin main and the local main is
# stale; origin/main is the reference, so neither shows up.
git init -q -b main "$TMP/squash"
cd "$TMP/squash"
git config user.name Test
git config user.email test@example.com
commit m0
git clone -q --bare . "$TMP/squash-origin.git"
git remote add origin "$TMP/squash-origin.git"
for i in 1 2 3; do
  git switch -q -c "old$i" main
  commit "o$i"
  git switch -q main
  git merge -q --squash "old$i" > /dev/null
  commit "squash old$i"
done
git push -q origin main
git fetch -q origin
git switch -q -c dev main~2
commit dev1
git branch -q -f main main~2
out=$(git base)
[[ $(sed -n '4,$p' <<< "$out") == "  origin/main  1 commit since $(short dev~1) (matches creation)" ]] ||
  fail 'squash workflow before mainmerge'

# After merging origin/main, only this branch's own commits count.
git merge -q --no-edit origin/main
out=$(git base)
[[ $(sed -n '4,$p' <<< "$out") == "  origin/main  1 commit since $(short origin/main)" ]] ||
  fail 'squash workflow after mainmerge'

# A parent that forked later than main did is still a candidate, and nearer.
git switch -q -c child
commit c1
out=$(git base)
[[ $(sed -n '4,$p' <<< "$out") == "$(printf '  %s\n' \
  "dev  1 commit since $(short dev) (matches creation)" \
  "origin/main  2 commits since $(short origin/main)")" ]] || fail 'stacked branch with origin'

# Long lists are cut down to the nearest five.
git init -q -b main "$TMP/many"
cd "$TMP/many"
git config user.name Test
git config user.email test@example.com
commit m0
for i in 1 2 3 4 5 6 7; do
  git switch -q -c "b$i" main
  commit "b$i"
done
git switch -q -c target main
commit t1
out=$(git base)
[[ $(sed -n '4,$p' <<< "$out" | wc -l) == 6 && $(tail -n 1 <<< "$out") == '  ... and 3 more' ]] ||
  fail 'limit'
cd "$TMP/repo"

# Errors: detached HEAD without a name, unknown branch, extra arguments.
git switch -q --detach
status=0
out=$(git base 2>&1) || status=$?
((status == 1)) || fail 'detached HEAD'
status=0
out=$(git base nope 2>&1) || status=$?
((status == 1)) || fail 'unknown branch'
status=0
out=$(git base a b 2>&1) || status=$?
((status == 2)) || fail 'usage'

echo 'PASS: git base shows the creation commit and nearest branches'
