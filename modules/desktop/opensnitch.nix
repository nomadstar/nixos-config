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

  environment.systemPackages = [ pkgs.opensnitch-ui ];
}
