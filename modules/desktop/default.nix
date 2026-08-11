{ ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./regreet.nix
    ./monitors.nix
    ./hypremoji.nix
    ./matrix-cursors.nix
  ];

  programs.firefox.enable = true;
}
