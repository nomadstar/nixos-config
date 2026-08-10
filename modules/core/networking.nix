{ config, lib, pkgs, ... }:

{
  # networking.hostName is set per-host, not here.
  networking.networkmanager.enable = true;
  services.openssh.enable = true;
}
