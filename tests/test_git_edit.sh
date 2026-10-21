#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export PATH="$ROOT/bin/git:$PATH" GIT_CONFIG_GLOBAL=/dev/null

# Stub editor: record its working directory and one argument per line.
cat > "$TMP/editor" << 'EOF'
#!/bin/sh
pwd > "$EDITOR_LOG"
printf '%s\n' "$@" >> "$EDITOR_LOG"
EOF
chmod +x "$TMP/editor"
export GIT_EDITOR="$TMP/editor" EDITOR_LOG="$TMP/log"

git init -q -b main "$TMP/repo"
cd "$TMP/repo"
git config user.name Test
git config user.email test@example.com
mkdir sub
echo base > base
echo gone > gone
echo keep > sub/keep
git add .
git commit -qm base
git clone -q --bare . "$TMP/origin.git"
git remote add origin "$TMP/origin.git"
git fetch -q origin

git switch -q -c feature
echo committed > committed
git rm -q gone
git add committed
git commit -qm committed

# origin/main moves on; its files must not be opened.
git clone -q "$TMP/origin.git" "$TMP/other"
echo upstream > "$TMP/other/upstream"
git -C "$TMP/other" add upstream
git -C "$TMP/other" -c user.name=Test -c user.email=test@example.com commit -qm upstream
git -C "$TMP/other" push -q origin main
git fetch -q origin

echo staged > staged
git add staged
echo changed >> sub/keep
echo 'with space' > 'un tracked'
echo ignored > ignored.log
echo '*.log' > .git/info/exclude

# Run from a subdirectory: paths must still resolve from the top level.
(cd sub && git edit)
[[ $(head -n 1 "$EDITOR_LOG") == "$(pwd -P)" ]] || {
  echo "FAIL: editor did not start at the top level" >&2
  exit 1
}
[[ $(tail -n +2 "$EDITOR_LOG" | sort) == "$(printf '%s\n' committed staged sub/keep 'un tracked')" ]] || {
  echo 'FAIL: unexpected files:' >&2
  cat "$EDITOR_LOG" >&2
  exit 1
}

# Vim and Neovim: four vertical splits per tab, the rest in following tabs.
if command -v nvim > /dev/null; then
  touch f1 f2
  # VimEnter fires after the -c layout command, so the dump sees the result.
  cat > "$TMP/dump.vim" << 'EOF'
autocmd VimEnter * call writefile(map(range(1, tabpagenr('$')),
      \ {_, t -> join(map(tabpagebuflist(t), {_, b -> bufname(b)}), ',')}),
      \ $LAYOUT_LOG) | qa!
EOF
  LAYOUT_LOG="$TMP/layout" GIT_EDITOR="nvim --headless -u NONE -i NONE --cmd 'source $TMP/dump.vim'" git edit
  [[ $(cat "$TMP/layout") == "$(printf '%s\n' committed,staged,sub/keep,f1 'f2,un tracked')" ]] || {
    echo 'FAIL: unexpected nvim layout:' >&2
    cat "$TMP/layout" >&2
    exit 1
  }
  rm f1 f2
else
  echo 'SKIP: nvim not found; layout not checked' >&2
fi

# Nothing changed since the merge base: report it without starting the editor.
git stash -q -u
git switch -q main
rm -f "$EDITOR_LOG"
out=$(git edit 2>&1)
[[ $out == 'No changed files.' && ! -e $EDITOR_LOG ]]

status=0
git edit extra 2> /dev/null || status=$?
((status == 2))

echo 'PASS: git edit opens files changed on the branch, including untracked'
