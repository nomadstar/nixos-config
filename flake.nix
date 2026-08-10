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
      url = "git+file:///home/nanixtus/dotfiles";
      flake = false;
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, sops-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/desktop/default.nix
          sops-nix.nixosModules.sops
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit dotfiles; };
            home-manager.users.nanixtus = import ./hosts/desktop/home.nix;
          }
        ];
      };

      # Optional, on-demand tool sets: `nix develop .#<name>`. Nothing here
      # is installed into the system config - these are throwaway shells.
      devShells.${system} = {
        ai = pkgs.mkShell {
          name = "ai-devshell";
          packages = with pkgs; [
            python3
            python3Packages.pip
            python3Packages.virtualenv
            ollama

            # GPU: this host has an AMD Radeon (Navi, amdgpu driver) -> ROCm,
            # not CUDA (CUDA is NVIDIA-only and would silently no-op here).
            # rocminfo/rocm-smi confirm the GPU is visible; Ollama itself
            # detects and uses ROCm automatically when present.
            rocmPackages.rocminfo
            rocmPackages.rocm-smi
          ];
        };

        pentest = pkgs.mkShell {
          name = "pentest-devshell";
          packages = with pkgs; [ nmap wireshark gobuster hydra sqlmap netcat-gnu ];
        };

        sdr = pkgs.mkShell {
          name = "sdr-devshell";
          packages = with pkgs; [ rtl-sdr gqrx gnuradio ];
        };
      };
    };
}
