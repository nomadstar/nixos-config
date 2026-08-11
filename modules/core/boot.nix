{ config, lib, pkgs, ... }:

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;

  # Matrix-style green-on-black GRUB menu. No NixOS option for menu colors
  # directly, so this is raw grub.cfg appended verbatim.
  boot.loader.grub.extraConfig = ''
    set color_normal=green/black
    set color_highlight=black/green
    set menu_color_normal=green/black
    set menu_color_highlight=black/green
  '';

  # Plain dark boot splash. A real Matrix rain animation would need a
  # hand-built Plymouth theme (script + frames) - out of scope for now.
  boot.plymouth.enable = true;
  boot.plymouth.theme = "spinner";
}
