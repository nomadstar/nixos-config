{ ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./regreet.nix
    ./monitors.nix
    ./hypremoji.nix
    ./matrix-cursors.nix
    ./wifi-panel.nix
    ./opensnitch.nix
    ./devshell-picker.nix
  ];

  programs.firefox.enable = true;
}
