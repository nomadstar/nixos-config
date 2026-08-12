{ config, lib, pkgs, ... }:

# Wi-Fi settings dropdown for waybar (wofi-based). Currently has one
# setting: Wi-Fi scan MAC randomization.
#
# Why this needs to be toggleable at all: NixOS's networkmanager module
# defaults wifi.scanRandMacAddress to true (see hosts/laptop/default.nix
# for the "why" - it breaks Miracast/fluxcast P2P GO Negotiation, because
# no in-tree kernel driver, including mt76/mt7921, declares
# NL80211_EXT_FEATURE_MGMT_TX_RANDOM_TA_CONNECTED). The system default
# stays secure (randomization on); this panel is how you drop it
# temporarily around a cast instead of baking the insecure setting into
# the persistent system config.
#
# How the toggle avoids needing a password: NixOS's networkmanager module
# only ever writes /etc/NetworkManager/NetworkManager.conf itself: nothing
# here manages /etc/NetworkManager/conf.d/, so it's safe to make that one
# directory group-writable (same "narrow, mechanism-specific" approach as
# modules/hardware/backlight.nix's udev rule) instead of reaching for sudo.
# NetworkManager merges conf.d/*.conf over the base file, so dropping a
# file there overrides wifi.scan-rand-mac-address without touching
# anything Nix manages; `nmcli general reload conf` picks it up live.
let
  macMarker = "/etc/NetworkManager/conf.d/99-wifi-mac-random-off.conf";

  wifiMacToggle = pkgs.writeShellApplication {
    name = "wifi-mac-toggle";
    runtimeInputs = [ pkgs.networkmanager pkgs.libnotify ];
    text = ''
      if [ -f "${macMarker}" ]; then
        rm -f "${macMarker}"
        nmcli general reload conf
        notify-send "Wi-Fi" "Randomización de MAC (scan): ON (default)"
      else
        printf '[device]\nwifi.scan-rand-mac-address=false\n' > "${macMarker}"
        nmcli general reload conf
        notify-send "Wi-Fi" "Randomización de MAC (scan): OFF (Miracast)"
      fi
    '';
  };

  wifiPanel = pkgs.writeShellApplication {
    name = "wifi-panel";
    runtimeInputs = [ pkgs.wofi wifiMacToggle ];
    text = ''
      if [ -f "${macMarker}" ]; then
        mac_line="Randomización de MAC (scan): OFF -> click para activar (default seguro)"
      else
        mac_line="Randomización de MAC (scan): ON -> click para desactivar (necesario para Miracast)"
      fi

      choice=$(printf '%s\n' "$mac_line" | wofi --dmenu --prompt "Wi-Fi" --width 480 --height 120)

      case "$choice" in
        "Randomización de MAC"*) wifi-mac-toggle ;;
      esac
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d /etc/NetworkManager/conf.d 0775 root networkmanager -"
  ];

  environment.systemPackages = [ wifiMacToggle wifiPanel ];
}
