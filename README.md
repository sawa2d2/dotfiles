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

### Neovim plugin installation (macOS, manual)

These steps install the plugins used by this dotfiles repository manually, without a plugin manager.

Install `ripgrep` for Telescope's file search:

```bash
brew install ripgrep
```

Clone the Neovim plugins into the native package directory:

```bash
plugin_dir="$HOME/.local/share/nvim/site/pack/dotfiles/start"
mkdir -p "$plugin_dir"

# Completion plugins
for plugin in nvim-cmp cmp-nvim-lsp cmp-buffer cmp-path; do
    [ -d "$plugin_dir/$plugin" ] ||
        git clone "https://github.com/hrsh7th/$plugin.git" "$plugin_dir/$plugin"
done

# VS Code-like UI and Git change signs
plugins=(
    "nvim-lua/plenary.nvim:plenary-nvim"
    "nvim-telescope/telescope.nvim:telescope-nvim"
    "nvim-neo-tree/neo-tree.nvim:neo-tree-nvim"
    "MunifTanjim/nui.nvim:nui-nvim"
    "lewis6991/gitsigns.nvim:gitsigns-nvim"
)

for entry in "${plugins[@]}"; do
    repo="${entry%%:*}"
    name="${entry##*:}"
    [ -d "$plugin_dir/$name" ] && continue

    if [ "$name" = "neo-tree-nvim" ]; then
        git clone --depth 1 --branch v3.x \
            "https://github.com/$repo.git" "$plugin_dir/$name"
    else
        git clone --depth 1 \
            "https://github.com/$repo.git" "$plugin_dir/$name"
    fi
done
```

Restart Neovim after installation.


### Neovim Japanese input (optional)

Neovim switches the IME to an ASCII/off state when leaving Insert mode and
restores the previous state on the next InsertEnter. This is implemented by
`config.d/nvim/plugin/ime-switch.lua` and only activates when a supported
command is installed:

- macOS: install `macism` (`brew tap laishulu/homebrew && brew install macism`).
  The ASCII input source defaults to `com.apple.keylayout.ABC`; verify it is
  enabled on your Mac with `macism` while using English input. If your English
  input source has another ID, set
  `let g:dotfiles_ime_ascii_source = 'YOUR_INPUT_SOURCE_ID'` in
  `config.d/nvim/init.vim` *before* Neovim plugins load.
- Ubuntu (Fcitx5): ensure `fcitx5-remote` is installed and available in PATH.
  The plugin saves whether Fcitx5 was active, turns it off on InsertLeave,
  then reactivates it on InsertEnter.

Without those commands, the plugin is inert. A terminal's IME can intercept
uncommitted Japanese text before Neovim receives keystrokes, so finish or
cancel an active conversion before using the mode-exit shortcut. Existing
`Ctrl+C`-to-`Esc` mapping remains unchanged.

## iTerm2 configuration (macOS)

In iTerm2, open **Settings → General → Settings**, enable **Load settings from a custom folder or URL**, and select this repository's `iterm2/` directory. Enable **Save changes to folder when iTerm2 quits** to keep the configuration in sync.

This is configured directly in iTerm2; `./install` is not involved.
