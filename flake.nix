{
  description = "nanixtus reproducible NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Curated dotfiles (hypr/alacritty/nwg-displays), also linked in as the
    # home/ git submodule for `git clone --recurse-submodules`. Fetched here
    # as its own flake input so Nix evaluation doesn't depend on the parent
    # repo's git index carrying submodule content (it doesn't).
    dotfiles = {
      url = "github:nomadstar/dotfiles";
      flake = false;
    };

    # Personal Neovim (NvChad-based) config, also linked in as the nvim/ git
    # submodule for `git clone --recurse-submodules` - same reasoning as
    # `dotfiles` above.
    nvimConfig = {
      url = "github:nomadstar/starter";
      flake = false;
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Claude Code CLI, for the ai devShell. Not in nixpkgs.
    claude-code.url = "github:ryoppippi/nix-claude-code";

    # Google Antigravity IDE + `agy` CLI, for the ai/developer devShells. Not
    # in nixpkgs; this flake pins its own nixpkgs with allowUnfree already set.
    antigravity-nix.url = "github:jacopone/antigravity-nix";

    # Wireless display casting (Miracast/WFD, DLNA, Chromecast). Not in
    # nixpkgs; packaged from source in modules/core/fluxcast.nix. Pinned to
    # a tag rather than a branch for reproducibility.
    fluxcast = {
      url = "github:IlyaP358/fluxcast/v0.2.2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, nvimConfig, sops-nix, claude-code, antigravity-nix, fluxcast, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # CUDA packages are unfree; only the pkgs instance used to build the
      # nvidia devShell variant allows it. The system-wide `pkgs` above (and
      # therefore nixosConfigurations) stays unfree-free unless you decide
      # otherwise for the whole system.
      pkgsUnfree = import nixpkgs { inherit system; config.allowUnfree = true; };

      # GPU policy for the ai devShell, per host: NVIDIA -> CUDA, AMD -> ROCm,
      # anything else (no dGPU, Intel-only, etc.) -> no GPU packages added.
      mkAiShell = { gpu ? "none" }:
        let
          gpuPackages =
            if gpu == "amd" then
              (with pkgs; [ rocmPackages.rocminfo rocmPackages.rocm-smi ])
            else if gpu == "nvidia" then
              (with pkgsUnfree; [ cudaPackages.cudatoolkit cudaPackages.cuda_nvcc ])
            else
              [ ];
        in
        pkgs.mkShell {
          name = "ai-devshell";
          packages = with pkgs; [
            python3
            python3Packages.pip
            python3Packages.virtualenv
            ollama
            claude-code.packages.${system}.default
            opencode
            antigravity-nix.packages.${system}.google-antigravity-cli
          ] ++ gpuPackages;
        };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit fluxcast; };
        modules = [
          ./hosts/desktop/default.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit dotfiles nvimConfig; };
            home-manager.users.nanixtus = import ./hosts/desktop/home.nix;
          }
        ];
      };

      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit fluxcast; };
        modules = [
          ./hosts/laptop/default.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit dotfiles nvimConfig; };
            home-manager.users.nanixtus = import ./hosts/laptop/home.nix;
          }
        ];
      };

      # Optional, on-demand tool sets: `nix develop .#<name>`. Nothing here
      # is installed into the system config - these are throwaway shells.
      devShells.${system} = {
        # desktop's GPU: AMD Radeon RX 9060 XT (Navi 44), amdgpu driver -> ROCm.
        ai = mkAiShell { gpu = "amd"; };

        # laptop's GPU: NVIDIA GeForce RTX 2050 (Ampere, GA107) -> CUDA.
        ai-laptop = mkAiShell { gpu = "nvidia"; };

        pentest = pkgs.mkShell {
          name = "pentest-devshell";
          packages = with pkgs; [ nmap wireshark gobuster hydra sqlmap netcat-gnu ];
        };

        sdr = pkgs.mkShell {
          name = "sdr-devshell";
          packages = with pkgs; [ rtl-sdr gqrx gnuradio ];
        };

        # GUI editors/IDEs, kept out of the ai devShell (and off the system
        # entirely) since they're heavy and only needed on demand. vscode is
        # unfree, hence pkgsUnfree instead of pkgs here.
        developer = pkgs.mkShell {
          name = "developer-devshell";
          packages = [
            pkgsUnfree.vscode
            antigravity-nix.packages.${system}.google-antigravity-ide
          ];
        };
      };
    };
}
