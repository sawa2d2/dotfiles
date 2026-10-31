#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
# Never let inherited NVM_DIR point tests at a real installation.
export NVM_DIR="$HOME/.nvm"
mkdir -p "$HOME" "$tmp/bin"
cat > "$tmp/bin/git" << 'GIT'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$HOME/git-calls"
[[ $1 == clone ]] || exit 1
destination="${!#}"
mkdir -p "$destination"
cat > "$destination/nvm.sh" <<'NVM'
nvm() {
  if [[ ${1:-} == --version ]]; then
    printf '%s\n' 0.40.8
  else
    return 1
  fi
}
NVM
GIT
chmod +x "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"

bash "$root/scripts/install-nvm" --dry-run
[[ ! -e "$HOME/.nvm" && ! -e "$HOME/git-calls" ]]

bash "$root/scripts/install-nvm"
[[ -s "$HOME/.nvm/nvm.sh" ]]
grep -q 'v0.40.8' "$HOME/git-calls"
lines=$(wc -l < "$HOME/git-calls")
bash "$root/scripts/install-nvm"
[[ $(wc -l < "$HOME/git-calls") == "$lines" ]]

rm -rf "$HOME/.nvm"
mkdir "$HOME/.nvm"
echo keep > "$HOME/.nvm/custom"
if bash "$root/scripts/install-nvm"; then
  echo "FAIL: invalid nvm installation should be rejected" >&2
  exit 1
fi
[[ -f "$HOME/.nvm/custom" ]]
[[ $(wc -l < "$HOME/git-calls") == "$lines" ]]

# A tiny nvm.sh file is not sufficient evidence of a real install.
rm -rf "$NVM_DIR"
mkdir "$NVM_DIR"
printf '# stub\n' > "$NVM_DIR/nvm.sh"
if bash "$root/scripts/install-nvm"; then
  echo "FAIL: stub nvm.sh should be rejected" >&2
  exit 1
fi
[[ $(wc -l < "$HOME/git-calls") == "$lines" ]]
echo 'PASS: isolated nvm dry-run, install, existing directory and stub rejection'
