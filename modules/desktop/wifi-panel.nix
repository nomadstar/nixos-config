{ config, lib, pkgs, ... }:

# Wi-Fi settings dropdown for waybar (wofi-based). Currently has one
# setting: Wi-Fi scan MAC randomization.
#
# Why this needs to be toggleable at all: NixOS's networkmanager module
# defaults wifi.scanRandMacAddress to true (see hosts/laptop/default.nix
# for the "why" - it breaks Miracast P2P GO Negotiation, because
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
# anything Nix manages.
#
# `nmcli general reload conf` alone is NOT enough - confirmed live via
# kprobe tracing on 2026-08-12 that it doesn't change the source address
# NetworkManager already picked for the p2p-dev-wlo1 device (that seems to
# get decided once, when NetworkManager/the device starts). A full
# `systemctl restart NetworkManager.service` does pick it up. That needs
# a polkit rule (below) since regular users can't restart system units by
# default - scoped to exactly this one unit for the networkmanager group,
# same "narrow" spirit as the tmpfiles rule above.
let
  macMarker = "/etc/NetworkManager/conf.d/99-wifi-mac-random-off.conf";

  wifiMacToggle = pkgs.writeShellApplication {
    name = "wifi-mac-toggle";
    runtimeInputs = [ pkgs.systemd pkgs.libnotify ];
    text = ''
      if [ -f "${macMarker}" ]; then
        rm -f "${macMarker}"
        systemctl restart NetworkManager.service
        notify-send "Wi-Fi" "Randomización de MAC (scan): ON (default)"
      else
        printf '[device]\nwifi.scan-rand-mac-address=false\n' > "${macMarker}"
        systemctl restart NetworkManager.service
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

  # Lets wifi-mac-toggle restart NetworkManager.service without a sudo
  # password prompt (which wouldn't work from a waybar/wofi click anyway -
  # no TTY to type it into). Scoped to this one unit and this one group.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "NetworkManager.service" &&
          subject.isInGroup("networkmanager")) {
        return polkit.Result.YES;
      }
    });
  '';

  environment.systemPackages = [ wifiMacToggle wifiPanel ];
}
