{ ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./mako.nix
    ./regreet.nix
    ./monitors.nix
    ./hypremoji.nix
    ./matrix-cursors.nix
    ./wifi-panel.nix
    ./blueman.nix
    ./opensnitch.nix
    ./devshell-picker.nix
    ./qt-theme.nix
    ./venv-pkg-search.nix
  ];

  programs.firefox.enable = true;
}
