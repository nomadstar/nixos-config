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
  };

  outputs = { self, nixpkgs, home-manager, dotfiles, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/desktop/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit dotfiles; };
            home-manager.users.nanixtus = import ./hosts/desktop/home.nix;
          }
        ];
      };
    };
}
