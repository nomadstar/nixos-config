{ pkgs, ... }:

{
  # Not in nixpkgs - packaged from source. Keybind (SUPER+.) and window
  # rules come from the home/ dotfiles (hypr/hypremoji.conf), sourced by
  # hyprland.conf the same way monitors.conf already is.
  environment.systemPackages = [
    (pkgs.callPackage ./hypremoji/package.nix { })
  ];
}
