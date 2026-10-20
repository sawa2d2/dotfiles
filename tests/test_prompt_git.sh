#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Theme colors are generated and untracked; use visible markers instead.
mkdir -p "$TMP/dot/theme/generated"
cat > "$TMP/dot/theme/generated/bash-prompt.bash" << 'COLORS'
_PROMPT_GIT_CLEAN='<clean>'
_PROMPT_GIT_DIRTY='<dirty>'
_PROMPT_GIT_STAGED='<staged>'
_PROMPT_GIT_MIXED='<mixed>'
_PROMPT_RESET=''
COLORS
sed 's/^/typeset -g /' "$TMP/dot/theme/generated/bash-prompt.bash" > "$TMP/dot/theme/generated/zsh-prompt.zsh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
repo="$TMP/repo"
git init -q -b main "$repo"
echo base > "$repo/file"
git -C "$repo" add file
git -C "$repo" commit -q -m base

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Print the Git part of the prompt for the given shell and directory.
git_part() {
  local shell=$1 dir=$2 prompt
  if [[ $shell == bash ]]; then
    prompt=$(cd "$dir" && DOTPATH="$TMP/dot" bash --norc -c \
      "source '$ROOT/home/.bash.d/prompt.bash'; _prompt_command; printf '%s' \"\$PS1\"")
  else
    prompt=$(cd "$dir" && DOTPATH="$TMP/dot" zsh -f -c \
      "source '$ROOT/home/.zsh.d/prompt.zsh'; _prompt_command_zsh; print -rn -- \"\$PROMPT\"")
  fi
  # Keep only "<color>(branch ...)"; zsh wraps the color as %F{...}.
  prompt=${prompt//%B%F\{/}
  prompt=${prompt//\}/}
  grep -oE '<(clean|dirty|staged|mixed)>\([^)]*\)' <<< "$prompt" || printf 'none'
}

expect() {
  local dir=$1 expected=$2 shell actual
  for shell in bash zsh; do
    command -v "$shell" > /dev/null 2>&1 || continue
    actual=$(git_part "$shell" "$dir")
    [[ $actual == "$expected" ]] || fail "$shell in ${dir#"$TMP"/}: expected '$expected', got '$actual'"
  done
}

expect "$TMP" 'none'
expect "$repo" '<clean>(main)'
echo change >> "$repo/file"
expect "$repo" '<dirty>(main *)'
git -C "$repo" add file
expect "$repo" '<staged>(main +)'
echo again >> "$repo/file"
expect "$repo" '<mixed>(main * +)'
git -C "$repo" commit -q -am second

# Untracked files do not mark the tree dirty.
echo new > "$repo/untracked"
expect "$repo" '<clean>(main)'
rm "$repo/untracked"

# Divergence from the locally known upstream.
git clone -q --bare "$repo" "$TMP/remote.git"
git -C "$repo" remote add origin "$TMP/remote.git"
git -C "$repo" fetch -q origin
git -C "$repo" branch -q --set-upstream-to=origin/main
expect "$repo" '<clean>(main)'
git -C "$repo" commit -q --allow-empty -m ahead
expect "$repo" '<clean>(main +1)'
git -C "$repo" reset -q --hard HEAD~2
expect "$repo" '<clean>(main -1)'
git -C "$repo" commit -q --allow-empty -m diverge
expect "$repo" '<clean>(main +1-1)'

# Detached HEAD shows the abbreviated commit.
git -C "$repo" checkout -q --detach
expect "$repo" "<clean>($(git -C "$repo" rev-parse --short HEAD))"
git -C "$repo" checkout -q main

# Conflicted paths count as both unstaged and staged.
git -C "$repo" checkout -q -b other
echo other > "$repo/file"
git -C "$repo" commit -q -am other
git -C "$repo" checkout -q main
echo main > "$repo/file"
git -C "$repo" commit -q -am main
git -C "$repo" merge -q other > /dev/null 2>&1 || true
expect "$repo" '<mixed>(main +2-1 * +)'

echo 'PASS: prompt Git status matches expected markers in Bash and Zsh'
