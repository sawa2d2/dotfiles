{
  description = "Home Manager configuration for dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    molokai = {
      url = "github:tomasr/molokai";
      flake = false;
    };
    fzf-git = {
      url = "github:junegunn/fzf-git.sh";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, fzf-git, molokai, ... }:
    let
      requireEnv = name:
        let value = builtins.getEnv name;
        in if value == "" then
          throw "Missing ${name}; set it in nix/local.env or export it, then apply with --impure"
        else value;
      username = requireEnv "HOME_MANAGER_USER";
      homeDirectory = requireEnv "HOME_MANAGER_HOME";
      mkHome = system: home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
        };
        extraSpecialArgs = { inherit fzf-git molokai; };
        modules = [
          ./home.nix
          {
            home.username = username;
            home.homeDirectory = homeDirectory;
          }
        ];
      };
    in {
      homeConfigurations = {
        ubuntu = mkHome "x86_64-linux";
        macos = mkHome "aarch64-darwin";
      };
    };
}
