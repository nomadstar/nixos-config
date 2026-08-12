{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/hardware/nvidia-prime.nix
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

  # This value should NOT be changed once set for this host.
  # See https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  system.stateVersion = "25.11";
}
