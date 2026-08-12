{ config, lib, pkgs, pkgsUnstable, ... }:

{
  programs.hyprland.enable = true;

  # Our nixpkgs-25.11 pin ships xdg-desktop-portal-hyprland 1.3.11, which
  # crash-loops gnome-network-displays' screencast a few seconds in
  # ("Asked for a wl_shm buffer which is legacy" -> "Out of buffers" ->
  # retry -> new session, forever - confirmed live via `journalctl --user
  # -u xdg-desktop-portal-hyprland`). 1.3.12 added a DMA-BUF-to-SHM
  # fallback for exactly this; nixpkgs-unstable is already at 1.4.1, so
  # pull just this one package from there instead of waiting for it to
  # land in a stable release (same pattern as pkgsUnstable's ollama/opencode
  # in the ai devShell - see flake.nix).
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
