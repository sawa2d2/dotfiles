#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/bin"
fixture="$tmp/repo"
mkdir -p "$fixture/home"
cp "$root/install" "$fixture/install"
printf '%s\n' '# Test configuration' > "$fixture/home/.bashrc"
git init -q "$fixture"
git -C "$fixture" -c user.name=Test -c user.email=test@example.com commit --allow-empty -qm 'Test fixture'
git -C "$fixture" branch base
git -C "$fixture" branch --set-upstream-to=base > /dev/null
cat > "$tmp/bin/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${3:-} == pull ]]; then
  printf '%s\n' "$*" >> "$HOME/git-pulls"
  exit "${GIT_PULL_STATUS:-0}"
fi
exec /usr/bin/git "$@"
GIT
chmod +x "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"

if GIT_PULL_STATUS=1 bash "$fixture/install" >"$tmp/output" 2>&1; then
  echo 'FAIL: install should stop when git pull fails' >&2
  exit 1
fi
[[ $(cat "$HOME/git-pulls") == "-C $fixture pull" ]]
[[ ! -e "$HOME/.bashrc" ]]

rm "$HOME/git-pulls"
bash "$fixture/install" --dry-run >"$tmp/output"
[[ ! -e "$HOME/git-pulls" ]]
[[ ! -e "$HOME/.bashrc" ]]

GIT_PULL_STATUS=1 bash "$fixture/install" --no-pull --no-nix >"$tmp/output"
[[ ! -e "$HOME/git-pulls" ]]
[[ $(readlink "$HOME/.bashrc") == "$fixture/home/.bashrc" ]]

git -C "$fixture" branch --unset-upstream
rm "$HOME/.bashrc"
GIT_PULL_STATUS=1 bash "$fixture/install" >"$tmp/output"
[[ ! -e "$HOME/git-pulls" ]]
[[ $(readlink "$HOME/.bashrc") == "$fixture/home/.bashrc" ]]
grep -qF 'SKIP: git pull (current branch has no upstream)' "$tmp/output"

# Exercise system argument parsing without touching system destinations.
cat > "$tmp/bin/uname" <<'UNAME'
#!/usr/bin/env bash
echo Darwin
UNAME
chmod +x "$tmp/bin/uname"
GIT_PULL_STATUS=1 bash "$fixture/install" --system >"$tmp/output"
grep -qF 'SKIP: git pull (current branch has no upstream)' "$tmp/output"
GIT_PULL_STATUS=1 bash "$fixture/install" --system --no-pull >"$tmp/output"
GIT_PULL_STATUS=1 bash "$fixture/install" --system --no-pull --dry-run >"$tmp/output"
GIT_PULL_STATUS=1 bash "$fixture/install" --system --dry-run --no-pull >"$tmp/output"
[[ ! -e "$HOME/git-pulls" ]]

echo 'PASS: install stops on pull failure and skips pull without an upstream, during dry-run, or with no-pull'
