#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/repo/theme" "$tmp/home"
cp "$repo/theme/sync" "$repo/theme/colors.sh" "$tmp/repo/theme/"
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/home/.config"

# Uses a disposable repository and home, never the real user's settings.
cd "$tmp/repo"
bash theme/sync >/dev/null
[[ $(cat "$XDG_CONFIG_HOME/dotfiles/theme") == teal ]]
grep -Fq "set -g @color_accent '#1bafb5'" theme/generated/tmux.theme.conf

bash theme/sync violet >/dev/null
[[ $(cat "$XDG_CONFIG_HOME/dotfiles/theme") == violet ]]
grep -Fq "set -g @color_accent '#9180d8'" theme/generated/tmux.theme.conf

bash theme/sync >/dev/null
[[ $(cat "$XDG_CONFIG_HOME/dotfiles/theme") == violet ]]
grep -Fq "set -g @color_accent '#9180d8'" theme/generated/tmux.theme.conf

# Migrate a pre-existing theme when no preference file exists.
rm "$XDG_CONFIG_HOME/dotfiles/theme"
bash theme/sync >/dev/null
[[ $(cat "$XDG_CONFIG_HOME/dotfiles/theme") == violet ]]

# Invalid explicit colors fail without overwriting the persisted preference.
if bash theme/sync nonexistent >/dev/null 2>&1; then
  echo 'Unexpected success for invalid theme' >&2
  exit 1
fi
[[ $(cat "$XDG_CONFIG_HOME/dotfiles/theme") == violet ]]
echo 'theme persistence: PASS'
