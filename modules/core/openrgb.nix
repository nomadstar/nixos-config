{ config, lib, pkgs, ... }:

{
  # OpenRGB: System-wide RGB lighting control across motherboards, RAM, GPUs,
  # coolers, and peripherals. Configured as a system service so udev rules and
  # i2c kernel modules (i2c-dev, i2c-piix4 / i2c-i801) are loaded and accessible
  # without needing root permissions.
  services.hardware.openrgb = {
    enable = true;
    package = pkgs.openrgb-with-all-plugins;
  };
}
