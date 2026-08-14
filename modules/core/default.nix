{ ... }:

{
  imports = [
    ./nix.nix
    ./boot.nix
    ./networking.nix
    ./users.nix
    ./packages.nix
    ./fonts.nix
    ./secrets.nix
    ./security.nix
    ./virtualisation.nix
    ./nix-ld.nix
  ];
}
