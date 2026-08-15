{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware-gpu.nix
    ../../modules/core
    ../../modules/desktop
    ../../modules/hardware/amdgpu.nix
    ../../modules/hardware/rtl-sdr.nix
  ];

  networking.hostName = "nanixos";
  time.timeZone = "America/Santiago";

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

  # This value should NOT be changed once set for this host.
  # See https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
  system.stateVersion = "25.11";
}
