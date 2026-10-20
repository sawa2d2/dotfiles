#!/usr/bin/env bash
# The shell git wrapper prunes squash-merged branches after fetch and pull.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Build a clone whose branch "stale" was squash-merged and deleted on origin.
setup() {
  local dir=$1
  git init -q -b main "$dir/seed"
  git -C "$dir/seed" config user.name Test
  git -C "$dir/seed" config user.email test@example.com
  printf 'base\n' > "$dir/seed/base"
  git -C "$dir/seed" add base
  git -C "$dir/seed" commit -qm base
  git clone -q --bare "$dir/seed" "$dir/origin.git"
  git clone -q "$dir/origin.git" "$dir/repo"
  git -C "$dir/repo" config user.name Test
  git -C "$dir/repo" config user.email test@example.com
  git -C "$dir/repo" switch -qc stale
  printf 'one\n' > "$dir/repo/one"
  git -C "$dir/repo" add one
  git -C "$dir/repo" commit -qm one
  git -C "$dir/repo" push -q origin stale
  git -C "$dir/repo" switch -q main

  # Squash-merge from another clone so the local main is behind origin.
  git clone -q "$dir/origin.git" "$dir/other"
  git -C "$dir/other" config user.name Test
  git -C "$dir/other" config user.email test@example.com
  git -C "$dir/other" merge --squash -q origin/stale > /dev/null
  git -C "$dir/other" commit -qm 'squash stale'
  git -C "$dir/other" push -q origin main
  git -C "$dir/other" push -q origin --delete stale
}

run() {
  local shell=$1 dir=$2 cmd=$3
  (cd "$dir/repo" && env DOTPATH="$ROOT" PATH="$ROOT/bin/git:/usr/bin:/bin" \
    "$shell" -c "source '$ROOT/home/.shell.d/git.sh'; $cmd" 2>&1)
}

for shell in bash zsh; do
  command -v "$shell" > /dev/null || fail "$shell not found"
  for cmd in 'git fetch -q' 'git pull -q'; do
    dir="$TMP/$shell-${cmd// /_}"
    mkdir -p "$dir"
    setup "$dir"
    output=$(run "$shell" "$dir" "$cmd") || fail "$shell: '$cmd' failed: $output"
    git -C "$dir/repo" show-ref -q --verify refs/heads/stale &&
      fail "$shell: '$cmd' kept stale branch"
    [[ $output == *'DELETE stale'* ]] || fail "$shell: '$cmd' did not report deletion: $output"
  done

  # Other subcommands and failed commands must not prune.
  dir="$TMP/$shell-status"
  mkdir -p "$dir"
  setup "$dir"
  run "$shell" "$dir" 'git status -s; git fetch --no-such-option' > /dev/null || true
  git -C "$dir/repo" show-ref -q --verify refs/heads/stale ||
    fail "$shell: pruned without a successful fetch or pull"

  # The wrapper preserves git's exit status.
  run "$shell" "$dir" 'git fetch --no-such-option; echo "status=$?"' |
    grep -q 'status=129' || fail "$shell: exit status not preserved"
done

echo 'PASS: git fetch/pull wrapper prunes squash-merged branches'
