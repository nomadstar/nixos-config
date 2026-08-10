{ ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./regreet.nix
    ./monitors.nix
  ];

  programs.firefox.enable = true;
}
