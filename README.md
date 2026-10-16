# dotfiles

## Install dotfiles

Run `./install` from the repository root to install the dotfiles.

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
