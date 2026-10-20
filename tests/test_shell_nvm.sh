#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nvm_dir="$tmp/nvm"
mkdir -p "$nvm_dir/alias/lts" "$nvm_dir/versions/node/v24.22.0/bin" "$nvm_dir/versions/node/v22.23.3/bin"
# Stub nvm records how it was loaded and invoked.
cat > "$nvm_dir/nvm.sh" << 'NVM'
printf 'source %s\n' "$*" >> "$NVM_DIR/calls"
nvm() { printf 'nvm %s\n' "$*" >> "$NVM_DIR/calls"; }
NVM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run() {
  local shell=$1
  rm -f "$nvm_dir/calls"
  # A stale nvm entry inherited from a parent shell must be replaced.
  env -u NVM_BIN -u NVM_INC NVM_DIR="$nvm_dir" PATH="$nvm_dir/versions/node/v22.23.3/bin:/usr/bin:/bin" \
    "$shell" -c "source '$root/home/.shell.d/nvm.sh'; printf '%s\n%s\n' \"\$PATH\" \"\${NVM_BIN:-}\""
}

for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || {
    echo "SKIP: $shell not installed"
    continue
  }

  # Exact default version: resolved without running nvm's default selection.
  printf 'lts/*\n' > "$nvm_dir/alias/default"
  printf 'lts/krypton\n' > "$nvm_dir/alias/lts/*"
  printf 'v24.22.0\n' > "$nvm_dir/alias/lts/krypton"
  output=$(run "$shell")
  bin="$nvm_dir/versions/node/v24.22.0/bin"
  [[ $(sed -n 1p <<< "$output") == "$bin:/usr/bin:/bin" ]] || fail "$shell: PATH: $output"
  [[ $(sed -n 2p <<< "$output") == "$bin" ]] || fail "$shell: NVM_BIN: $output"
  [[ $(cat "$nvm_dir/calls") == 'source --no-use' ]] || fail "$shell: calls: $(cat "$nvm_dir/calls")"

  # Partial versions keep nvm's own resolution.
  printf '24\n' > "$nvm_dir/alias/default"
  run "$shell" > /dev/null
  [[ $(cat "$nvm_dir/calls") == $'source --no-use\nnvm use --silent default' ]] ||
    fail "$shell: fallback calls: $(cat "$nvm_dir/calls")"
done

echo 'PASS: nvm loads without default selection and activates the default version'
