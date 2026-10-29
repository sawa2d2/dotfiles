# dotfiles

## Install dotfiles

Requires Git.

```bash
curl -fsSL https://raw.githubusercontent.com/sawa2d2/dotfiles/main/bootstrap.sh | bash
```

Clones into `~/dotfiles` (override with `DOTFILES_DIR`) and installs symlinks. Existing Git checkouts are reused without pulling; other existing destinations are not overwritten.

`./install` also installs nvm v0.40.8 if `~/.nvm` is absent. Existing nvm directories are left untouched; Node.js versions are not installed automatically. Bash and Zsh load nvm from the shared shell initialization. To install Node.js explicitly, run `nvm install --lts` in a new shell.

## private.d

To manage private dotfiles separately, create a `private.d/` repository next to this repository's `home/` directory:

```text
dotfiles/
├── home/
└── private.d/
    ├── home/
    │   └── .config/
    └── install -> ../install
```

Link the parent installer from `private.d/`, put private settings under `private.d/home/`, and run:

```bash
ln -s ../install private.d/install
cd private.d
./install
```

The installer links files under `home/` into `$HOME`. If private settings require extra setup, add an optional `install-extra` script.

A symlinked `install` marks a child repository: its `home/.bashrc` and `home/.zshrc` are not linked into `$HOME`. Source these from the parent shell configuration when needed. This applies to nested child repositories as well.

## VS Code User Settings

`./install` links `home/.config/vscode/settings.json` and `extensions.json` to the VS Code User directory:

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


## tmux pane forwarding (tchat)

`tchat` forwards text from one tmux pane to another. It is a generic local
transport; it does **not** understand when an AI response is complete.

```bash
tmux display-message -p '#{pane_id}'  # run in each pane to find its ID
tchat once %1 %2    # send current source-pane snapshot once
tchat on %1 %2      # watch %1 and forward changed snapshots after 2s idle
tchat status %1
tchat off %1        # stop the watcher
```

Forwarding is one-way. Do not enable opposite-direction watchers simultaneously:
that can create feedback loops. The continuous mode forwards a bounded snapshot
of the source pane's visible history, not just an AI answer; use it only with
trusted panes and review the receiving agent's permissions. For reliable
answer-only forwarding, an AI-specific completion hook belongs in agent-config,
not this generic tmux utility. Requires Python 3 and tmux.

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

Note: VS Code uses `.vscode/extensions.json` for workspace extension recommendations. A file in the User directory is not equivalent and does not automatically install or recommend extensions globally.
