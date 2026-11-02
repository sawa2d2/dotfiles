#!/usr/bin/env bash
# wiki clones <origin without .git>.wiki.git into .wiki at the top level,
# whatever the host or URL form.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null

fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "$(cat "$TMP/out" 2> /dev/null)" >&2
  exit 1
}

# Stub git clone only; everything else is the real git.
mkdir "$TMP/bin"
cat > "$TMP/bin/git" << EOF
#!/usr/bin/env bash
if [[ \$1 == clone ]]; then
  printf '%s\n' "\$*" > "$TMP/clone"
  exit 0
fi
exec $(command -v git) "\$@"
EOF
chmod +x "$TMP/bin/git"

git init -q "$TMP/repo"
mkdir "$TMP/repo/sub"
cd "$TMP/repo/sub"
top=$(git rev-parse --show-toplevel)

check() {
  git remote set-url origin "$1" 2> /dev/null || git remote add origin "$1"
  PATH="$TMP/bin:$PATH" bash "$ROOT/bin/git/wiki" > "$TMP/out" 2>&1 || fail "$1: wiki failed"
  [[ $(cat "$TMP/clone") == "clone $2 $top/.wiki" ]] || fail "$1: cloned $(cat "$TMP/clone")"
}

check git@github.com:owner/repo.git git@github.com:owner/repo.wiki.git
check https://github.com/owner/repo https://github.com/owner/repo.wiki.git
check https://ghe.example.com/owner/repo.git https://ghe.example.com/owner/repo.wiki.git
check ssh://git@gitlab.example.com:2222/group/sub/project.git ssh://git@gitlab.example.com:2222/group/sub/project.wiki.git
check https://gitlab.com/group/project/ https://gitlab.com/group/project.wiki.git

git remote remove origin
if PATH="$TMP/bin:$PATH" bash "$ROOT/bin/git/wiki" > "$TMP/out" 2>&1; then fail 'no origin accepted'; fi
grep -q 'Origin remote is required' "$TMP/out" || fail 'no origin: message'

echo 'PASS: wiki derives the wiki URL from origin for any host'
