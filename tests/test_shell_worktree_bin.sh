#!/usr/bin/env bash
set -euo pipefail
# fakeroot fakes the ownership [[ -O ]] sees, so a clone can belong to another user.
if [[ -z ${FAKEROOTKEY-} ]] && command -v fakeroot > /dev/null 2>&1; then
  exec fakeroot -- bash "${BASH_SOURCE[0]}" "$@"
fi
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

repo() {
  local dir=$1 url=$2
  mkdir -p "$dir/bin" "$dir/sub"
  git -C "$dir" init -q
  git -C "$dir" remote add origin "$url"
}

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
main="$tmp/local-ai"
wt="$tmp/worktrees/local-ai/feature"
evil="$tmp/evil"
repo "$main" git@github.com:sawa2d2/local-ai.git
git -C "$main" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$main" worktree add -q -b feature "$wt"
# Untracked bin/ is not checked out into the worktree; create it like a real one.
mkdir -p "$wt/bin" "$wt/sub"
repo "$evil" https://github.com/someone/evil
foreign="$tmp/foreign"
foreign_bin="$tmp/foreign-bin"
repo "$foreign" git@github.com:sawa2d2/local-ai.git
repo "$foreign_bin" git@github.com:sawa2d2/local-ai.git
[[ -z ${FAKEROOTKEY-} ]] || chown 4242 "$foreign" "$foreign_bin/bin"

base="$main/bin:$(dirname "$(command -v git)"):/usr/bin:/bin"

# Print PATH after each cd; bash updates from PROMPT_COMMAND, so run it as a prompt would.
run() {
  local shell=$1 repos=$2 var dirs
  local -a flags=(--norc --noprofile) keep=()
  shift 2
  (($#)) || set -- "$wt/sub" "$wt" "$evil" "$main/sub" "$wt" /
  dirs=$(printf " '%s'" "$@")
  # Pass fakeroot through env -i.
  for var in FAKEROOTKEY LD_LIBRARY_PATH LD_PRELOAD; do
    [[ -n ${!var-} ]] && keep+=("$var=${!var}")
  done
  # Start outside any repository (the checkout running this test is allowlisted).
  cd "$tmp"
  [[ $shell == zsh ]] && flags=(-f)
  # safe.directory: git must not hide a foreign clone's origin, so only the hook rejects it.
  env -i "${keep[@]}" HOME="$tmp" PATH="$base" DOTFILES_WORKTREE_BIN_REPOS="$repos" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*' \
    "$shell" "${flags[@]}" -i -c "
    source '$root/home/.shell.d/path.sh'
    source '$root/home/.shell.d/worktree-bin.sh'
    prompt() { [[ -n \${BASH_VERSION:-} ]] && eval \"\$PROMPT_COMMAND\"; printf '%s\n' \"\$PATH\"; }
    for dir in$dirs; do cd \"\$dir\"; prompt; done
    source '$root/home/.shell.d/worktree-bin.sh'
    printf 'hook=%s\n' \"\${PROMPT_COMMAND:-}\"" 2> /dev/null
}

for shell in bash zsh; do
  command -v "$shell" > /dev/null 2>&1 || {
    echo "SKIP: $shell not installed"
    continue
  }

  expected="$wt/bin:$base
$wt/bin:$base
$base
$base
$wt/bin:$base
$base"
  out=$(run "$shell" '')
  [[ $(sed '$d' <<< "$out") == "$expected" ]] || fail "$shell: $out"
  # Re-sourcing must not register the bash hook twice.
  [[ $shell == zsh || $(tail -n 1 <<< "$out") == hook=_dotfiles_worktree_bin_update ]] || fail "$shell PROMPT_COMMAND: $out"

  # Extending the allowlist trusts another repository.
  out=$(run "$shell" github.com/someone/evil)
  [[ $(sed -n 3p <<< "$out") == "$evil/bin:$base" ]] || fail "$shell extended: $out"

  # Another user's clone of an allowlisted repository is not trusted.
  if [[ -n ${FAKEROOTKEY-} ]]; then
    out=$(run "$shell" '' "$foreign/sub" "$foreign_bin/sub")
    [[ $out == "$base
$base"* ]] || fail "$shell foreign owner: $out"
  else
    echo "SKIP: $shell foreign owner (fakeroot not installed)"
  fi
done

echo 'PASS: allowlisted worktree bin/ is first on PATH only while inside it'
