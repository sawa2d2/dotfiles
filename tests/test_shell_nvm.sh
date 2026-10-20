#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

nvm_dir="$tmp/nvm"
mkdir -p "$nvm_dir/alias/lts"
# Lexical order differs from version order (v24.9.0 < v24.22.0, v9 < v25).
for version in v9.0.0 v22.23.3 v24.9.0 v24.22.0 v25.8.2; do
  mkdir -p "$nvm_dir/versions/node/$version/bin"
done
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

# Check which Node.js version the default alias activates.
expect_default() {
  local shell=$1 alias=$2 version=$3 output bin
  printf 'lts/krypton\n' > "$nvm_dir/alias/lts/*"
  printf 'v24.22.0\n' > "$nvm_dir/alias/lts/krypton"
  printf '%s\n' "$alias" > "$nvm_dir/alias/default"
  output=$(run "$shell")
  if [[ $version == fallback ]]; then
    [[ $(cat "$nvm_dir/calls") == $'source --no-use\nnvm use --silent default' ]] ||
      fail "$shell $alias: expected nvm fallback, calls: $(cat "$nvm_dir/calls")"
    return
  fi
  bin="$nvm_dir/versions/node/$version/bin"
  [[ $(sed -n 1p <<< "$output") == "$bin:/usr/bin:/bin" ]] || fail "$shell $alias: PATH: $output"
  [[ $(sed -n 2p <<< "$output") == "$bin" ]] || fail "$shell $alias: NVM_BIN: $output"
  [[ $(cat "$nvm_dir/calls") == 'source --no-use' ]] || fail "$shell $alias: calls: $(cat "$nvm_dir/calls")"
}

for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || {
    echo "SKIP: $shell not installed"
    continue
  }

  # Resolved without running nvm's default selection.
  expect_default "$shell" 'lts/*' v24.22.0
  expect_default "$shell" v22.23.3 v22.23.3
  expect_default "$shell" node v25.8.2
  expect_default "$shell" stable v25.8.2
  expect_default "$shell" 24 v24.22.0
  expect_default "$shell" v24 v24.22.0
  expect_default "$shell" 24.9 v24.9.0
  expect_default "$shell" 9 v9.0.0

  # Anything else keeps nvm's own resolution.
  expect_default "$shell" system fallback
  expect_default "$shell" 23 fallback
done

echo 'PASS: nvm loads without default selection and activates the default version'
