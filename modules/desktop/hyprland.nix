{ config, lib, pkgs, pkgsUnstable, ... }:

{
  programs.hyprland.enable = true;

  # Use the complete current package recipe. The former source-only override
  # mixed an August 2026 Qt share-picker source with a newer Hyprtoolkit-based
  # nixpkgs recipe, so CMake could not find Qt and the whole system rebuild
  # failed. Version 1.5.0 already contains the screencopy race fix for which
  # that temporary override was introduced.
  programs.hyprland.portalPackage = pkgsUnstable.xdg-desktop-portal-hyprland;

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
