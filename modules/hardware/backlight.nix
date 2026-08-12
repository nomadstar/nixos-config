{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [ pkgs.brightnessctl ];

  # /sys/class/backlight/*/brightness is root:root 0644 by default. Unlike
  # input/sound/drm devices, systemd's udev rules only tag backlight
  # devices TAG+="seat" (71-seat.rules), not TAG+="uaccess" - so logind
  # never grants the session user an ACL on them, and brightnessctl (used
  # by home/hypr/hyprland.conf's XF86MonBrightness binds) fails to write
  # without this.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video $sys$devpath/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w $sys$devpath/brightness"
  '';

  users.users.nanixtus.extraGroups = [ "video" ];
}
