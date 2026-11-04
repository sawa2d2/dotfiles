#!/usr/bin/env bash
set -euo pipefail
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

base="$main/bin:$(dirname "$(command -v git)"):/usr/bin:/bin"

# Print PATH after each cd; bash updates from PROMPT_COMMAND, so run it as a prompt would.
run() {
  local shell=$1 repos=$2
  local -a flags=(--norc --noprofile)
  # Start outside any repository (the checkout running this test is allowlisted).
  cd "$tmp"
  [[ $shell == zsh ]] && flags=(-f)
  env -i HOME="$tmp" PATH="$base" DOTFILES_WORKTREE_BIN_REPOS="$repos" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
    "$shell" "${flags[@]}" -i -c "
    source '$root/home/.shell.d/path.sh'
    source '$root/home/.shell.d/worktree-bin.sh'
    prompt() { [[ -n \${BASH_VERSION:-} ]] && eval \"\$PROMPT_COMMAND\"; printf '%s\n' \"\$PATH\"; }
    for dir in '$wt/sub' '$wt' '$evil' '$main/sub' '$wt' /; do cd \"\$dir\"; prompt; done
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
done

echo 'PASS: allowlisted worktree bin/ is first on PATH only while inside it'
