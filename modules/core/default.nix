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
    ../hardware/hardware-profile.nix
    ../hardware/detect-gpu.nix
    ./codebase-memory-mcp.nix
  ];
}
