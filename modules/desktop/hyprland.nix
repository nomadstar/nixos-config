{ config, lib, pkgs, ... }:

{
  programs.hyprland.enable = true;

  # Without this, Electron/Chromium apps (Discord, VSCode, ...) fall back to
  # XWayland, which doesn't handle this session's fractional/HiDPI scaling
  # right and renders them blurry/pixelated instead of native-Wayland sharp.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    alacritty
    wofi
    wl-clipboard
    grim
    slurp
    nwg-displays
  ];
}
