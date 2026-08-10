{ ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./regreet.nix
    ./monitors.nix
    ./hypremoji.nix
  ];

  programs.firefox.enable = true;
}
