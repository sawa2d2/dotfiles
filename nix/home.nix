{ pkgs, molokai, ... }:

{
  home.stateVersion = "26.05";

  # CLI packages only; existing dotfiles remain unmanaged by Home Manager.
  home.packages = with pkgs; [
    fzf
    delta
    zoxide
    tmux
    neovim
    ripgrep
    jq
    git
    gh
    tree
    shellcheck
    shfmt
    gnumake
    ruff
    pyright
  ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    blesh
  ];

  # Neovim plugins, installed in the native package discovery path.
  home.file.".local/share/nvim/site/pack/dotfiles/start/nvim-cmp".source = pkgs.vimPlugins.nvim-cmp;
  home.file.".local/share/nvim/site/pack/dotfiles/start/cmp-nvim-lsp".source = pkgs.vimPlugins.cmp-nvim-lsp;
  home.file.".local/share/nvim/site/pack/dotfiles/start/cmp-buffer".source = pkgs.vimPlugins.cmp-buffer;
  home.file.".local/share/nvim/site/pack/dotfiles/start/cmp-path".source = pkgs.vimPlugins.cmp-path;
  home.file.".local/share/nvim/site/pack/dotfiles/start/plenary-nvim".source = pkgs.vimPlugins.plenary-nvim;
  home.file.".local/share/nvim/site/pack/dotfiles/start/telescope-nvim".source = pkgs.vimPlugins.telescope-nvim;
  home.file.".local/share/nvim/site/pack/dotfiles/start/neo-tree-nvim".source = pkgs.vimPlugins.neo-tree-nvim;
  home.file.".local/share/nvim/site/pack/dotfiles/start/nui-nvim".source = pkgs.vimPlugins.nui-nvim;
  home.file.".local/share/nvim/site/pack/dotfiles/start/gitsigns-nvim".source = pkgs.vimPlugins.gitsigns-nvim;
  home.file.".local/share/nvim/site/pack/dotfiles/start/vim-illuminate".source = pkgs.vimPlugins.vim-illuminate;

  # Zsh plugins, sourced from stable Home Manager-managed paths.
  home.file.".local/share/zsh/plugins/zsh-autosuggestions".source = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
  home.file.".local/share/zsh/plugins/zsh-syntax-highlighting".source = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";

  # Vim's native package layout; do not replace the existing Vim configuration.
  home.file.".vim/pack/tpope/start/surround".source = pkgs.vimPlugins.vim-surround;

  # Share exactly the same Molokai theme between Vim and Neovim.
  home.file.".vim/colors/molokai.vim".source = "${molokai}/colors/molokai.vim";
  home.file.".config/nvim/colors/molokai.vim".source = "${molokai}/colors/molokai.vim";

  # Keep the path sourced by both Bash and Zsh unchanged.

  programs.home-manager.enable = true;
}
