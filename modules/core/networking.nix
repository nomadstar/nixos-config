{ config, lib, pkgs, ... }:

{
  # networking.hostName is set per-host, not here.
  networking.networkmanager.enable = true;

  # Key-only, no root - this box has real global IPv6 addresses (not just
  # the private IPv4 behind the router's NAT), and NixOS's firewall opens
  # 22/tcp for both address families equally (services.openssh.openFirewall
  # defaults to true) - so unlike IPv4, reachability here depends on the
  # router/ISP filtering inbound IPv6, which isn't something this config
  # can see or control. The matching authorized key lives in
  # modules/core/users.nix.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # mDNS/DNS-SD (printers, file shares, .local hostnames on the LAN).
  # Unrelated to Miracast/WFD - that discovery happens over raw 802.11 P2P
  # frames before any IP network exists, confirmed via a monitor-mode
  # capture during the Wi-Fi P2P investigation (see hosts/laptop/default.nix).
 services.avahi = {
    enable = true;
    nssmdns4 = true; # Allows software to resolve .local hostnames
    openFirewall = true; # Allows other devices to find this system
    publish = {
      enable = true;
      userServices = true;
    };
  };
}
