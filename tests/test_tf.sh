#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Stub binaries print which one ran; only the tested ones are on PATH.
mkdir "$TMP/tofu" "$TMP/terraform"
for name in tofu terraform; do
  printf '#!/bin/sh\necho "%s $*"\n' "$name" > "$TMP/$name/$name"
  chmod +x "$TMP/$name/$name"
done
# PATH holds only the scripts, the stubs and bash (for the scripts'
# `#!/usr/bin/env bash`), so a real tofu or terraform never runs.
mkdir "$TMP/shell"
ln -s "$(command -v bash)" "$TMP/shell/bash"
run() {
  local dirs=$1
  shift
  env -u TF_BIN PATH="$ROOT/bin/terraform:$dirs:$TMP/shell" "$@"
}
fail() {
  printf 'FAIL: %s\n--- output ---\n%s\n' "$1" "${out:-}" >&2
  exit 1
}
out=$(run "$TMP/tofu:$TMP/terraform" tf version)
[[ $out == 'tofu version' ]] || fail 'tofu preferred when installed'
out=$(run "$TMP/terraform" tf plan)
[[ $out == 'terraform plan' ]] || fail 'terraform fallback'
out=$(TF_BIN=terraform env PATH="$ROOT/bin/terraform:$TMP/tofu:$TMP/terraform:$TMP/shell" tf apply -auto-approve)
[[ $out == 'terraform apply -auto-approve' ]] || fail 'TF_BIN forces terraform'
# The shortcuts go through tf.
out=$(run "$TMP/tofu" tff -recursive)
[[ $out == 'tofu fmt -recursive' ]] || fail 'tff uses tf'
out=$(run "$TMP/tofu" tfp)
[[ $out == 'tofu plan' ]] || fail 'tfp uses tf'

echo 'PASS: tf runs OpenTofu when installed and Terraform otherwise'
