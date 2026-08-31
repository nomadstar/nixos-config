{ ... }:

# KDE Connect: Phone integration (file sharing, notifications, clipboard sync,
# multimedia control, remote input).
#
# 1. Package & Firewall:
#    programs.kdeconnect.enable = true installs pkgs.kdePackages.kdeconnect-kde
#    and automatically opens TCP and UDP port ranges 1714-1764 in
#    networking.firewall.
#
# 2. Hyprland tray indicator:
#    Autostarted via home/hypr/hyprland.conf's exec-once (kdeconnect-indicator).
{
  programs.kdeconnect.enable = true;
}
