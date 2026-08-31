{ config, lib, pkgs, ... }:

# Application firewall with per-connection allow/deny prompts. Chosen over
# ufw/gufw (what was originally asked for): neither is packaged in nixpkgs,
# and ufw manages iptables/nftables state outside Nix's declarative model -
# the same conflict-with-the-managed-firewall problem that ruled out gufw.
# OpenSnitch instead runs its own separate nftables table
# (services.opensnitch.settings.Firewall, "nftables" by upstream default),
# so it coexists with NixOS's own networking.firewall (modules/core/networking.nix)
# instead of replacing it.
#
# Two halves:
# - opensnitchd (this service): the privileged daemon that intercepts
#   connections and enforces rules.
# - opensnitch-ui (packaged below, autostarted via home/hypr/hyprland.conf's
#   exec-once): the GTK app with the "allow/deny this connection?" popup and
#   the rule manager. It has to already be running *before* a connection
#   happens for the popup to show at all - if it's not running,
#   DefaultAction (opensnitch's own upstream default: "allow") is all that
#   applies. modules/desktop/wifi-panel.nix's wofi menu (right-click on the
#   waybar network icon) also has an entry to open/raise it on demand.
{
  services.opensnitch.enable = true;

  # Declarative rules (written as symlinks into
  # services.opensnitch.settings.Rules.Path, which already resolves to
  # /etc/opensnitchd/rules - same directory opensnitchd's own shipped
  # default-config.json points at, confirmed live). Nix's cleanup for this
  # option only ever deletes symlinks it created itself, so this coexists
  # fine with the two rules already sitting there as plain files
  # (avahi-daemon.json, gnome-network-displays.json) from before this was
  # declarative.
  #
  # Every rule needs a "created" field - opensnitchd expects it in
  # RFC3339 and logs a parse warning (WAR "Error parsing rule Created
  # date") on every single evaluation of the rule if it's missing, which
  # is exactly the bug that had allow-avahi-daemon/allow-gnome-network-displays
  # (created outside Nix, by hand) spamming the daemon log all day
  # 2026-08-14 before it got fixed by hand-adding the field back.
  services.opensnitch.rules = {
    "permitir-avahi-mdns" = {
      name = "permitir-avahi-mdns";
      enabled = true;
      action = "allow";
      duration = "always";
      created = "2026-08-14T22:00:00Z";
      operator = {
        type = "simple";
        sensitive = false;
        operand = "dest.port";
        data = "5353";
      };
    };
    "permitir-miracast-rtsp" = {
      name = "permitir-miracast-rtsp";
      enabled = true;
      action = "allow";
      duration = "always";
      created = "2026-08-14T22:00:00Z";
      operator = {
        type = "simple";
        sensitive = false;
        operand = "dest.port";
        data = "7236";
      };
    };
    "permitir-kdeconnect" = {
      name = "permitir-kdeconnect";
      enabled = true;
      action = "allow";
      duration = "always";
      created = "2026-08-31T20:00:00Z";
      operator = {
        type = "regexp";
        sensitive = false;
        operand = "dest.port";
        data = "^(171[4-9]|17[2-5][0-9]|176[0-4])$";
      };
    };
  };

  environment.systemPackages = [ pkgs.opensnitch-ui ];
}
