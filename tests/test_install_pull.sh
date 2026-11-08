#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/bin"
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

if GIT_PULL_STATUS=1 bash "$root/install" >"$tmp/output" 2>&1; then
  echo 'FAIL: install should stop when git pull fails' >&2
  exit 1
fi
[[ $(cat "$HOME/git-pulls") == "-C $root pull" ]]
[[ ! -e "$HOME/.bashrc" ]]

rm "$HOME/git-pulls"
bash "$root/install" --dry-run >"$tmp/output"
[[ ! -e "$HOME/git-pulls" ]]
echo 'PASS: install pulls the checked-out branch before changes, stops on pull failure, and skips pull during dry-run'
