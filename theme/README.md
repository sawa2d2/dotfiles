# Theme

## Target files

- `.tmux.conf`
- `.bash.d/prompt.bash`
- `.vimrc`
- `theme/generated/fzf.sh`

## Usage

```bash
./theme/sync teal     # Save an explicit global color
./theme/sync         # Reapply the saved color (or teal on first install)
```

## Allowed options

| Theme    | Accent    | Selected  |
| -------- | --------- | --------- |
| `teal`   | `#1bafb5` | `#79bfc0` |
| `violet` | `#9180d8` | `#b1a5e5` |
| `orange` | `#d98d50` | `#e9b888` |
| `blue`   | `#1192e8` | `#75b8ed` |
| `red`    | `#da4e58` | `#ed9298` |
| `green`  | `#24a86a` | `#82cfaa` |


## tmux session color

Inside tmux, run `tcolor violet` to change only the current session's status bar.
The same six variants are supported. Run `tcolor default` to inherit the
current global color again. New sessions inherit the global color set by
`./theme/sync <variant>` unless explicitly overridden.
`tsave` stores the session's variant by name and `tload` reapplies it, so a
restored session follows later theme color changes.

The Bash and Zsh `fzf` functions read tmux's session accent and selected colors
at launch and override only fzf's highlight, prompt, pointer and selection
background. Other fzf colors remain global. Commands that execute the fzf
binary directly (outside the shell function) use the global theme.

The selection is saved in `${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme` and is preserved by subsequent `./install` runs. On first upgrade, an existing generated tmux accent is detected and retained when no saved selection exists. `./install --dry-run` does not change the selection.
