{ config, lib, pkgs, ... }:

{
  # networking.hostName is set per-host, not here.
  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  # mDNS/DNS-SD (printers, file shares, .local hostnames on the LAN).
  # Unrelated to Miracast/WFD - that discovery happens over raw 802.11 P2P
  # frames before any IP network exists, confirmed via a monitor-mode
  # capture during the Wi-Fi P2P investigation (see hosts/laptop/default.nix).
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
}
