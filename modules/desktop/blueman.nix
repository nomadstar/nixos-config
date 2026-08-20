{ ... }:

# blueman-applet: Bluetooth tray icon + menu (pair/connect/trust/remove
# devices), autostarted via home/hypr/hyprland.conf's exec-once.
# services.blueman.enable (not just installing pkgs.blueman) is what wires
# up the polkit rules and D-Bus service blueman-applet needs to manage
# bluetoothd as a regular user instead of failing silently without them.
# hardware.bluetooth.enable itself already lives in
# modules/hardware/windows-bt-sync.nix, laptop-only (this repo's only
# dual-boot/Bluetooth-using host).
{
  services.blueman.enable = true;
}
