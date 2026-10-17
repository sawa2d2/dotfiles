# dotfiles

## Install dotfiles

The `home/` directory contains dotfiles linked directly into `$HOME`. The repository-level `.editorconfig` stays at the root to configure this repository as well.

Run `./install` from the repository root to install the dotfiles. After switching to this layout from an older checkout, run it immediately to repair symlinks pointing to the previous root paths.

```bash
./install
```

## VS Code User Settings

`./install` links `config.d/vscode/settings.json` to the VS Code User Settings path:

- Ubuntu/Linux: `~/.config/Code/User/settings.json`
- macOS: `~/Library/Application Support/Code/User/settings.json`

If an existing regular `settings.json` is present, it is moved to an available
`settings.json.backup` (or numbered backup) before the shared settings are linked.
Existing settings are **replaced**, not merged; review the backup to retain any
personal preferences. Re-running `./install` updates an existing symlink without
creating another backup.

## Vim / Neovim project sessions

Vim and Neovim automatically restore the previous session for the current
Git worktree or, outside Git, the current directory. Starting with an explicit
file (such as `vim main.py`) restores the same session, then opens that file\nin a new tab while preserving the restored layout.
The Git worktree is determined from the file path when supplied, even if Vim
was launched outside the repository. On exit, sessions save open files, tabs,
split windows, and editing positions.

Sessions live in `~/.local/state/dotfiles/vim-sessions/`, not in the project.
Vim and Neovim use separate session files. Different directories outside Git
have independent sessions; directories within one Git worktree share a session.
Inside Git, Vim changes its working directory to the worktree root on startup,
even when launched from a subdirectory or with a file path. Session restoration
cannot override that root directory.
Unsaved buffer contents and running terminal processes are **not** preserved;
save your files before quitting.

## Installing dependencies

### Nix installation

Install Nix on macOS or Linux using the official multi-user installer:

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

Open a new terminal and verify the installation:

```bash
nix --version
```

Reference: [Nix installation guide](https://nix.dev/install-nix).

### Neovim plugin installation (manual)

If you are not using Nix, run:

```bash
bash ./install-nvim-plugins
```

## iTerm2 configuration (macOS)

In iTerm2, open **Settings → General → Settings**, enable **Load settings from a custom folder or URL**, and select this repository's `iterm2/` directory. Enable **Save changes to folder when iTerm2 quits** to keep the configuration in sync.

This is configured directly in iTerm2; `./install` is not involved.
