{ config, lib, pkgs, ... }:

{
  # Lets the rtl-sdr tools in the `sdr` devShell (flake.nix) talk to the
  # dongle over plain USB permissions, without udev rules or sudo.
  hardware.rtl-sdr.enable = true;
  hardware.hackrf.enable = true;

  # The kernel's DVB-T driver claims the dongle by default, which then
  # keeps rtl-sdr/SoapySDR from opening it as an SDR. Keep it from loading.
  boot.blacklistedKernelModules = [ "dvb_usb_rtl28xxu" ];

  # Same idea for Ettus USRPs and other platforms in the `sdr` devShell: 
  # ship its udev rules so the USB/network USRP is user-accessible without sudo.
  services.udev.packages = [ pkgs.uhd pkgs.soapysdr ];
}
