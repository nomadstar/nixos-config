{ config, lib, pkgs, ... }:

{
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    wofi
    wl-clipboard
    grim
    slurp
    nwg-displays
  ];
}
