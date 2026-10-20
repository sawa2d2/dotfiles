#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git init -q -b main "$TMP/repo"
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email test@example.com
printf 'base\n' > "$TMP/repo/base"
git -C "$TMP/repo" add base
git -C "$TMP/repo" commit -qm base
git clone -q --bare "$TMP/repo" "$TMP/origin.git"
git -C "$TMP/repo" remote add origin "$TMP/origin.git"
git -C "$TMP/repo" push -q -u origin main

git -C "$TMP/repo" switch -qc stale
printf 'one\n' > "$TMP/repo/one"
git -C "$TMP/repo" add one
git -C "$TMP/repo" commit -qm one
printf 'two\n' > "$TMP/repo/two"
git -C "$TMP/repo" add two
git -C "$TMP/repo" commit -qm two
git -C "$TMP/repo" push -q origin stale

git -C "$TMP/repo" switch -q main
git -C "$TMP/repo" merge --squash -q stale >/dev/null
git -C "$TMP/repo" commit -qm 'squash stale'
git -C "$TMP/repo" push -q origin main
git -C "$TMP/repo" push -q origin --delete stale

git -C "$TMP/repo" switch -qc keep
printf 'unique\n' > "$TMP/repo/unique"
git -C "$TMP/repo" add unique
git -C "$TMP/repo" commit -qm unique
git -C "$TMP/repo" switch -q main

preview=$(cd "$TMP/repo" && "$ROOT/bin/git/gprune")
printf '%s\n' "$preview" | grep -q 'WOULD DELETE stale'
if printf '%s\n' "$preview" | grep -q 'WOULD DELETE keep'; then
  echo 'FAIL: unmerged branch selected' >&2
  exit 1
fi
git -C "$TMP/repo" show-ref -q --verify refs/heads/stale

(cd "$TMP/repo" && "$ROOT/bin/git/gprune" -y) >/dev/null
if git -C "$TMP/repo" show-ref -q --verify refs/heads/stale; then
  echo 'FAIL: merged branch not removed' >&2
  exit 1
fi
git -C "$TMP/repo" show-ref -q --verify refs/heads/keep
git -C "$TMP/repo" show-ref -q --verify refs/heads/main

echo 'PASS: dry run and safe squash branch cleanup'
