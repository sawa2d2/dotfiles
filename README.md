# dotfiles

## Install dotfiles

Run `./install` from the repository root to install the dotfiles.

```bash
./install
```

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
