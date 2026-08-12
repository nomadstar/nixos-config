{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/hardware/nvidia-prime.nix
    ../../modules/hardware/backlight.nix
  ];

  networking.hostName = "nanixos";
  time.timeZone = "America/Santiago";

  # This laptop's internal panel enumerates as eDP-1, not the desktop's
  # DP-1 - see modules/desktop/regreet.nix for why a mismatch here makes
  # greetd crash-loop (sway ends up with every output disabled).
  desktop.greeter.output = "eDP-1";

  i18n.defaultLocale = "es_CL.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "la-latin1";
    useXkbConfig = false;
  };

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # fluxcast (Miracast/Wi-Fi Direct casting to the Roku) needs this RTSP
  # port reachable; NixOS's firewall blocks it by default.
  networking.firewall.allowedTCPPorts = [ 7236 ];

  # Miracast/fluxcast needs Wi-Fi scan MAC randomization off (see
  # modules/desktop/wifi-panel.nix for why: no in-tree kernel driver,
  # including mt76/mt7921, declares
  # NL80211_EXT_FEATURE_MGMT_TX_RANDOM_TA_CONNECTED, so cfg80211 rejects
  # the P2P GO Negotiation Request frame's randomized source address with
  # EINVAL while wlo1 stays connected to the home AP - confirmed live,
  # kernel accepts the frame once randomization is off). Kept on
  # (default/secure) here; wifi-panel's waybar toggle drops it temporarily
  # around a cast instead of baking the insecure setting in persistently.

  # This value should NOT be changed once set for this host.
  # See https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  system.stateVersion = "25.11";
}
