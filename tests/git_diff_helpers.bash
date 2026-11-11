# Shared fixtures for the diff command interface tests.
setup_diff_repo() {
  git init -q -b main "$TMP/repo"
  cd "$TMP/repo" || return
  git config user.name Test
  git config user.email test@example.com
  echo base > base
  git add base
  git commit -qm base
  echo first > first
  git add first
  git commit -qm first
  echo second > second
  git add second
  git commit -qm second
  echo changed >> base
  echo untracked > untracked
  echo dash > ./-p
  mkdir sub
  echo nested > sub/file
  git add sub/file ./-p
  git commit -qm nested
  echo modified >> sub/file
  echo modified >> ./-p
  echo staged > staged
  git add staged
}

# A real terminal makes Git's pager decision observable, including outer pagers.
tty_diff() {
  python3 - "$@" << 'PY'
import errno
import os
import pty
import subprocess
import sys
master, slave = pty.openpty()
process = subprocess.Popen(sys.argv[1:], stdout=slave, stderr=slave)
os.close(slave)
while True:
    try:
        data = os.read(master, 65536)
    except OSError as error:
        if error.errno == errno.EIO:
            break
        raise
    if not data:
        break
    sys.stdout.buffer.write(data)
os.close(master)
sys.exit(process.wait())
PY
}

check_display() {
  local command=$1
  shift
  cat > "$TMP/pager" << 'SH'
#!/bin/sh
echo pager >> "$PAGER_LOG"
cat
SH
  cat > "$TMP/external" << 'SH'
#!/bin/sh
echo EXTERNAL_DIFF
SH
  chmod +x "$TMP/pager" "$TMP/external"
  export PAGER_LOG="$TMP/pager.log" GIT_PAGER="$TMP/pager"
  export GIT_EXTERNAL_DIFF="$TMP/external"
  git config color.ui always
  : > "$PAGER_LOG"
  local plain normal
  plain=$(tty_diff git "$command" -p "$@")
  [[ ! -s $PAGER_LOG && $plain == *'diff --git'* ]]
  [[ $plain != *EXTERNAL_DIFF* && $plain != *$'\e['* ]]
  normal=$(tty_diff git "$command" "$@")
  [[ -s $PAGER_LOG && $normal == *EXTERNAL_DIFF* ]]
  if [[ $command == dfm ]]; then
    [[ $(wc -l < "$PAGER_LOG") -eq 1 ]]
  fi
  unset GIT_EXTERNAL_DIFF
  git config color.ui auto
  export GIT_PAGER=cat
  # Git optimizes the cat pager away; this must not recurse.
  tty_diff git "$command" "$@" > /dev/null
}
