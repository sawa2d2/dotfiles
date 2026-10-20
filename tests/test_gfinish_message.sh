#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
gfinish="$repo_root/bin/git/gfinish"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

git init --bare -q "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work"
cd "$tmp/work"
git config user.name 'Gfinish Test'
git config user.email 'gfinish@example.invalid'
git switch -q -c main
printf 'base\n' > file
git add file
git commit -qm base
git push -q -u origin main
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/main

check_finish() {
  local branch=$1 expected=$2
  shift 2
  git switch -q -c "$branch"
  printf '%s\n' "$branch" >> file
  git add file
  git commit -qm change
  "$gfinish" -y "$@" > "$tmp/output"
  [[ $(git branch --show-current) == main ]]
  [[ $(git log -1 --format=%s) == "$expected" ]]
  [[ -z $(git branch --list "$branch") ]]
}

check_finish feat/separator 'Fix: hoge fuga' -- Fix: hoge fuga
check_finish feat/legacy 'Fix: original syntax' -m 'Fix: original syntax'
check_finish feat/default 'feat: default' 

git switch -q -c feat/invalid
if "$gfinish" -y -- > /dev/null 2>&1; then
  echo 'FAIL: empty -- message accepted' >&2
  exit 1
fi
if "$gfinish" -y -m existing -- other > /dev/null 2>&1; then
  echo 'FAIL: ambiguous -m/-- accepted' >&2
  exit 1
fi
if "$gfinish" -y -- '  ' > /dev/null 2>&1; then
  echo 'FAIL: whitespace-only message accepted' >&2
  exit 1
fi

echo 'PASS: gfinish -m, --, default, and invalid arguments'
